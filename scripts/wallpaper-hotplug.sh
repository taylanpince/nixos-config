#!/usr/bin/env bash
# Keep the wallpaper on every screen, including monitors hot-plugged after login.
#
# set-random-wallpaper.sh runs once at login and only writes entries for the
# monitors present then. Since the LG tiles are plugged in after login, they come
# up with a black desktop. This listens for monitor-add events and re-applies the
# current wallpaper to all connected monitors. (This hyprpaper is too old for the
# `hyprctl hyprpaper` IPC, so it regenerates the config and restarts hyprpaper.)
set -u

sig="${HYPRLAND_INSTANCE_SIGNATURE:-}"
[ -n "$sig" ] || exit 0
sock="${XDG_RUNTIME_DIR}/hypr/${sig}/.socket2.sock"
conf="${XDG_RUNTIME_DIR:-/tmp}/hyprpaper.conf"
lock="${XDG_RUNTIME_DIR:-/tmp}/.wallpaper-hotplug.lock"
command -v socat >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

current_image() {
  awk -F'=' '/^[[:space:]]*path[[:space:]]*=/ {gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); print $2; exit}' "$conf" 2>/dev/null
}

reapply() {
  exec 9>"$lock"; flock 9   # serialize so overlapping events can't race hyprpaper
  local img monitors desired
  img="$(current_image)"
  [ -n "${img:-}" ] && [ -f "$img" ] || return 0
  monitors="$(hyprctl monitors -j 2>/dev/null | jq -r '.[].name')" || return 0
  [ -n "$monitors" ] || return 0

  desired="splash = false"$'\n'
  for m in $monitors; do
    desired+="wallpaper {"$'\n'"    monitor = $m"$'\n'"    path = $img"$'\n'"}"$'\n'
  done

  # No change (e.g., the second event of a two-tile plug) -> nothing to do.
  [ "$desired" = "$(cat "$conf" 2>/dev/null)" ] && return 0

  printf '%s' "$desired" > "$conf"
  pkill -x hyprpaper || true
  sleep 0.2
  hyprpaper & disown
}

# Give a newly added monitor a moment to settle, then reconcile all screens.
socat -U - UNIX-CONNECT:"$sock" | while read -r line; do
  case "$line" in
    monitoradded*) sleep 0.6; reapply ;;
  esac
done
