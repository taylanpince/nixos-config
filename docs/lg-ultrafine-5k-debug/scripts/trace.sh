#!/usr/bin/env bash
# Bounded read-only event capture. The owner performs physical connection changes.
set -u
umask 077
project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
label=${1:?Usage: trace.sh RUN_LABEL [SECONDS]}
duration=${2:-600}
[[ $label =~ ^[a-zA-Z0-9_-]+$ && $duration =~ ^[0-9]+$ ]] || exit 2
(( duration >= 1 && duration <= 1800 )) || exit 2
out=$(mktemp -d "$project/evidence/$(date +%Y%m%dT%H%M%S)-${label}-trace-XXXXXX")
date --iso-8601=seconds > "$out/start.txt"
timeout "$duration" journalctl -k -b -n 0 -f -o short-monotonic > "$out/kernel-live.txt" 2>&1 &
kernel_pid=$!
timeout "$duration" udevadm monitor --kernel --udev --property --subsystem-match=thunderbolt --subsystem-match=typec --subsystem-match=drm --subsystem-match=usb > "$out/udev-live.txt" 2>&1 &
udev_pid=$!
cleanup() { kill "$kernel_pid" "$udev_pid" 2>/dev/null || true; wait "$kernel_pid" "$udev_pid" 2>/dev/null || true; }
trap cleanup EXIT
trap 'exit 130' INT TERM
printf 'TRACE_DIR=%s\n' "$out"
deadline=$((SECONDS + duration))
previous=''
while (( SECONDS < deadline )); do
  state=$(
    for d in /sys/bus/thunderbolt/devices/*; do
      [[ -e $d ]] && printf 'TB %s\n' "${d##*/}"
    done
    for p in /sys/class/drm/card*-*/status; do
      [[ -r $p ]] && printf 'DRM %s %s\n' "$p" "$(cat "$p")"
    done
    for p in /sys/class/typec/port*/power_operation_mode; do
      [[ -r $p ]] && printf 'TYPEC %s %s\n' "$p" "$(cat "$p")"
    done
  )
  if [[ $state != "$previous" ]]; then
    { date --iso-8601=seconds; printf '%s\n' "$state"; } | tee -a "$out/state-changes.txt"
    previous=$state
  fi
  sleep 2
done
