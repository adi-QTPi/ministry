# Dotfiles

>Basically I ditched nix (reasons: [archive/nix/README.md](../archive/nix/README.md)), but wanted a dependable alternative.

Single source of truth for shell, editor, and terminal configs. Managed by [chezmoi](https://www.chezmoi.io/), applied machine-wide via Ansible, and kept in sync by cron.

The dotfiles themselves are cross-platform: `dot_zshrc` (and its aliases) is written to work on both macOS and Linux servers, so the same config applies to a Mac. The Ansible package management, however, is Linux-only - it exists to prime the servers and is not meant to run on macOS. On a Mac, use `chezmoi update --force` (the `dotsync` alias) to pull the same dotfiles without Ansible.

## Layout

- `dot_zshrc` -> `~/.zshrc`
- `dot_zsh_plugins.txt` -> `~/.zsh_plugins.txt`
- `dot_config/nvim/init.lua` -> `~/.config/nvim/init.lua`
- `dot_config/alacritty/alacritty.toml` -> `~/.config/alacritty/alacritty.toml`
- `dot_config/starship.toml.tmpl` -> `~/.config/starship.toml`
- `shell-packages.yaml` -> package manifest (kept out of chezmoi via `.chezmoiignore`)
- `.chezmoiignore` -> keeps `README.md` out of chezmoi's target set
- `README.md` -> this file

## Plugins

Zsh plugins are loaded by [antidote](https://antidote.sh/), a pure-zsh plugin manager. `dot_zshrc` clones antidote into `~/.antidote` on first login, then loads `~/.zsh_plugins.txt`, so there is nothing to install separately. Add new plugins to `dot_zsh_plugins.txt`; order matters, `compinit` runs first.

## Flow

### Install - Ansible only

`infra/ansible/playbooks/chezmoi.yaml` runs the `chezmoi` role. The install step reads `shell-packages.yaml` and installs:

- everything listed in `shell-packages.yaml` (apt packages + official install scripts)
- chezmoi itself

### Sync - Ansible once, then cron

The role validates the repo and branch, deploys `/usr/local/bin/chezmoi-sync`, runs it once, sets zsh as the default shell for every user, and registers a cron job every 30 minutes.

The script:

- shallow, single-branch, blobless, sparse clone of this repo into `/opt/chezmoi` (only `dotfiles/`)
- later runs do `git pull --rebase --depth 1`
- applies `/opt/chezmoi/dotfiles` as the chezmoi source to every user (root + normal users)

Push to the configured branch and every host updates within 30 minutes, no Ansible needed.

## Config

In `infra/ansible/playbooks/chezmoi.yaml`:

- `chezmoi_repo` - repo URL
- `chezmoi_repo_branch` - branch to track
- `chezmoi_repo_dir` - subfolder used as chezmoi source
- `chezmoi_sync_minute` - cron interval, default `*/30`

## Run

```
just dotfiles           # all hosts
just dotfiles teddy     # one host
```

Packages install only when the playbook runs. Cron syncs dotfiles only, never packages.

## Last updated

- Date: 2026-09-17 02:18 UTC
- Previous commit: [5f9ca77](https://github.com/adi-QTPi/ministry/commit/5f9ca77)

_Date and commit hash are auto-generated. Commit hash is of the commit previous to the commit which modified this README._
