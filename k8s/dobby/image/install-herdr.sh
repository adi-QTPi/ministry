#!/bin/bash
# Match the laptop client; verify release bytes before installing.
set -euo pipefail
case "${1:-}" in
    arm64)
        architecture=aarch64
        checksum=f4ccf4de745f2cb9a39a983e9ba3703dad50ec2a58dea83026ceab721bbd8d9e
        ;;
    amd64)
        architecture=x86_64
        checksum=2a02fed16beb651ef006e1d43f048f652ca4dc58ad053cd2d44450563d5c54b7
        ;;
    *) echo 'Herdr requires arm64 or amd64.' >&2; exit 1 ;;
esac
temporary=$(mktemp -d)
trap 'rm -rf -- "$temporary"' EXIT
curl --fail --location --silent --show-error --retry 3 \
    "https://github.com/herdrdev/herdr/releases/download/v0.9.1/herdr-linux-$architecture" \
    --output "$temporary/herdr"
printf '%s  %s\n' "$checksum" "$temporary/herdr" | sha256sum --check --status
install -m 0755 "$temporary/herdr" /usr/local/bin/herdr
herdr --version
