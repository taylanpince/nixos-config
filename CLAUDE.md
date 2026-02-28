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
Configs are symlinked from `/etc/nixos/config/` to `~/.config/`:
```bash
ln -s /etc/nixos/config/hypr ~/.config/hypr
```

### Adding System Packages
Edit `nixos/configuration.nix`, add to `environment.systemPackages`:
```nix
environment.systemPackages = with pkgs; [
  # add packages here
];
```

### Modifying Keybindings
Edit `hypr/hyprland.conf` - uses SUPER as mod key, vim-style navigation (H/J/K/L)

### Enterprise Security
CrowdStrike and Kolide require manual setup steps documented in `KOLIDE.md`. The dpkg status shim in `kolide.nix` satisfies Kolide's package-based compliance checks on NixOS.
