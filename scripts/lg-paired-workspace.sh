#!/usr/bin/env bash
# Paired LG "page" switching, bound to Super+Left / Super+Right.
#
# The LG is two tiles (DP-7 left, DP-8 right). Pages use a FIXED workspace map,
# not the tiles' current workspace lists, so it is robust when an app spawns a
# window on another space and desyncs the tiles: pressing the key always drives
# BOTH tiles to the same known page, which re-aligns them.
#
#   page k  ->  left tile (DP-7) workspace 2k-1,  right tile (DP-8) workspace 2k
#   page 1 = (1,2)   page 2 = (3,4)   page 3 = (5,6)   page 4 = (7,8)
#
# On the laptop (or when the LG is absent) it just cycles that screen's own
# workspaces. Matches the persistent workspace scheme in hypr/hyprland.conf.
#
# Usage: lg-paired-workspace.sh next|prev
set -u

case "${1:-}" in
  next) d=1 ;;
  prev) d=-1 ;;
  *) echo "usage: $0 next|prev" >&2; exit 2 ;;
esac

command -v hyprctl >/dev/null 2>&1 || { echo "hyprctl not found" >&2; exit 1; }

left=DP-7
right=DP-8
pages=4   # keep in step with the persistent workspaces 1-8 in hyprland.conf

mons=$(hyprctl monitors)
focused=$(printf '%s\n' "$mons" | awk '/^Monitor /{n=$2} /focused: yes/{print n; exit}')
have_l=$(printf '%s\n' "$mons" | grep -c "^Monitor $left ")
have_r=$(printf '%s\n' "$mons" | grep -c "^Monitor $right ")

# Laptop focused, or a tile missing: cycle the focused screen's own workspaces.
if { [ "$focused" != "$left" ] && [ "$focused" != "$right" ]; } \
   || [ "$have_l" != "1" ] || [ "$have_r" != "1" ]; then
  if [ "$d" = 1 ]; then hyprctl dispatch workspace m+1 >/dev/null; else hyprctl dispatch workspace m-1 >/dev/null; fi
  exit 0
fi

# Derive the current page from the focused tile's active workspace via the map.
# If it isn't one of the page workspaces (an app put a stray space here), treat
# it as page 1 so the next press lands on a defined page and re-aligns the tiles.
act=$(printf '%s\n' "$mons" | awk -v M="$focused" '$0 ~ "^Monitor "M" " {f=1} f && /active workspace:/ {print $3; exit}')
page=0
if [ "$focused" = "$left" ]  && [ $((act % 2)) -eq 1 ]; then page=$(((act + 1) / 2)); fi
if [ "$focused" = "$right" ] && [ $((act % 2)) -eq 0 ]; then page=$((act / 2)); fi
if [ "$page" -lt 1 ] || [ "$page" -gt "$pages" ]; then page=1; fi

# Step with wrap within 1..pages, then drive both tiles to that page's pair.
page=$(( (page - 1 + d + pages) % pages + 1 ))
lws=$((2 * page - 1))
rws=$((2 * page))

hyprctl --batch "\
  dispatch focusmonitor $left;  dispatch workspace $lws; \
  dispatch focusmonitor $right; dispatch workspace $rws; \
  dispatch focusmonitor $focused" >/dev/null
