#!/bin/bash
set -euo pipefail
install -d -m 0700 "$HOME/.config/dobby/tailscale"
# Userspace mode keeps TUN devices and NET_ADMIN out of the workspace.
exec sudo -n /usr/local/bin/tailscaled --tun=userspace-networking \
    --state="$HOME/.config/dobby/tailscale/tailscaled.state" \
    --socket=/tmp/dobby-tailscaled.sock --port=41641
