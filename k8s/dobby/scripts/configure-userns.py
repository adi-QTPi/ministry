#!/usr/bin/env python3
"""Reserve kubelet's subordinate IDs on bella. Does not restart k3s."""
import datetime
import grp
import json
import os
import pathlib
import pwd
import shutil
import subprocess
import sys

START = 16777216
COUNT = 7208960  # 110 pod slots, 65536 IDs per pod.
END = START + COUNT - 1

if os.geteuid() != 0:
    sys.exit("Run as root on bella. Review the planned k3s restart first.")
if not shutil.which("getsubids"):
    sys.exit("getsubids is required. Install the distro's uidmap/shadow utilities first.")
pods = json.loads(subprocess.check_output([
    "k3s", "kubectl", "get", "pods", "-A", "--field-selector", "spec.nodeName=bella", "-o", "json"
], text=True))
if any(p["spec"].get("hostUsers") is False for p in pods["items"]):
    sys.exit("A user-namespaced pod exists on bella. Drain/review that workload before changing ranges.")
node = json.loads(subprocess.check_output(["k3s", "kubectl", "get", "node", "bella", "-o", "json"], text=True))
if int(node["status"]["allocatable"]["pods"]) > COUNT // 65536:
    sys.exit("Configured range is too small for bella's pod limit.")
if any(START <= account.pw_uid <= END for account in pwd.getpwall()):
    sys.exit("Proposed range overlaps a host user.")
if any(START <= account.gr_gid <= END for account in grp.getgrall()):
    sys.exit("Proposed range overlaps a host group.")

paths = [pathlib.Path("/etc/subuid"), pathlib.Path("/etc/subgid")]
updates = {}
for path in paths:
    if path.is_symlink():
        sys.exit(f"Review symlinked subordinate-ID configuration manually: {path}")
    text = path.read_text() if path.exists() else ""
    entries = [line.split(":") for line in text.splitlines() if line and not line.startswith("#")]
    own = [entry for entry in entries if entry[0] == "kubelet"]
    if own and own != [["kubelet", str(START), str(COUNT)]]:
        sys.exit(f"Existing kubelet assignment differs in {path}; review manually.")
    for name, first, count in entries:
        if name != "kubelet" and int(first) <= END and int(first) + int(count) - 1 >= START:
            sys.exit(f"Range collision with {name} in {path}.")
    if not own:
        updates[path] = text.rstrip("\n") + ("\n" if text else "") + f"kubelet:{START}:{COUNT}\n"

try:
    account = pwd.getpwnam("kubelet")
    if account.pw_shell not in ("/usr/sbin/nologin", "/sbin/nologin", "/bin/false"):
        sys.exit("Existing kubelet account has a login shell; review it manually.")
except KeyError:
    subprocess.run(["useradd", "--system", "--no-create-home", "--shell", "/usr/sbin/nologin", "kubelet"], check=True)

stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
for path, text in updates.items():
    if path.exists():
        shutil.copy2(path, str(path) + f".dobby-{stamp}.bak")
    temporary = path.with_name(path.name + ".dobby-new")
    with temporary.open("x") as stream:
        stream.write(text)
    os.chmod(temporary, 0o644)
    os.replace(temporary, path)
print(f"Reserved {START}-{END} for kubelet UIDs/GIDs. No k3s restart performed.")
print("Review changes, then restart k3s during the planned maintenance window.")
