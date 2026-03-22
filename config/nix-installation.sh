#!/usr/bin/env bash

set -e

echo "--- Starting Nix & Home Manager Bootstrap ---"

read -p "Enter the flake configuration name (e.g., user@hostname): " FLAKE_NAME

if [ -z "$FLAKE_NAME" ]; then
    echo "Error: Flake configuration name cannot be empty. Exiting."
    exit 1
fi

echo "Proceeding with configuration: .#$FLAKE_NAME"
echo "---------------------------------------------"

echo "Checking for base dependencies (curl, git, xz-utils)..."
sudo apt update && sudo apt install -y curl xz-utils git

if ! command -v nix &> /dev/null; then
    echo "Installing Nix via Determinate Systems..."
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
    
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
else
    echo "Nix is already installed. Skipping installation..."
fi

echo "Ensuring flake files are tracked in Git..."
git add flake.nix home.nix 2>/dev/null || true

echo "Building Home Manager environment..."
nix run github:nix-community/home-manager -- switch -b backup --flake .#"$FLAKE_NAME"

for rc in ~/.bashrc ~/.zshrc; do
    if [ -f "$rc" ] && [ ! -L "$rc" ] && ! grep -q "nix-profile/bin" "$rc"; then
        echo "Adding Nix and Home Manager paths to $rc..."
        cat << 'EOF' >> "$rc"

# Nix & Home Manager Priority (Added by bootstrap script)
if [ -e "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
    source "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
fi
export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"
EOF
    fi
done

echo "--- Success! Reloading shell... ---"
exec "$SHELL"