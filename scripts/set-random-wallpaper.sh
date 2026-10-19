#!/usr/bin/env bash
# Set the wallpaper across all screens, splitting one wide image across the LG's
# two tiles so it reads as a single seamless monitor.
#
#   - The LG is two 2560x2880 tiles side by side (DP-7 | DP-8). One 5120x2880
#     image is cut into a left and a right half, one per tile, so it spans the
#     seam continuously.
#   - The laptop (eDP) gets a cover-cropped version of the same image.
#   - A lone tile, or any other screen, gets a cover-cropped full image.
#
# Source images live at the top level of ~/wallpapers (ideally 5120x2880 or
# larger, 16:9). Derived halves/crops are cached under ~/.cache/wallpaper-tiles.
#
# Usage:
#   set-random-wallpaper.sh            # pick a random source image
#   set-random-wallpaper.sh <image>    # use a specific image (hotplug re-apply)
set -euo pipefail

WALLDIR="$HOME/wallpapers"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-tiles"
RUNTIME_CONF="${XDG_RUNTIME_DIR:-/tmp}/hyprpaper.conf"
CONF_LINK="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprpaper.conf"
STATE="${XDG_RUNTIME_DIR:-/tmp}/current-wallpaper"
TILE_W=2560 TILE_H=2880   # one LG tile

mkdir -p "$CACHE"

# Keep ~/.config/hypr/hyprpaper.conf pointing at the runtime config.
if [ ! -L "$CONF_LINK" ] || [ "$(readlink "$CONF_LINK" 2>/dev/null)" != "$RUNTIME_CONF" ]; then
  rm -f "$CONF_LINK"; ln -s "$RUNTIME_CONF" "$CONF_LINK"
fi

# Pick the source image: explicit arg, else a random one from ~/wallpapers.
src="${1:-}"
if [ -z "$src" ] || [ ! -f "$src" ]; then
  src="$(find "$WALLDIR" -maxdepth 1 -type f \
      \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
      -print0 | shuf -z -n1 | tr -d '\0')"
fi
[ -n "${src:-}" ] && [ -f "$src" ] || exit 0
printf '%s\n' "$src" > "$STATE"

# Derive the pieces once per source (cache keyed by content path).
key="$(printf '%s' "$src" | sha1sum | cut -c1-16)"
full="$CACHE/$key-full.png"
left="$CACHE/$key-left.png"
right="$CACHE/$key-right.png"
if [ ! -s "$left" ] || [ ! -s "$right" ] || [ ! -s "$full" ]; then
  magick "$src" -resize 5120x2880^ -gravity center -extent 5120x2880 "$full"
  magick "$full" -crop "${TILE_W}x${TILE_H}+0+0"            +repage "$left"
  magick "$full" -crop "${TILE_W}x${TILE_H}+${TILE_W}+0"    +repage "$right"
fi

# Enumerate connected monitors; bail if the query fails.
mapfile -t mons < <(hyprctl monitors -j 2>/dev/null | jq -r '.[] | "\(.name)\t\(.x)\t\(.width)\t\(.height)"')
[ "${#mons[@]}" -gt 0 ] || exit 0

# Identify the two LG tiles (2560x2880) and order them left-to-right by x.
tile_lines=()
for m in "${mons[@]}"; do
  IFS=$'\t' read -r name x w h <<<"$m"
  [ "$w" = "$TILE_W" ] && [ "$h" = "$TILE_H" ] && tile_lines+=("$x $name")
done
left_name=""; right_name=""
if [ "${#tile_lines[@]}" -ge 2 ]; then
  sorted="$(printf '%s\n' "${tile_lines[@]}" | sort -n)"
  left_name="$(printf '%s\n' "$sorted" | sed -n '1p' | cut -d' ' -f2)"
  right_name="$(printf '%s\n' "$sorted" | sed -n '2p' | cut -d' ' -f2)"
fi

# Build the hyprpaper config: halves on the tiles, cover-crops elsewhere.
# The layout comment records every screen's geometry, so moving a monitor (e.g.
# a hyprctl reload with new positions) counts as a change and restarts hyprpaper:
# its surfaces otherwise stay at the old positions and the desktop goes blank.
layout="$(hyprctl monitors -j 2>/dev/null | jq -r '[.[] | "\(.name)@\(.x),\(.y):\(.width)x\(.height)"] | join(" ")')"
desired="# layout: $layout"$'\n'"splash = false"$'\n'
for m in "${mons[@]}"; do
  IFS=$'\t' read -r name x w h <<<"$m"
  if [ "$name" = "$left_name" ]; then img="$left"
  elif [ "$name" = "$right_name" ]; then img="$right"
  else
    img="$CACHE/$key-${name}.png"
    [ -s "$img" ] || magick "$full" -resize "${w}x${h}^" -gravity center -extent "${w}x${h}" "$img"
  fi
  desired+="wallpaper {"$'\n'"    monitor = $name"$'\n'"    path = $img"$'\n'"}"$'\n'
done

# Skip the restart if nothing changed and hyprpaper is already up (debounces the
# second monitor event of a two-tile hot-plug, and plain config reloads).
if [ "$desired" = "$(cat "$RUNTIME_CONF" 2>/dev/null)" ] && pgrep -x hyprpaper >/dev/null; then
  exit 0
fi

printf '%s' "$desired" > "$RUNTIME_CONF"
pkill -x hyprpaper || true
sleep 0.2
hyprpaper >/dev/null 2>&1 & disown
