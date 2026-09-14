# Archived: Nix + Home Manager

Archived 2026-09-14. Kept for reference only. Do not re-enable.

## What this did

Nix flake + Home Manager configuration that managed dotfiles, packages,
and shell environment across the homelab hosts:

- `flake.nix` - flake entrypoint, defines a Home Manager config per host
- `hosts/hogwarts/home.nix` - macOS desktop/laptop
- `hosts/teddy/home.nix` - bare metal Linux server
- `hosts/rubie/home.nix` - bare metal Linux server
- `modules/` - shared config: shell, dev, desktop, security
- `utils/` - helper scripts: brightness, wifi, lid handling
- `nix-installation.sh` - bootstrap script that installs Nix and runs
  `home-manager switch`

## Why deprecated

- Fragile: Home Manager and nixpkgs version mismatches broke `switch` runs.
- Bloated and binding: heavy dependency graph for a small homelab, and it
  dictated the whole environment instead of staying out of the way.
- Packages gave intermittent issues, making the setup unreliable.
- No proper automation: config was manual and host-specific, not driven by
  a playbook.

## Replacement

Ansible now manages the hosts. See `infra/ansible/`.
