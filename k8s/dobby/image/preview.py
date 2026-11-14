#!/usr/bin/python3
"""Register Homepage preview tiles. Does not start apps or modify Kubernetes."""
import argparse
import fcntl
import os
import pathlib
import tempfile
import urllib.parse

import yaml


def preview_url(base_url, port):
    if not 3000 <= port <= 5999:
        raise ValueError("Choose a preview port between 3000 and 5999.")
    parsed = urllib.parse.urlsplit(base_url)
    if parsed.scheme != "https" or not parsed.hostname or parsed.path not in ("", "/") or parsed.query or parsed.fragment or parsed.username or parsed.password:
        raise ValueError("Preview base URL must be an HTTPS origin.")
    return f"{base_url.rstrip('/')}/live/{port}/"


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
        if any(name in item and item[name].get("href") != url for item in entries):
            raise ValueError("That name already belongs to another port.")
    entries[:] = [item for item in entries if next(iter(item.values())).get("href") != url]
    if action == "add":
        entries.append({name: {"href": url, "description": f"localhost:{port}", "target": "_self"}})
    return document


def write_atomic(path, document):
    descriptor, temporary = tempfile.mkstemp(prefix=".services-", suffix=".yaml", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w") as stream:
            yaml.safe_dump(document, stream, sort_keys=False, allow_unicode=True)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config-dir", type=pathlib.Path, default=pathlib.Path("/preview-config"))
    parser.add_argument("--base-url", default=os.environ.get("DOBBY_PREVIEW_URL", ""))
    commands = parser.add_subparsers(dest="action", required=True)
    add = commands.add_parser("add")
    add.add_argument("name")
    add.add_argument("port", type=int)
    remove = commands.add_parser("remove")
    remove.add_argument("port", type=int)
    commands.add_parser("list")
    args = parser.parse_args()
    try:
        path = args.config_dir / "services.yaml"
        with (args.config_dir / ".registration.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            document = yaml.safe_load(path.read_text()) or []
            if args.action == "list":
                print(yaml.safe_dump({"Live previews": live_group(document)}, sort_keys=False))
                return
            url = preview_url(args.base_url, args.port)
            update(document, args.action, url, getattr(args, "name", None), args.port)
            write_atomic(path, document)
        print(f"{'Registered' if args.action == 'add' else 'Removed tile for'} {url}")
        print("App processes are unchanged. Refresh the dashboard if needed.")
    except (OSError, ValueError, yaml.YAMLError) as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
