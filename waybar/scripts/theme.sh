#!/usr/bin/env bash
set -euo pipefail

MODE_FILE="$HOME/.config/theme-mode"
CFG="$HOME/.config"
WAYBAR_DIR="$CFG/waybar"

get_mode() { [[ -f "$MODE_FILE" ]] && cat "$MODE_FILE" || echo "dark"; }

apply_mode() {
  local mode="$1"
  echo "$mode" > "$MODE_FILE"

  # --- Desktop appearance signal for GUI/web apps (Brave/Slack/Superhuman) ---
  # 'prefer-light' -> portal color-scheme 2 (true light); 'default' would be 0 (no pref).
  if [[ "$mode" == "dark" ]]; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'  >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'    >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface gtk-application-prefer-dark-theme true  >/dev/null 2>&1 || true
  else
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita'         >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface gtk-application-prefer-dark-theme false >/dev/null 2>&1 || true
  fi

  # --- Per-app symlink swaps (suffix = mode) ---
  ln -sfn "style-$mode.css"      "$WAYBAR_DIR/style.css"          || true
  ln -sfn "theme-$mode.conf"     "$CFG/kitty/theme.conf"          || true
  ln -sfn "style-$mode.css"      "$CFG/wofi/style.css"            || true
  ln -sfn "solarized-$mode.rasi" "$CFG/rofi/themes/current.rasi"  || true
  ln -sfn "wob-$mode.ini"        "$CFG/wob/wob.ini"               || true
  ln -sfn "palette-$mode.css"    "$CFG/swaync/palette.css"        || true

  # --- Reloads ---
  # IMPORTANT: reload waybar LAST. When this script is launched from waybar's
  # on-click, `pkill -USR2 waybar` makes waybar reload, which kills this child
  # process mid-run. Doing every other reload first guarantees kitty/swaync/wob
  # are handled before waybar tears us down. (The keybind path is unaffected.)
  pkill -USR1 kitty  2>/dev/null || true          # kitty live config reload
  swaync-client --reload-css 2>/dev/null || true  # swaync CSS reload
  "$CFG/scripts/start-wob.sh" 2>/dev/null || true # restart wob daemon w/ new ini
  pkill -USR2 waybar 2>/dev/null || true          # waybar CSS reload — MUST be last
}

status_json() {
  local mode icon tip cls
  mode="$(get_mode)"
  if [[ "$mode" == "dark" ]]; then icon="󰖔"; tip="Theme: Dark (click to toggle)"; cls="dark"
  else icon="󰖨"; tip="Theme: Light (click to toggle)"; cls="light"; fi
  printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$icon" "$tip" "$cls"
}

toggle() { [[ "$(get_mode)" == "dark" ]] && apply_mode "light" || apply_mode "dark"; }

case "${1:-}" in
  --status) status_json ;;
  --toggle) toggle ;;
  --light)  apply_mode "light" ;;
  --dark)   apply_mode "dark" ;;
  *) echo "usage: $0 --status|--toggle|--light|--dark" >&2; exit 2 ;;
esac
