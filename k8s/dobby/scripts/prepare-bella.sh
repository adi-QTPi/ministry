#!/bin/bash
# Run on bella as root AFTER reviewing the paths. No recursive chown of data.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo 'Run as root on bella.' >&2; exit 1; }
base=${1:-/srv/dobby}
[[ "$base" = /* && "$base" != / && ! "$base" =~ [[:space:]] ]] || exit 2
for directory in "$base" "$base/home" "$base/workspace" "$base/preview-config" "$base/relay" "$base/admin"; do
    [[ ! -L "$directory" ]] || { echo "Refusing symlink: $directory" >&2; exit 1; }
done
install -d -m 0755 -o root -g root "$base"
# Volume inode ownership is the in-container identity, even with idmapped mounts.
# Do not create a host login account for UID/GID 10000.
if getent passwd 10000 >/dev/null || getent group 10000 >/dev/null; then
    echo 'UID/GID 10000 already belongs to a host account/group; choose another identity first.' >&2
    exit 1
fi
install -d -m 0700 -o 10000 -g 10000 "$base/home" "$base/workspace"
install -d -m 0700 -o 1000 -g 1000 "$base/relay"
install -d -m 0700 -o 10000 -g 10000 "$base/preview-config"
install -d -m 0700 -o root -g root "$base/admin"
install -d -m 0700 -o 10000 -g 10000 "$base/home/.config" "$base/home/.config/dobby"
echo "Prepared $base. Configure disk quotas and external backups before unattended use."
