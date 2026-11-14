#!/bin/bash
# Pinned upstream native releases. No curl-to-shell installers or daemon startup.
set -euo pipefail
case "${1:-}" in
    arm64)
        architecture=arm64
        treehouse_sha=3d1c02c8ab13049709ace66be51d99b72fe7b6d0b73d0d0efd90f226e1aa87d1
        no_mistakes_sha=8529f37d3b11a213abe9162851e84208e9c12e9d8ebf830e037f05e00558a656
        ;;
    amd64)
        architecture=amd64
        treehouse_sha=bd6227d909ba8046263ae5d4e072ccbcf43010cac9d7289b1262126510edfeed
        no_mistakes_sha=fbf131356a278623a509b6b50ecb39c5375b1a82e7dcfc48e42d10e761416d1e
        ;;
    *) echo 'Firstmate native dependencies require arm64 or amd64.' >&2; exit 1 ;;
esac
temporary=$(mktemp -d)
trap 'rm -rf -- "$temporary"' EXIT
install_release() {
    local name=$1 version=$2 checksum=$3
    local archive="$name-v$version-linux-$architecture.tar.gz"
    mkdir "$temporary/$name"
    curl --fail --location --silent --show-error --retry 3 \
        "https://github.com/kunchenguid/$name/releases/download/v$version/$archive" \
        --output "$temporary/$archive"
    printf '%s  %s\n' "$checksum" "$temporary/$archive" | sha256sum --check --status
    tar -xzf "$temporary/$archive" -C "$temporary/$name" "$name"
    install -m 0755 "$temporary/$name/$name" "/usr/local/bin/$name"
}
install_release treehouse 3.1.8 "$treehouse_sha"
install_release no-mistakes 1.106.1 "$no_mistakes_sha"
