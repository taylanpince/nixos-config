#!/usr/bin/env bash
set -euo pipefail

WALLDIR="${1:-$HOME/wallpapers}"
RUNTIME_CONF="${XDG_RUNTIME_DIR:-/tmp}/hyprpaper.conf"
CONF_LINK="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprpaper.conf"

# Ensure the symlink exists pointing to runtime location
if [ ! -L "$CONF_LINK" ]; then
  rm -f "$CONF_LINK"
  ln -s "$RUNTIME_CONF" "$CONF_LINK"
fi

img="$(
  find "$WALLDIR" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) -print0 \
  | shuf -z -n1 \
  | tr -d '\0'
)"

[ -n "${img:-}" ] || exit 0

# Get all connected monitors
monitors=$(hyprctl monitors -j | jq -r '.[].name')

# Build hyprpaper config (new format for hyprpaper 0.8+)
{
  echo "splash = false"
  for mon in $monitors; do
    cat <<EOF
wallpaper {
    monitor = $mon
    path = $img
}
EOF
  done
} > "$RUNTIME_CONF"

# Restart hyprpaper to apply the new config
pkill -x hyprpaper || true
sleep 0.1
hyprpaper &
disown
