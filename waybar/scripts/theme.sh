#!/usr/bin/env bash
set -euo pipefail

MODE_FILE="$HOME/.config/theme-mode"
WAYBAR_DIR="$HOME/.config/waybar"
DARK="$WAYBAR_DIR/style-dark.css"
LIGHT="$WAYBAR_DIR/style-light.css"
STYLE="$WAYBAR_DIR/style.css"

get_mode() {
  if [[ -f "$MODE_FILE" ]]; then
    cat "$MODE_FILE"
  else
    echo "dark"
  fi
}

apply_mode() {
  local mode="$1"
  echo "$mode" > "$MODE_FILE"

  if [[ "$mode" == "dark" ]]; then
    ln -sf "$DARK" "$STYLE"
    # Best-effort GTK hint (doesn't break if absent)
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' >/dev/null 2>&1 || true
  else
    ln -sf "$LIGHT" "$STYLE"
    gsettings set org.gnome.desktop.interface color-scheme 'default' >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita' >/dev/null 2>&1 || true
  fi

  # reload Waybar CSS/config
  pkill -USR2 waybar || true
}

status_json() {
  local mode icon tip
  mode="$(get_mode)"
  if [[ "$mode" == "dark" ]]; then
    icon="󰖔"
    tip="Theme: Dark (click to toggle)"
    cls="dark"
  else
    icon="󰖨"
    tip="Theme: Light (click to toggle)"
    cls="light"
  fi
  printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$icon" "$tip" "$cls"
}

toggle() {
  local mode
  mode="$(get_mode)"
  if [[ "$mode" == "dark" ]]; then
    apply_mode "light"
  else
    apply_mode "dark"
  fi
}

case "${1:-}" in
  --status) status_json ;;
  --toggle) toggle ;;
  *) echo "usage: $0 --status|--toggle" >&2; exit 2 ;;
esac

