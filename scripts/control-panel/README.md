# NixOS Control Panel

A TUI-based system control panel using [gum](https://github.com/charmbracelet/gum).

## Requirements

Add `gum` to your NixOS configuration:

```nix
environment.systemPackages = with pkgs; [
  gum
];
```

## Usage

```bash
~/config/scripts/control-panel/main.sh
```

## Hyprland Integration

Add to your `hyprland.conf`:

```conf
# Control panel keybind
bind = $mod, P, exec, kitty --class control-panel -e ~/config/scripts/control-panel/main.sh

# Window rules for floating control panel
windowrulev2 = float, class:^(control-panel)$
windowrulev2 = size 600 500, class:^(control-panel)$
windowrulev2 = center, class:^(control-panel)$
```

## Features

- **System**: Power profiles, sleep, reboot, shutdown, services
- **Display**: Brightness, monitor info
- **Network**: WiFi, VPN, Tailscale
- **Audio**: Volume, output/input device selection, mute
- **Theme**: Wallpaper selection
- **Packages**: Search nixpkgs, rebuild NixOS, garbage collection, system info

## Customization

Colors are set in `lib/common.sh` using Catppuccin Mocha palette.
Modify to match your theme.
