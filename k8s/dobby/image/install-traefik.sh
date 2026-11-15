#!/bin/bash
set -euo pipefail
case "${1:-}" in
 arm64) checksum=cf3711fe64e1c229a1b1c50836f2a5db735a700b3fa5c4bc69fe0602fa0e9506 ;;
 amd64) checksum=bc7e1e520c2d628b784e4e9c19bb259914082d5a70a27d509911caac5df18091 ;;
 *) echo 'Unsupported Traefik architecture' >&2; exit 1 ;;
esac
temporary=$(mktemp -d)
trap 'rm -rf -- "$temporary"' EXIT
curl -fsSL --retry 3 "https://github.com/traefik/traefik/releases/download/v3.7.18/traefik_v3.7.18_linux_$1.tar.gz" -o "$temporary/traefik.tgz"
printf '%s  %s\n' "$checksum" "$temporary/traefik.tgz" | sha256sum --check --status
tar -xzf "$temporary/traefik.tgz" -C "$temporary" traefik
install -m 0755 "$temporary/traefik" /usr/local/bin/traefik
