#!/usr/bin/python3
"""Seed and supervise upstream Pangolin/Traefik; sync the preview email allowlist."""
import argparse
import http.cookies
import json
import os
import pathlib
import re
import secrets
import signal
import sqlite3
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

import yaml

APP = pathlib.Path("/opt/pangolin")
READY = pathlib.Path("/tmp/dobby-preview-auth-ready")
EMAIL = re.compile(r"[A-Za-z0-9.!#$%&'+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?\.[A-Za-z]{2,}")
TEMPLATE = """# Use two HTTPS hostnames on the same public domain.
# Example: https://hq-previews.example.com and https://hq-preview-auth.example.com
preview_url: ""
auth_url: ""
smtp:
  host: ""
  port: 465
  user: ""
  password: ""
  from: ""
  secure: true  # implicit TLS, normally port 465
session_hours: 24
"""


def create_missing(path, contents):
    try:
        with open(path, "x", opener=lambda name, flags: os.open(name, flags, 0o600)) as stream:
            stream.write(contents)
    except FileExistsError:
        pass


def atomic_write(path, contents):
    descriptor, name = tempfile.mkstemp(dir=path.parent, prefix=".pangolin-")
    try:
        with os.fdopen(descriptor, "w") as stream:
            stream.write(contents)
        os.replace(name, path)
    finally:
        pathlib.Path(name).unlink(missing_ok=True)


def seed(root):
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    (root / "runtime").mkdir(exist_ok=True, mode=0o700)
    create_missing(root / "settings.yaml", TEMPLATE)
    create_missing(root / "allowed-emails.txt", "# One exact email address per line. Empty means deny everyone.\n")
    # These are machine credentials, not a viewer account or an allowlist entry.
    state = {"secret": secrets.token_hex(32), "email": "admin@dobby.invalid",
             "password": secrets.token_urlsafe(48)}
    create_missing(root / "admin.json", json.dumps(state, indent=2) + "\n")


def origin(value):
    if not isinstance(value, str):
        raise ValueError("Set preview_url and auth_url to HTTPS origins.")
    url = urllib.parse.urlsplit(value)
    if (url.scheme != "https" or not url.hostname or url.port not in (None, 443)
            or url.path not in ("", "/") or url.query or url.fragment or url.username
            or url.password or not re.fullmatch(r"[a-z0-9]+(?:[.-][a-z0-9]+)*", url.hostname)):
        raise ValueError("Set preview_url and auth_url to HTTPS origins without paths or custom ports.")
    return url.hostname


def settings(root):
    data = yaml.safe_load((root / "settings.yaml").read_text())
    if not isinstance(data, dict):
        raise ValueError("settings.yaml must contain a settings map.")
    preview, auth = origin(data.get("preview_url")), origin(data.get("auth_url"))
    if preview == auth or preview.split(".")[1:] != auth.split(".")[1:]:
        raise ValueError("Use distinct preview/auth hostnames with the same parent domain.")
    smtp = data.get("smtp")
    if (not isinstance(smtp, dict) or not isinstance(smtp.get("host"), str) or not smtp["host"]
            or not EMAIL.fullmatch(str(smtp.get("from", "")))
            or type(smtp.get("port")) is not int or not 1 <= smtp["port"] <= 65535
            or smtp.get("secure") is not True
            or any(not isinstance(smtp.get(key), str) for key in ("user", "password"))):
        raise ValueError("Fill in SMTP host, port and from address; secure must be true (implicit TLS).")
    hours = data.get("session_hours")
    if type(hours) is not int or not 1 <= hours <= 168:
        raise ValueError("session_hours must be an integer between 1 and 168.")
    return data


def emails(root):
    allowed = set()
    for line in (root / "allowed-emails.txt").read_text().splitlines():
        email = line.strip().lower()
        if not email or email.startswith("#"):
            continue
        if not EMAIL.fullmatch(email) or "*" in email:
            raise ValueError("allowed-emails.txt contains an invalid address; use exact emails, no wildcards.")
        allowed.add(email)
    return sorted(allowed)


def runtime_config(data, state):
    auth = origin(data["auth_url"])
    smtp = data["smtp"]
    return {
        "app": {"dashboard_url": data["auth_url"].rstrip("/"), "log_level": "info",
                "telemetry": {"anonymous_usage": False}},
        "domains": {"dobby": {"base_domain": auth.split(".", 1)[1]}},
        "gerbil": {"base_endpoint": auth},
        "server": {"secret": state["secret"], "external_port": 6100, "internal_port": 6101,
                   "next_port": 6102, "integration_port": 6103, "ai_gateway_port": 6104,
                   "internal_hostname": "127.0.0.1", "resource_session_length_hours": data["session_hours"],
                   "dashboard_session_length_hours": 24, "trust_proxy": 1},
        "flags": {"require_email_verification": True, "disable_signup_without_invite": True,
                  "disable_user_create_org": True, "allow_raw_resources": False,
                  "enable_integration_api": False, "enable_acme_cert_sync": False},
        "email": {"smtp_host": smtp["host"], "smtp_port": smtp["port"],
                  "smtp_user": smtp["user"], "smtp_pass": smtp["password"],
                  "no_reply": smtp["from"], "smtp_secure": smtp["secure"],
                  "smtp_tls_reject_unauthorized": True},
    }


def traefik_config(runtime):
    return {
        "entryPoints": {"websecure": {"address": "127.0.0.1:6081",
                         "forwardedHeaders": {"trustedIPs": ["127.0.0.1/32"]}}},
        "providers": {"file": {"filename": str(runtime / "routes.yaml"), "watch": True}},
        "experimental": {"plugins": {"badger": {"moduleName": "github.com/fosrl/badger", "version": "v1.4.0"}}},
        "log": {"level": "INFO"},
        "global": {"sendAnonymousUsage": False, "checkNewVersion": False},
    }


def routes(data):
    # Traefik terminates TLS only on loopback; the outer proxy owns public TLS.
    # Static routes avoid needing a WireGuard exit node or Docker socket.
    host = lambda name: f"Host(`{origin(data[name])}`)"
    # Badger has no defaults for these fields. Match Pangolin's server defaults.
    badger = {
        "apiBaseUrl": "http://127.0.0.1:6101/api/v1",
        "userSessionCookieName": "p_session_token",
        "resourceSessionRequestParam": "resource_session_request_param",
        "accessTokenQueryParam": "p_token",
        "accessTokenIdHeader": "P-Access-Token-Id",
        "accessTokenHeader": "P-Access-Token",
        "remoteUserIdHeader": "Remote-User-Id",
        "remoteVirtualApiKeyIdHeader": "Remote-Virtual-Api-Key-Id",
        "remoteUserHeader": "Remote-User",
        "remoteEmailHeader": "Remote-Email",
        "remoteNameHeader": "Remote-Name",
        "remoteRoleHeader": "Remote-Role",
    }
    return {"http": {
        "routers": {
            "previews": {"entryPoints": ["websecure"], "rule": host("preview_url"),
                         "middlewares": ["preview-auth"], "service": "previews", "tls": {}},
            "auth-api": {"entryPoints": ["websecure"], "rule": host("auth_url") + " && PathPrefix(`/api/v1`)",
                         "middlewares": ["auth-exchange"], "service": "auth-api", "tls": {}},
            "auth-ui": {"entryPoints": ["websecure"], "rule": host("auth_url"),
                        "middlewares": ["auth-exchange"], "service": "auth-ui", "tls": {}},
        },
        "middlewares": {
            "preview-auth": {"plugin": {"badger": badger}},
            "auth-exchange": {"plugin": {"badger": {**badger, "disableForwardAuth": True}}},
        },
        "services": {name: {"loadBalancer": {"servers": [{"url": f"http://127.0.0.1:{port}"}]}}
                     for name, port in (("previews", 6080), ("auth-api", 6100), ("auth-ui", 6102))},
    }}


def blueprint(data, allowed):
    return {"public-resources": {"dobby-previews": {
        "name": "Dobby previews", "mode": "http", "full-domain": origin(data["preview_url"]),
        "ssl": True, "enabled": bool(allowed), "forward-identity-headers": False,
        "auth": {"sso-enabled": False, "whitelist-users": allowed},
        # Traefik's static route owns the existing nginx upstream.
        "targets": [],
    }}}


class Api:
    def __init__(self, auth_url):
        self.auth_url = auth_url
        self.cookie = ""
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))

    def call(self, method, path, body=None):
        request = urllib.request.Request("http://127.0.0.1:6100/api/v1" + path,
            data=json.dumps(body).encode() if body is not None else None, method=method,
            headers={"Content-Type": "application/json", "X-CSRF-Token": "x-csrf-protection",
                     "Origin": self.auth_url, "X-Forwarded-Proto": "https", "Cookie": self.cookie})
        with self.opener.open(request, timeout=15) as response:
            cookie = http.cookies.SimpleCookie()
            for value in response.headers.get_all("Set-Cookie", []):
                cookie.load(value)
            if "p_session_token" in cookie:
                self.cookie = "p_session_token=" + cookie["p_session_token"].value
            result = json.load(response)
        if not result.get("success"):
            raise ValueError(f"Pangolin rejected {method} {path}.")
        return result.get("data")

    def sync(self, data, state, allowed):
        self.call("POST", "/auth/login", {"email": state["email"], "password": state["password"]})
        try:
            orgs = self.call("GET", "/orgs")["orgs"]
            if not any(org["orgId"] == "dobby" for org in orgs):
                self.call("PUT", "/org", {"orgId": "dobby", "name": "Dobby",
                          "subnet": "100.90.128.0/24", "utilitySubnet": "100.96.128.0/24"})
            result = self.call("PUT", "/org/dobby/blueprint", {
                "name": "Dobby preview email gate", "source": "API",
                "blueprint": yaml.safe_dump(blueprint(data, allowed))})
            if not result or not result.get("succeeded"):
                raise ValueError("Pangolin could not apply the preview email gate.")
        finally:
            self.call("POST", "/auth/logout", {})
            self.cookie = ""


def fresh_database(path):
    # Pangolin's JS export is named users, but its SQLite table is singular.
    with sqlite3.connect(f"file:{path}?mode=ro", uri=True) as db:
        return db.execute('SELECT count(*) FROM "user"').fetchone()[0] == 0


def run(root):
    READY.unlink(missing_ok=True)
    children = []
    try:
        last_error = None
        while True:
            try:
                data = settings(root)
                emails(root)
                break
            except (OSError, ValueError, yaml.YAMLError) as error:
                # YAML errors can include SMTP password lines. Do not print them.
                if type(error) != last_error:
                    print(f"Preview authentication locked: configure HTTPS origins, SMTP and exact emails in {root}.", flush=True)
                    last_error = type(error)
                time.sleep(5)
        state = json.loads((root / "admin.json").read_text())
        runtime = root / "runtime"
        for filename, document in (("config.yml", runtime_config(data, state)),
                                   ("traefik.yaml", traefik_config(runtime)), ("routes.yaml", routes(data))):
            atomic_write(runtime / filename, yaml.safe_dump(document, sort_keys=False))
        env = {**os.environ, "ENVIRONMENT": "prod", "NODE_ENV": "production", "ENABLE_SQLITE_WAL_MODE": "true"}
        subprocess.run(["node", "dist/migrations.mjs"], cwd=APP, env=env, check=True)
        # Only initialize a fresh instance. Never reset an existing administrator.
        if fresh_database(runtime / "db/db.sqlite"):
            subprocess.run(["node", "dist/cli.mjs", "set-admin-credentials", "--email", state["email"],
                            "--password", state["password"]], cwd=APP, env=env, check=True)
        children.append(subprocess.Popen(["node", "--enable-source-maps", "dist/server.mjs"], cwd=APP, env=env))
        children.append(subprocess.Popen(["traefik", "--configFile=" + str(runtime / "traefik.yaml")], cwd=runtime, env=env))
        api = Api(data["auth_url"].rstrip("/"))
        previous = None
        last_error = None
        while all(child.poll() is None for child in children):
            try:
                if settings(root) != data:
                    raise RuntimeError("Pangolin settings changed; restarting authentication.")
                allowed = emails(root)
                if allowed != previous:
                    READY.unlink(missing_ok=True)
                    api.sync(data, state, allowed)
                    previous = allowed
                    print(f"Preview email gate applied: {len(allowed)} approved addresses.", flush=True)
                if allowed:
                    READY.touch(mode=0o600)
                last_error = None
            except (OSError, ValueError, yaml.YAMLError) as error:
                READY.unlink(missing_ok=True)
                # Never log response bodies or configuration containing credentials.
                message = f"Preview authentication locked ({type(error).__name__}); check config and Pangolin logs."
                if message != last_error:
                    print(message, flush=True)
                    last_error = message
                previous = None
            time.sleep(5)
        raise RuntimeError("Pangolin or Traefik exited; restarting authentication.")
    finally:
        READY.unlink(missing_ok=True)
        for child in children:
            if child.poll() is None:
                child.terminate()
        for child in children:
            try:
                child.wait(timeout=10)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("seed", "check", "run"))
    parser.add_argument("--config-dir", type=pathlib.Path,
                        default=pathlib.Path.home() / ".config/dobby/pangolin")
    args = parser.parse_args()
    os.umask(0o077)
    if args.action == "seed":
        seed(args.config_dir)
    elif args.action == "check":
        settings(args.config_dir)
        print(f"Valid settings; {len(emails(args.config_dir))} approved emails.")
    else:
        signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
        run(args.config_dir)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, yaml.YAMLError, subprocess.CalledProcessError) as error:
        sys.exit(f"Preview authentication failed ({type(error).__name__}); gateway remains locked.")
