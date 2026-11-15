#!/usr/bin/python3
"""Register preview tiles and manage their project servers with Supervisor."""
import argparse
import fcntl
import hashlib
import json
import os
import pathlib
import shlex
import sys
import tempfile
import time
import urllib.parse
import xmlrpc.client

import yaml


def preview_url(base_url, port):
    if not 3000 <= port <= 5999:
        raise ValueError("Choose a preview port between 3000 and 5999.")
    parsed = urllib.parse.urlsplit(base_url)
    if parsed.scheme != "https" or not parsed.hostname or parsed.path not in ("", "/") or parsed.query or parsed.fragment or parsed.username or parsed.password:
        raise ValueError("Preview base URL must be an HTTPS origin.")
    return f"/live/{port}/"


def same_preview(href, path):
    # Older registries stored absolute URLs. Match their route during updates.
    parsed = urllib.parse.urlsplit(href or "")
    return parsed.path == path and not parsed.query and not parsed.fragment


def live_group(document):
    if not isinstance(document, list):
        raise ValueError("services.yaml must contain a list of Homepage groups.")
    groups = [g for g in document if isinstance(g, dict) and "Live previews" in g]
    if len(groups) > 1:
        raise ValueError("Keep one Live previews group in services.yaml.")
    if not groups:
        document.append({"Live previews": []})
        groups = [document[-1]]
    entries = groups[0]["Live previews"]
    if not isinstance(entries, list):
        raise ValueError("Live previews must be a list of service tiles.")
    if any(not isinstance(e, dict) or len(e) != 1 or not isinstance(next(iter(e.values())), dict) for e in entries):
        raise ValueError("Each Live previews tile must have one name and a settings map.")
    return entries


def update(document, action, url, name=None, port=None):
    entries = live_group(document)
    if action == "add":
        if not name or len(name) > 120 or any(ord(c) < 32 for c in name):
            raise ValueError("Use a readable preview name of 1..120 characters.")
        if any(name in item and not same_preview(item[name].get("href"), url) for item in entries):
            raise ValueError("That name already belongs to another port.")
    entries[:] = [item for item in entries if not same_preview(next(iter(item.values())).get("href"), url)]
    if action == "add":
        entries.append({name: {"href": url, "description": f"localhost:{port}", "target": "_self"}})
    return document


def write_atomic(path, document):
    write_text_atomic(path, yaml.safe_dump(document, sort_keys=False, allow_unicode=True))


def write_text_atomic(path, content):
    descriptor, temporary = tempfile.mkstemp(prefix=".services-", suffix=".yaml", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w") as stream:
            stream.write(content)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def supervisor_client(url):
    # Supervisor supplies the Unix-socket transport; no TCP control port is opened.
    from supervisor.xmlrpc import SupervisorTransport
    return xmlrpc.client.ServerProxy(
        "http://localhost", transport=SupervisorTransport(None, None, url)
    )


def sync_program(client, name, present):
    added, changed, removed = client.reloadConfig()[0]
    if name in changed or name in removed:
        try:
            client.stopProcessGroup(name, True)
        except xmlrpc.client.Fault as error:
            if error.faultCode != 70:  # NOT_RUNNING
                raise
        client.removeProcessGroup(name)
    if name in added or name in changed:
        client.addProcessGroup(name)
    if present:
        try:
            client.startProcess(name, True)
        except xmlrpc.client.Fault as error:
            if error.faultCode != 60:  # ALREADY_STARTED
                raise
        deadline = time.monotonic() + 20
        while True:
            info = client.getProcessInfo(name)
            if info["statename"] == "RUNNING":
                return
            if info["statename"] not in ("STARTING", "BACKOFF") or time.monotonic() >= deadline:
                raise ValueError(f"{name} failed to start; inspect its Supervisor log.")
            time.sleep(0.1)


def program_config(program_dir, port, spec):
    # User commands live in JSON, not INI: %, semicolons and quotes stay literal.
    command = shlex.join([
        sys.executable, str(pathlib.Path(__file__).resolve()),
        "--program-dir", str(program_dir), "run", str(port),
    ]).replace("%", "%%")
    revision = hashlib.sha256(spec.encode()).hexdigest()
    logfile = str(program_dir / f"preview-{port}.log").replace("%", "%%")
    return f"""[program:preview-{port}]
command={command}
environment=DOBBY_PREVIEW_REV="{revision}"
autostart=true
autorestart=true
startsecs=1
startretries=3
stopwaitsecs=15
stopasgroup=true
killasgroup=true
redirect_stderr=true
stdout_logfile={logfile}
stdout_logfile_maxbytes=1MB
stdout_logfile_backups=3
"""


def register(args, path, document):
    with supervisor_client(args.supervisor_url) as server:
        client = server.supervisor
        client.getState()  # Fail before changing files if Supervisor is unavailable.
        update_registration(args, path, document, client)


def update_registration(args, path, document, client):
    program_dir = args.program_dir.resolve()
    program_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    # One Supervisor program per port, regardless of the tile's display name.
    name = f"preview-{args.port}"
    config = program_dir / f"{name}.conf"
    metadata = program_dir / f"{name}.json"
    files = (config, metadata, path)
    previous = {p: p.read_text() if p.exists() else None for p in files}
    try:
        if args.action == "add":
            directory = args.directory.resolve(strict=True)
            if not directory.is_dir():
                raise ValueError("Preview working directory must be a directory.")
            command = shlex.split(args.command)
            if not command or any("\0" in arg for arg in command):
                raise ValueError("Provide a nonempty preview start command.")
            spec = json.dumps({"directory": str(directory), "command": command})
            write_text_atomic(metadata, spec)
            write_text_atomic(config, program_config(program_dir, args.port, spec))
        else:
            config.unlink(missing_ok=True)
        sync_program(client, name, args.action == "add")
        if args.action == "remove":
            metadata.unlink(missing_ok=True)
        write_atomic(path, document)
    except Exception:
        for file, content in previous.items():
            if content is None:
                file.unlink(missing_ok=True)
            else:
                write_text_atomic(file, content)
        try:
            sync_program(client, name, previous[config] is not None)
        except Exception as error:
            print(f"Supervisor rollback failed for {name}: {error}", file=sys.stderr)
        raise


def run_preview(args):
    spec = json.loads((args.program_dir / f"preview-{args.port}.json").read_text())
    os.chdir(spec["directory"])
    os.environ["PORT"] = str(args.port)
    os.environ["DOBBY_PREVIEW_PORT"] = str(args.port)
    os.execvp(spec["command"][0], spec["command"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config-dir", type=pathlib.Path, default=pathlib.Path("/preview-config"))
    parser.add_argument("--base-url", default=os.environ.get("DOBBY_PREVIEW_URL", ""))
    parser.add_argument("--program-dir", type=pathlib.Path,
                        default=pathlib.Path.home() / ".config/dobby/previews")
    parser.add_argument("--supervisor-url", default="unix:///tmp/dobby-supervisor.sock")
    commands = parser.add_subparsers(dest="action", required=True)
    add = commands.add_parser("add")
    add.add_argument("name")
    add.add_argument("port", type=int)
    add.add_argument("--directory", type=pathlib.Path, default=pathlib.Path.cwd())
    add.add_argument("--command", required=True, help="Start command, parsed as argv without a shell")
    remove = commands.add_parser("remove")
    remove.add_argument("port", type=int)
    commands.add_parser("list")
    run = commands.add_parser("run", help=argparse.SUPPRESS)
    run.add_argument("port", type=int)
    args = parser.parse_args()
    try:
        if args.action == "run":
            run_preview(args)
            return
        path = args.config_dir / "services.yaml"
        with (args.config_dir / ".registration.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            document = yaml.safe_load(path.read_text()) or []
            if args.action == "list":
                print(yaml.safe_dump({"Live previews": live_group(document)}, sort_keys=False))
                return
            url = preview_url(args.base_url, args.port)
            update(document, args.action, url, getattr(args, "name", None), args.port)
            register(args, path, document)
        print(f"{'Registered' if args.action == 'add' else 'Removed tile for'} {url}")
        print(f"Supervisor preview-{args.port} {'running' if args.action == 'add' else 'removed'}. Refresh the dashboard if needed.")
    except (OSError, ValueError, yaml.YAMLError, xmlrpc.client.Error) as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
