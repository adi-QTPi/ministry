#!/usr/bin/env python3
"""Run as root on bella. Create private files without displaying credentials."""
import argparse
import getpass
import os
import pathlib
import secrets
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--base", type=pathlib.Path, default=pathlib.Path("/srv/dobby"))
args = parser.parse_args()
if os.geteuid() != 0:
    parser.error("Run as root on bella, after prepare-bella.sh.")
admin = args.base / "admin"
if not admin.is_dir() or admin.is_symlink():
    parser.error("Expected the root-owned admin directory created by prepare-bella.sh.")
if admin.stat().st_uid != 0 or admin.stat().st_mode & 0o077:
    parser.error("The admin directory must be root-owned with mode 0700.")
os.umask(0o077)


def create(name, values):
    path = admin / name
    for key, value in values.items():
        if not value or any(c in value for c in "\n\r\x00"):
            raise ValueError(f"Invalid {key}")
    if path.is_symlink():
        raise ValueError(f"Refusing symlink: {path}")
    if path.exists():
        print(f"Keeping existing {path}")
        return
    descriptor, temporary = tempfile.mkstemp(prefix=".secret-", dir=admin)
    try:
        with os.fdopen(descriptor, "w") as stream:
            for key, value in values.items():
                stream.write(f"{key}={value}\n")
            stream.flush()
            os.fsync(stream.fileno())
        # Atomically publish without replacing an existing secret.
        os.link(temporary, path)
    finally:
        os.unlink(temporary)
    print(f"Created {path}")


create("relay.env", {"HANDY_MASTER_SECRET": secrets.token_hex(32)})
if not (admin / "tailscale.env").exists():
    create("tailscale.env", {
        "client_id": getpass.getpass("Tailscale OAuth client ID: "),
        "client_secret": getpass.getpass("Tailscale OAuth client secret: "),
    })
else:
    print(f"Keeping existing {admin / 'tailscale.env'}")
