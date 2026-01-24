#!/usr/bin/env bash
set -euo pipefail

PIPE="${WOB_PIPE:-/tmp/wobpipe}"
STEP="${BRIGHTNESS_STEP:-5}"

clamp() {
  local v="$1"
  (( v < 0 )) && v=0
  (( v > 100 )) && v=100
  echo "$v"
}

get_brightness() {
  # brightnessctl prints "Current brightness: 12345 (50%)"
  brightnessctl -m | awk -F, '{gsub(/%/,"",$4); print $4}' | tail -n1
}

set_brightness() {
  local target="$1"
  brightnessctl set "${target}%" >/dev/null
}

usage() { echo "usage: osd-brightness {raise|lower|set <0-100>}"; exit 2; }

[[ $# -ge 1 ]] || usage

case "$1" in
  raise)
    cur="$(get_brightness || echo 0)"
    cur="${cur:-0}"
    target="$(clamp $((cur + STEP)))"
    set_brightness "$target"
    ;;
  lower)
    cur="$(get_brightness || echo 0)"
    cur="${cur:-0}"
    target="$(clamp $((cur - STEP)))"
    set_brightness "$target"
    ;;
  set)
    [[ $# -eq 2 ]] || usage
    target="$(clamp "$2")"
    set_brightness "$target"
    ;;
  *)
    usage
    ;;
esac

# After setting, read back the true state and send to wob
final="$(get_brightness || echo 0)"
final="${final:-0}"
final="$(clamp "$final")"

# Only write if pipe exists (wob running)
if [[ -p "$PIPE" ]]; then
  printf '%s\n' "$final" > "$PIPE"
fi

