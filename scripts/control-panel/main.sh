#!/usr/bin/env bash
# NixOS Control Panel - TUI system management
# Requires: gum

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

show_main_menu() {
  clear
  show_header
  
  local choice
  choice=$(gum choose --cursor.foreground="$ACCENT" --selected.foreground="$ACCENT" \
    "󰒓  System" \
    "󰍹  Display" \
    "󰖩  Network" \
    "󰕾  Audio" \
    "󰸌  Theme" \
    "󰏗  Packages" \
    "󰗼  Exit")

  case "$choice" in
    *System*)   source "$SCRIPT_DIR/lib/system.sh"   && show_system_menu ;;
    *Display*)  source "$SCRIPT_DIR/lib/display.sh"  && show_display_menu ;;
    *Network*)  source "$SCRIPT_DIR/lib/network.sh"  && show_network_menu ;;
    *Audio*)    source "$SCRIPT_DIR/lib/audio.sh"    && show_audio_menu ;;
    *Theme*)    source "$SCRIPT_DIR/lib/theme.sh"    && show_theme_menu ;;
    *Packages*) source "$SCRIPT_DIR/lib/packages.sh" && show_packages_menu ;;
    *Exit*)     exit 0 ;;
  esac
}

# Check dependencies
if ! command -v gum &> /dev/null; then
  echo "Error: gum is required. Add it to your NixOS configuration."
  echo "  environment.systemPackages = with pkgs; [ gum ];"
  exit 1
fi

# Main loop
while true; do
  show_main_menu
done
