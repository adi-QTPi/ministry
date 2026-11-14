#!/bin/bash
# Bookworm does not package ttyd. Use checksum-pinned upstream static binaries.
set -euo pipefail
case "${1:-}" in
    arm64)
        asset=ttyd.aarch64
        checksum=b38acadd89d1d396a0f5649aa52c539edbad07f4bc7348b27b4f4b7219dd4165
        ;;
    amd64)
        asset=ttyd.x86_64
        checksum=8a217c968aba172e0dbf3f34447218dc015bc4d5e59bf51db2f2cd12b7be4f55
        ;;
    *) echo 'ttyd requires arm64 or amd64.' >&2; exit 1 ;;
esac
temporary=$(mktemp -d)
trap 'rm -rf -- "$temporary"' EXIT
curl --fail --location --silent --show-error --retry 3 \
    "https://github.com/tsl0922/ttyd/releases/download/1.7.7/$asset" \
    --output "$temporary/ttyd"
printf '%s  %s\n' "$checksum" "$temporary/ttyd" | sha256sum --check --status
install -m 0755 "$temporary/ttyd" /usr/local/bin/ttyd
