#!/bin/bash
set -euo pipefail
case "${1:-}" in
 arm64) checksum=d6bed2720310b328b861f943d7b4016c5358a9bad60575eb51e8143b79068484 ;;
 amd64) checksum=e56693ff74a64f2591b7e819c280635a100aae1ddfb0ef058fcd052b7cd8d16c ;;
 *) echo 'Unsupported Tailscale architecture' >&2; exit 1 ;;
esac
temporary=$(mktemp -d)
trap 'rm -rf -- "$temporary"' EXIT
curl -fsSL --retry 3 "https://pkgs.tailscale.com/stable/tailscale_1.104.7_$1.tgz" -o "$temporary/tailscale.tgz"
printf '%s  %s\n' "$checksum" "$temporary/tailscale.tgz" | sha256sum --check --status
tar -xzf "$temporary/tailscale.tgz" -C "$temporary"
install -m 0755 "$temporary/tailscale_1.104.7_$1/tailscale" /usr/local/bin/tailscale
install -m 0755 "$temporary/tailscale_1.104.7_$1/tailscaled" /usr/local/bin/tailscaled
