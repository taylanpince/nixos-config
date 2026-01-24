#!/usr/bin/env bash
set -euo pipefail

SINK='@DEFAULT_AUDIO_SINK@'
STEP='0.05'          # 5%
WOB_FIFO="${WOB_FIFO:-/tmp/wobpipe}"

# Returns:
#   VOL_FRAC like "0.42"
#   MUTED "yes"|"no"
get_state() {
  local out vol muted
  out="$(wpctl get-volume "$SINK")"            # e.g. "Volume: 0.42 [MUTED]"
  vol="$(awk '{print $2}' <<<"$out")"
  if grep -q '\[MUTED\]' <<<"$out"; then
    muted="yes"
  else
    muted="no"
  fi
  printf '%s %s\n' "$vol" "$muted"
}

# Push 0-100 to wob
push_wob() {
  local pct="$1"
  # clamp
  if (( pct < 0 )); then pct=0; fi
  if (( pct > 100 )); then pct=100; fi
  printf '%s\n' "$pct" > "$WOB_FIFO"
}

cmd="${1:-}"

case "$cmd" in
  up)
    # unmute when raising volume (optional but nice)
    wpctl set-mute "$SINK" 0
    wpctl set-volume -l 1.0 "$SINK" "$STEP+"
    ;;
  down)
    wpctl set-volume -l 1.0 "$SINK" "$STEP-"
    ;;
  mute)
    wpctl set-mute "$SINK" toggle
    ;;
  *)
    echo "Usage: $0 {up|down|mute}" >&2
    exit 2
    ;;
esac

read -r vol muted < <(get_state)

if [[ "$muted" == "yes" ]]; then
  push_wob 0
else
  # vol is fraction, convert to int percent
  pct="$(awk -v v="$vol" 'BEGIN{printf("%d\n", (v*100)+0.5)}')"
  push_wob "$pct"
fi

