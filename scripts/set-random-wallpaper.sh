#!/usr/bin/env bash
set -euo pipefail

WALLDIR="${1:-$HOME/wallpapers}"

img="$(
  find "$WALLDIR" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) -print0 \
  | shuf -z -n1 \
  | tr -d '\0'
)"

[ -n "${img:-}" ] || exit 0

# Hyprpaper must be running for hyprctl hyprpaper commands to work.
# Give it a moment in case Hyprland is still starting up.
for _ in {1..20}; do
  hyprctl hyprpaper listloaded >/dev/null 2>&1 && break
  sleep 0.05
done

hyprctl hyprpaper unload all || true
hyprctl hyprpaper preload "$img"
# Apply to all monitors (empty monitor name before the comma)
hyprctl hyprpaper wallpaper ",$img"

