#!/usr/bin/env bash
# Recover the LG UltraFine 5K when the panel is powered but shows no image after
# a hotplug, and log every use so you can see how often it is needed.
#
# The streams are valid (the GPU is scanning out); the panel just failed to latch
# onto the two DisplayPort tiles. A DPMS off/on cycle is the quick nudge. If that
# does not help, --remodeset disables and re-adds the tiles, and if software does
# not recover it, a physical monitor power cycle (LG power button, or pull its AC
# for ~10 s) is the reliable fallback.
#
# Usage:
#   lg-dpms-cycle.sh             DPMS off/on the LG tiles (quick nudge)
#   lg-dpms-cycle.sh --remodeset Disable then re-add the tiles (stronger)
#   lg-dpms-cycle.sh --log       Print the log
#   lg-dpms-cycle.sh --count     Summarise how often it has been used
set -u

tiles=(DP-7 DP-8)
# Keep the re-add geometry in step with hypr/hyprland.conf.
declare -A geometry=(
  [DP-7]="2560x2880@60,0x0,1"
  [DP-8]="2560x2880@60,2560x0,1"
)
log="${XDG_STATE_HOME:-$HOME/.local/state}/lg-dpms-cycle.log"
mkdir -p "$(dirname "$log")"

case "${1:-}" in
  --log)
    [ -f "$log" ] && cat "$log" || echo "No log yet at $log"
    exit 0 ;;
  --count)
    if [ -f "$log" ]; then
      printf 'Recoveries logged: %s\n' "$(grep -c $'\tcycle\t' "$log")"
      printf 'By day (most recent last):\n'
      grep $'\tcycle\t' "$log" | cut -f1 | cut -d' ' -f1 | uniq -c | tail -14
    else
      echo "No log yet at $log"
    fi
    exit 0 ;;
esac

mode=dpms
[ "${1:-}" = "--remodeset" ] && mode=remodeset
ts=$(date '+%Y-%m-%d %H:%M:%S')

if ! command -v hyprctl >/dev/null 2>&1; then
  echo "hyprctl not found; are you in a Hyprland session?" >&2
  exit 1
fi

# Both tiles must be present to act.
present=yes
for t in "${tiles[@]}"; do
  hyprctl monitors all 2>/dev/null | grep -q "Monitor $t " || present=no
done
if [ "$present" = no ]; then
  printf '%s\tskip\t%s\tLG tiles not both connected\n' "$ts" "$mode" >> "$log"
  echo "LG tiles are not both connected; nothing to do. (logged)"
  exit 0
fi

if [ "$mode" = dpms ]; then
  for t in "${tiles[@]}"; do hyprctl dispatch dpms off "$t" >/dev/null; done
  sleep 3
  for t in "${tiles[@]}"; do hyprctl dispatch dpms on "$t" >/dev/null; done
else
  for t in "${tiles[@]}"; do hyprctl keyword monitor "$t,disable" >/dev/null; done
  sleep 2
  for t in "${tiles[@]}"; do hyprctl keyword monitor "$t,${geometry[$t]}" >/dev/null; done
fi

# Output churn during the cycle can orphan Waybar's bars; rebuild them too.
systemctl --user restart waybar.service >/dev/null 2>&1 || true

printf '%s\tcycle\t%s\n' "$ts" "$mode" >> "$log"
echo "LG $mode cycle done, Waybar restarted. If still blank, try --remodeset, then a physical monitor power cycle. (logged to $log)"
