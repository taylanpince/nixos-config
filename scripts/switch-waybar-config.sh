#!/usr/bin/env bash
set -euo pipefail

EXT="DP-4"
WAYBAR_DIR="${HOME}/.config/waybar"
LINK="${WAYBAR_DIR}/config"
SINGLE="${WAYBAR_DIR}/config.single"
DUAL="${WAYBAR_DIR}/config.dual"

has_ext() {
  hyprctl monitors 2>/dev/null | grep -q "Monitor ${EXT} "
}

target="$SINGLE"
if has_ext; then
  target="$DUAL"
fi

current="$(readlink -f "$LINK" 2>/dev/null || true)"
if [[ "$current" != "$(readlink -f "$target")" ]]; then
  ln -sf "$target" "$LINK"
  systemctl --user restart waybar.service
fi

