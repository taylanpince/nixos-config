#!/usr/bin/env bash
# Waybar module: flags an amdgpu SMU that has wedged with the iGPU shader clock
# pinned at its floor. Renders nothing at all while the GPU is healthy.
#
# The fault (first seen 2026-09-22, after a 14h s2idle resume) leaves the clock
# stuck at minimum no matter the load — the SMU ignores even an explicit
# power_dpm_force_performance_level=high. It is invisible in CPU and memory
# stats, so the desktop just feels slow for no apparent reason. Only a reboot
# clears it.
#
# Detection is deliberately NOT "clock == minimum": at genuine idle the GPU
# correctly sits there, so that check would fire constantly on healthy
# hardware. The fault is a floor clock *while the GPU is busy*, sustained
# across several polls so a burst caught mid-ramp can't trip it.
#
# Tests: ./gpu-clock.test.sh (drives this against a fake sysfs tree).

set -uo pipefail

DRM_ROOT="${GPU_DRM_ROOT:-/sys/class/drm}"
STATE_DIR="${GPU_STATE_DIR:-${XDG_RUNTIME_DIR:-/run/user/$UID}/waybar-gpu-clock}"
NOTIFY_CMD="${GPU_NOTIFY_CMD:-notify-send}"

BUSY_MIN=50    # % busy below which a floor clock is simply idle, not a fault
FLOOR_PCT=115  # a clock within this % of minimum counts as "at the floor"
TRIP_POLLS=3   # consecutive faulting polls before we believe it

# Anything unexpected renders as healthy rather than breaking the bar.
healthy() { printf '{"text":"","class":"ok","tooltip":""}\n'; exit 0; }
is_num() { [[ "${1:-}" =~ ^[0-9]+$ ]]; }

# Find the render card. Connector dirs (card1-DP-1, card1-eDP-1) also match
# card*, and DRM numbering isn't stable across boots, so match cardN exactly
# and confirm it actually exposes a DPM table.
dev=""
for c in "$DRM_ROOT"/card*/device; do
  [[ "$c" =~ /card[0-9]+/device$ ]] || continue
  [[ -r "$c/pp_dpm_sclk" ]] || continue
  dev="$c"
  break
done
[[ -n "$dev" ]] || healthy

# This APU prints pp_dpm_sclk as three lines: min / current* / max.
sclk_field() { sed -n "$1"'s/.*:[[:space:]]*\([0-9]\{1,\}\)Mhz.*/\1/p' "$dev/pp_dpm_sclk" 2>/dev/null; }
min="$(sclk_field 1)"
max="$(sclk_field '$')"
busy="$(cat "$dev/gpu_busy_percent" 2>/dev/null)"

# Prefer hwmon for the current clock: it reads the hardware directly, whereas
# the DPM table reprints its own bounds when a force level is applied (under
# force=high it showed min=max=2900 while the chip still ran at 600).
cur=""
for f in "$dev"/hwmon/hwmon*/freq1_input; do
  [[ -r "$f" ]] || continue
  hz="$(cat "$f" 2>/dev/null)"
  is_num "$hz" && cur=$(( hz / 1000000 ))
  break
done
[[ -n "$cur" ]] || cur="$(sclk_field 2)"

is_num "$min" && is_num "$max" && is_num "$busy" && is_num "$cur" || healthy
(( min > 0 )) || healthy

mkdir -p "$STATE_DIR" 2>/dev/null || healthy
count_file="$STATE_DIR/consecutive"
notified_file="$STATE_DIR/notified"

count="$(cat "$count_file" 2>/dev/null)"
is_num "$count" || count=0

floor=$(( min * FLOOR_PCT / 100 ))
if (( busy >= BUSY_MIN && cur <= floor )); then
  count=$(( count + 1 ))
else
  # Any healthy poll clears the run and re-arms the notification, so a later
  # trip is reported again.
  count=0
  rm -f "$notified_file"
fi
printf '%s\n' "$count" >"$count_file" 2>/dev/null

(( count >= TRIP_POLLS )) || healthy

# Notify once per trip, not once per poll.
if [[ ! -e "$notified_file" ]]; then
  "$NOTIFY_CMD" -u critical "GPU clock stuck" \
    "iGPU pinned at ${cur}MHz (max ${max}MHz) under ${busy}% load — SMU wedged, usually after a long suspend. Reboot to clear." \
    >/dev/null 2>&1
  : >"$notified_file"
fi

printf '{"text":"󰢮 GPU %sMHz","class":"wedged","alt":"wedged","tooltip":"iGPU stuck at %sMHz (min %s, max %s) at %s%% busy\\nDPM is not ramping — SMU wedged, usually after a long s2idle resume\\nReboot to clear; forcing power_dpm_force_performance_level does not work"}\n' \
  "$cur" "$cur" "$min" "$max" "$busy"
