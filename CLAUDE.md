# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a NixOS dotfiles configuration repository for a development workstation running Hyprland (Wayland compositor). The system uses NixOS flakes for declarative, reproducible configuration.

**Hostname:** bloomware
**System:** NixOS 25.11 (nixos-unstable channel)
**Desktop:** Hyprland + Waybar + Kitty terminal

## Common Commands

### System Rebuild
```bash
sudo nixos-rebuild switch              # Apply configuration changes
sudo nixos-rebuild switch --flake .    # Apply using flake (from nixos/ dir)
```

### Development Shells
```bash
nix develop .#go        # Go development environment
nix develop .#python    # Python development environment
nix develop .#node      # Node.js development environment
nix develop .#pulumi    # Pulumi development environment
```

### Package Management
```bash
nix search nixpkgs <package>    # Search for packages
sudo nix-collect-garbage -d     # Clean old generations
```

## Architecture

### NixOS Configuration (nixos/)
- `flake.nix` - Flake definition with nixosConfigurations.bloomware and devShells
- `configuration.nix` - Main system config (imports hardware, falcon, kolide modules)
- `falcon.nix` - CrowdStrike Falcon sensor with FHS wrapper
- `kolide.nix` - Kolide compliance agent with dpkg status shim
- `shells/*.nix` - Development shell definitions (go, python, node, pulumi)

### Desktop Environment
- `hypr/hyprland.conf` - Window manager keybindings, layouts, rules
- `hypr/mocha.conf` - Catppuccin Mocha color scheme
- `waybar/` - Status bar with config variants for single/dual display
- `waybar/scripts/` - Custom modules (volume, brightness, bluetooth, theme, etc.)

### User Services (systemd/user/)
- `waybar.service` - Status bar daemon
- `polkit-gnome-agent.service` - Authentication agent for GUI dialogs

### Helper Scripts (scripts/)
Key scripts for desktop functionality:
- `display-hotplug.sh` - Multi-monitor workspace management
- `window-switcher.sh` - Advanced window switcher with MRU tracking
- `switch-waybar-config.sh` - Theme/display mode switching
- `osd-volume.sh`, `osd-brightness.sh` - Visual feedback via wob

## Key Patterns

### Dotfile Management
Dotfiles reach `~/.config` two different ways. Know which, because it
determines how an edit goes live. (The repo lives at `~/config`; `/etc/nixos`
→ `~/config/nixos`.)

**Declarative via home-manager (needs a rebuild).** `nixos/home/taylan.nix`
copies these into the Nix store with `xdg.configFile.<name>.source = ../../<name>`:
`hypr`, `wlogout`, `mpv`, `nvim`, `scripts`, `pnpm`, `starship`. The resulting
`~/.config/<name>` is a **read-only Nix-store symlink, not the repo file** —
editing the repo does nothing until you rebuild:
```bash
sudo nixos-rebuild switch --flake ./nixos#bloomware   # from repo root
```
For Hyprland changes, follow with `hyprctl reload`. (`hyprctl reload` on its
own re-reads the *old* Nix-store copy, so it can't pick up an unbuilt edit.)

**Directly symlinked (live immediately).** These are excluded from home-manager
and symlinked straight to the repo, so edits apply on the next app restart with
no rebuild: `waybar`, `kitty`, `wofi`, `rofi`, `wob`, `swaync`. One-time setup:
```bash
for a in waybar kitty wofi rofi wob swaync; do ln -sfn ~/config/$a ~/.config/$a; done
```

### Adding System Packages
Edit `nixos/configuration.nix`, add to `environment.systemPackages`:
```nix
environment.systemPackages = with pkgs; [
  # add packages here
];
```

### Modifying Keybindings
Edit `hypr/hyprland.conf` - uses SUPER as mod key, vim-style navigation (H/J/K/L).
`hypr` is declaratively managed, so apply changes with a rebuild + `hyprctl reload`
(see Dotfile Management) — editing the file alone won't take effect.

### Enterprise Security
CrowdStrike and Kolide require manual setup steps documented in `KOLIDE.md`. The dpkg status shim in `kolide.nix` satisfies Kolide's package-based compliance checks on NixOS.
