#!/bin/bash
# Run on bella after rendering. Preserve existing agent-managed dashboard config.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo 'Run as root on bella.' >&2; exit 1; }
base=${1:-/srv/dobby}
seed=${2:-rendered/homepage}
destination="$base/preview-config"
[[ -d "$destination" && ! -L "$destination" ]] || {
    echo 'Run prepare-bella.sh first.' >&2; exit 1;
}
for name in settings services bookmarks widgets docker kubernetes; do
    [[ -f "$seed/$name.yaml" ]] || { echo "Missing seed: $name.yaml" >&2; exit 1; }
done
for name in settings services bookmarks widgets docker kubernetes; do
    if [[ ! -e "$destination/$name.yaml" ]]; then
        install -m 0600 -o 10000 -g 10000 "$seed/$name.yaml" "$destination/$name.yaml"
    fi
done
echo "Seeded missing dashboard files in $destination; existing configuration retained."
