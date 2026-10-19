#!/usr/bin/env bash
# Re-apply the wallpaper across all screens when a monitor is added or the config
# is reloaded (which can move monitors), so the LG tiles (hot-plugged after login)
# get their halves of the current image instead of a black desktop. Reuses the
# current source image (no re-randomize) and lets set-random-wallpaper.sh handle
# the tile split and a no-op debounce.
set -u

sig="${HYPRLAND_INSTANCE_SIGNATURE:-}"
[ -n "$sig" ] || exit 0
sock="${XDG_RUNTIME_DIR}/hypr/${sig}/.socket2.sock"
state="${XDG_RUNTIME_DIR:-/tmp}/current-wallpaper"
setter="$HOME/.config/scripts/set-random-wallpaper.sh"
command -v socat >/dev/null 2>&1 || exit 0

reapply() {
  local src=""
  [ -s "$state" ] && src="$(cat "$state" 2>/dev/null)"
  bash "$setter" "$src"   # empty src -> setter picks a random image
}

# Give a newly added monitor a moment to settle, then reconcile all screens.
socat -U - UNIX-CONNECT:"$sock" | while read -r line; do
  case "$line" in
    monitoradded*|configreloaded*) sleep 0.6; reapply ;;
  esac
done
