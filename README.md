# NixOS Configuration

A complete NixOS setup with Hyprland window manager, featuring a clean and efficient development environment.

## Overview

This configuration includes:
- **NixOS 25.11** with latest kernel
- **Hyprland** Wayland compositor with custom keybindings
- **Waybar** status bar with custom modules
- **Kitty** terminal with Solarized Dark theme
- **Starship** prompt with Solarized palette
- Development tools and utilities

## System Configuration

### Core Features
- Latest Linux kernel
- NetworkManager for networking
- PipeWire for audio
- 1Password integration
- Touchpad support with natural scrolling
- US keyboard layout with Alt/Win swap

### Installed Packages
- **Development**: git, curl, vim, wget, nodejs_22, pnpm, opencode
- **Terminal**: kitty, starship, bash-completion, fzf, ripgrep, bat, eza, fd, zoxide, jq, jless
- **Desktop**: waybar, dunst, wl-clipboard, grim, slurp, rofi, wofi
- **System**: pavucontrol, pulseaudio, networkmanagerapplet, wireplumber
- **Browser**: Brave
- **Security**: hyprlock, hypridle

### Fonts
- Inter (UI font)
- JetBrains Mono Nerd Font (terminal)

## Directory Structure

```
config/
├── nixos/
│   ├── configuration.nix          # Main system configuration
│   └── hardware-configuration.nix # Hardware-specific settings
├── hypr/
│   ├── hyprland.conf              # Hyprland window manager config
│   ├── hypridle.conf              # Idle management
│   └── mocha.conf                 # Catppuccin Mocha color scheme
├── waybar/
│   ├── config                     # Waybar configuration
│   ├── style.css                  # Waybar styling
│   └── scripts/                   # Custom scripts (volume, mic, calendar)
├── kitty/
│   └── kitty.conf                 # Terminal emulator config
├── starship/
│   └── starship.toml              # Shell prompt configuration
├── rofi/
│   ├── config.rasi                # Rofi theming
│   └── themes/                    # Custom themes
├── wofi/
│   └── style.css                  # Wofi styling
├── keyd/
│   └── default.conf               # Keyboard remapping
├── systemd/
│   └── user/                      # User services
├── bashrc                         # Shell configuration
└── inputrc                        # Input configuration
```

## Installation

### Prerequisites
- NixOS installation media
- Target system with UEFI boot support

### Setup Steps

1. **Clone this repository:**
   ```bash
   git clone <repository-url> /mnt/etc/nixos/config
   ```

2. **Generate hardware configuration:**
   ```bash
   nixos-generate-config --root /mnt
   ```

3. **Copy configuration:**
   ```bash
   cp /mnt/etc/nixos/config/nixos/configuration.nix /mnt/etc/nixos/
   cp /mnt/etc/nixos/config/nixos/hardware-configuration.nix /mnt/etc/nixos/
   ```

4. **Install NixOS:**
   ```bash
   nixos-install
   ```

5. **Reboot and setup user configs:**
   ```bash
   # After reboot, copy dotfiles to home directory
   cp -r /etc/nixos/config/hypr ~/.config/
   cp -r /etc/nixos/config/waybar ~/.config/
   cp -r /etc/nixos/config/kitty ~/.config/
   cp -r /etc/nixos/config/starship ~/.config/
   cp -r /etc/nixos/config/rofi ~/.config/
   cp -r /etc/nixos/config/wofi ~/.config/
   cp /etc/nixos/config/bashrc ~/.bashrc
   cp /etc/nixos/config/inputrc ~/.inputrc
   ```

## Configuration Details

### Hyprland
- **Mod key**: SUPER (Windows key)
- **Keybindings**:
  - `SUPER + ENTER`: Launch Kitty
  - `SUPER + W`: Close window
  - `SUPER + F`: Fullscreen
  - `SUPER + L`: Lock screen
  - `SUPER + SHIFT + L`: Suspend
  - `SUPER + H/J/K/L`: Navigate windows
  - `SUPER + SHIFT + H/J/K/L`: Move windows
  - `SUPER + 1-9`: Switch workspaces
  - `SUPER + SHIFT + 1-9`: Move to workspace
  - `SUPER + SPACE`: Application launcher (Rofi)
  - `SUPER + TAB`: Window switcher
  - `SUPER + S`: Screenshot (area selection)

### Waybar Modules
- **Workspaces**: Hyprland workspace indicators
- **Clock**: Date/time with calendar popup
- **Volume**: Audio control with scroll adjustment
- **Microphone**: Mic toggle
- **Network**: WiFi/Ethernet status
- **Battery**: Power status and remaining time
- **Tray**: System tray icons

### Terminal (Kitty)
- **Font**: JetBrains Mono Nerd Font (13pt)
- **Theme**: Solarized Dark
- **Features**: Ligatures enabled, custom padding

### Shell (Bash + Starship)
- **Enhancements**: zoxide for smart navigation, fzf for fuzzy search
- **Aliases**: `ls` uses eza with git info, `dv` for development directory
- **History**: Large history with deduplication
- **Prompt**: Starship with Solarized Dark palette

## Customization

### Adding Packages
Edit `nixos/configuration.nix` and add packages to the `environment.systemPackages` list:

```nix
environment.systemPackages = with pkgs; [
  # existing packages...
  new-package
];
```

### Modifying Hyprland
Edit `hypr/hyprland.conf` for keybindings, layouts, and rules.

### Theming
- **Colors**: Edit `hypr/mocha.conf` for Catppuccin colors
- **Waybar**: Modify `waybar/style.css` for bar styling
- **Rofi**: Update `rofi/themes/solarized-dark.rasi`

## Maintenance

### Update System
```bash
sudo nixos-rebuild switch
```

### Clean Old Generations
```bash
sudo nix-collect-garbage -d
```

### Search Packages
```bash
nix search <package-name>
```

## Troubleshooting

### Common Issues
- **Wayland apps not working**: Ensure `xdg.portal` is configured
- **Audio issues**: Check PipeWire and WirePlumber services
- **Display problems**: Verify GPU drivers in hardware configuration

### Logs
- **System logs**: `journalctl -b`
- **Hyprland logs**: Check `~/.local/share/hyprland/hyprland.log`

## License

This configuration is provided as-is. Feel free to adapt it to your needs.