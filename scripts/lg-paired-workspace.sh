#!/usr/bin/env bash
# Option 3 trial: move BOTH LG tiles' workspaces together with one key.
#
# Bound to Super+Left / Super+Right. The LG's two tiles each hold their own set
# of workspaces; this treats them as "pages" by position. Pressing next/prev
# moves both tiles to the same page index in their (sorted) workspace lists, so
# they move in lockstep and snap into sync even if they started on different
# pages. Wraps around at the ends. When focus is on the laptop (or the LG is
# absent) it just switches the focused screen's workspace, as before.
#
# Usage: lg-paired-workspace.sh next|prev
set -u

case "${1:-}" in
  next) d=1 ;;
  prev) d=-1 ;;
  *) echo "usage: $0 next|prev" >&2; exit 2 ;;
esac

command -v hyprctl >/dev/null 2>&1 || { echo "hyprctl not found" >&2; exit 1; }

mons=$(hyprctl monitors)
focused=$(printf '%s\n' "$mons" | awk '/^Monitor /{n=$2} /focused: yes/{print n; exit}')
have7=$(printf '%s\n' "$mons" | grep -c '^Monitor DP-7 ')
have8=$(printf '%s\n' "$mons" | grep -c '^Monitor DP-8 ')

fallback() { # single-screen relative switch, incl. empty workspaces (old behaviour)
  if [ "$d" = 1 ]; then
    hyprctl dispatch workspace r+1 >/dev/null
  else
    hyprctl dispatch workspace r-1 >/dev/null
  fi
}

# Only pair when focused on a tile and both tiles are present.
if { [ "$focused" != "DP-7" ] && [ "$focused" != "DP-8" ]; } \
   || [ "$have7" != "1" ] || [ "$have8" != "1" ]; then
  fallback; exit 0
fi

ws=$(hyprctl workspaces)
mapfile -t a7 < <(printf '%s\n' "$ws" | awk '/^workspace ID/ && /on monitor DP-7:/ {print $3}' | sort -n)
mapfile -t a8 < <(printf '%s\n' "$ws" | awk '/^workspace ID/ && /on monitor DP-8:/ {print $3}' | sort -n)
n7=${#a7[@]}; n8=${#a8[@]}
[ "$n7" -gt 0 ] && [ "$n8" -gt 0 ] || { fallback; exit 0; }

# Current page = position of the focused tile's active workspace in its list.
act=$(printf '%s\n' "$mons" | awk -v M="$focused" '$0 ~ "^Monitor "M" " {f=1} f && /active workspace:/ {print $3; exit}')
ref=("${a7[@]}"); [ "$focused" = "DP-8" ] && ref=("${a8[@]}")
idx=0
for i in "${!ref[@]}"; do [ "${ref[$i]}" = "$act" ] && { idx=$i; break; }; done

# Page within the shorter list so both tiles always have a target; wrap at ends.
len=$n7; [ "$n8" -lt "$len" ] && len=$n8
nidx=$(( (idx + d + len) % len ))

hyprctl --batch "\
  dispatch focusmonitor DP-7; dispatch workspace ${a7[$nidx]}; \
  dispatch focusmonitor DP-8; dispatch workspace ${a8[$nidx]}; \
  dispatch focusmonitor $focused" >/dev/null
