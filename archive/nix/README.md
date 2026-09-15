# [Archived] Nix + Home Manager

> **Archived:** September 14, 2026  
> **Status:** Kept for reference. Superseded by Ansible.

---

## Overview

This repository originally housed a Nix Flake + Home Manager setup intended to declaratively manage dotfiles, environment variables, base packages, and shell configurations across my homelab nodes:

- `flake.nix` — Flake entrypoint defining per-host Home Manager configurations.
- `hosts/hogwarts/home.nix` — macOS workstation (handled cross-platform dependencies nicely).
- `hosts/teddy/home.nix` — Bare-metal Linux server.
- `hosts/rubie/home.nix` — Bare-metal Linux server.
- `modules/` — Shared configurations for shell, dev tools, desktop, and security.
- `utils/` — Helper scripts (brightness control, Wi-Fi, lid handling).
- `nix-installation.sh` — Bootstrap script running `home-manager switch`.

---

## Why I Moved Away from Nix

To be clear: **this is not a critique of Nix or Home Manager.** Nix is an incredible tool, and its declarative approach to cross-platform setup (especially syncing macOS and Linux) was fantastic when it worked. 

Ultimately, this came down to my own learning curve with my first declarative configuration language, combined with friction in my day-to-day workflow:

### 1. Read-Only Symlinks & File Locking
Home Manager manages files by symlinking them to immutable read-only paths in the Nix Store (`/nix/store`). 
- Tools, SDKs, and third-party services that expected to append custom exports or auto-integrate into `~/.zshrc` failed outright because the files were write-protected.
- Simple, quick tweaks—like quickly appending a temporary directory to `$PATH`—became an unnecessary chore of updating Nix expressions and rebuilding.

### 2. Package & State Management Friction (Docker / Go)
Trying to declaratively manage stateful services like Docker or language toolchains (Go) introduced constant headaches. State files stored deep inside user profile stores (`~/.nix-profile`, `~/.local/state/nix`) collided with standard system-level daemons, creating permission issues and weird runtime edge cases.

### 3. Workflow Friction & Operational Overhead
Nix was my first deep dive into a purely declarative configuration system. While the core paradigm is powerful, maintaining it in a dynamic homelab environment introduced significant operational friction:

- **Impedance Mismatch:** Nix excels in strictly controlled, immutable environments. However, in a hands-on lab where rapid testing, ad-hoc changes, and third-party script integrations are constant, the overhead of constantly translating quick system tweaks into Nix expressions proved inefficient.
- **Incomplete Homelab Coverage:** Because of the ongoing friction with read-only environments and package compatibility, fully onboarding every node became counterproductive. Rather than forcing a tool that created friction on specialized nodes, it made more sense to re-evaluate the architecture entirely.
- **Loss of Experimentation Velocity:** Ultimately, the friction of fighting read-only file constraints turned standard system maintenance into a chore. It subtly disincentivized tinkering, leading me to bypass Nix entirely on newer nodes in favor of standard system package managers (apt, brew) and direct CLI configuration. Standardizing on Ansible was a deliberate pivot to eliminate this friction and restore full speed and agility to the homelab.

---

## The Pivot to Ansible

Rather than trying to force a strict, immutable model onto a lab that requires flexibility, I pivoted to Ansible. The goal was to eliminate unnecessary system resistance while retaining a clean, version-controlled infrastructure:

- **Pragmatic Flexibility:** Ansible allows declarative base configurations while leaving room for standard file access, third-party integrations, and quick local overrides when experimenting.
- **Streamlined Host Onboarding:** Adding a new node to the homelab is as simple as updating an inventory file and executing a playbook—no special per-host bootstrapping or Nix Store workarounds required.
- **Unified Infrastructure Tooling:** As the homelab transitions from single-node Docker Compose setups toward a Kubernetes cluster, using Ansible for bare-metal host provisioning establishes a single, cohesive automation pipeline across the entire infrastructure.

---

## Current Setup

All host configuration, dotfile deployment, and system bootstrap scripts are now maintained via Ansible: [infra/ansible](../../infra/ansible/)

## Last updated

- Date: 2026-09-15 11:22 UTC
- Previous commit: [3f086c8](https://github.com/adi-QTPi/ministry/commit/3f086c8)

_Date and commit hash are auto-generated. Commit hash is of the commit previous to the commit which modified this README._
