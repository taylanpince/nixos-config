#!/usr/bin/env bash
# Approved transient A/B/A test. No installed module, boot or firmware writes.
set -euo pipefail
mode=${1:---check}
[[ $# -le 1 && ( $mode == --check || $mode == --run ) ]] || exit 2
project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
module="$project/evidence/ucsi-build-CHVJka/drivers/usb/typec/ucsi/typec_ucsi.ko"
expected=14d7dd3ceb82c473058c212664d4a74a7467c7672cbb125d44f39ae19cf6f625
[[ $(uname -r) == 6.18.44 ]] || { echo 'Wrong kernel; nothing changed.' >&2; exit 1; }
actual=$(sha256sum -- "$module")
[[ ${actual%% *} == "$expected" ]] || { echo 'Module hash mismatch.' >&2; exit 1; }
[[ $(cat /sys/class/dmi/id/sys_vendor) == Framework &&
   $(cat /sys/class/dmi/id/product_name) == 'Laptop 13 (AMD Ryzen AI 300 Series)' ]] || exit 1
(( EUID == 0 )) || { echo 'Run with sudo in a local terminal.' >&2; exit 1; }
exec 9>/run/lock/lg-ucsi-pdo-trial.lock
flock -n 9 || { echo 'Another PDO trial is running.' >&2; exit 1; }
[[ -t 0 || $mode == --check ]] || { echo 'An interactive terminal is required.' >&2; exit 1; }
[[ $(cat /sys/class/power_supply/BAT1/capacity) -ge 30 ]] || {
  echo 'Battery below 30%; charge before the trial.' >&2; exit 1;
}
[[ ! -e /sys/module/typec_ucsi/parameters/lab_skip_partner_pdos ]] || {
  echo 'Lab module already loaded; restore stock before a new trial.' >&2; exit 1;
}
[[ -d /sys/module/ucsi_acpi && -d /sys/module/typec_ucsi ]] || exit 1
for holder in /sys/module/typec_ucsi/holders/*; do
  [[ -e $holder ]] || continue
  [[ ${holder##*/} == ucsi_acpi ]] || { echo "Unexpected holder: $holder" >&2; exit 1; }
done
for holder in /sys/module/ucsi_acpi/holders/*; do
  [[ ! -e $holder ]] || { echo "Unexpected ACPI holder: $holder" >&2; exit 1; }
done
if rg -q 'ucsi' /sys/kernel/tracing/kprobe_events; then
  echo 'UCSI probes still registered; stop their capture first.' >&2; exit 1
fi
for cmd in modprobe insmod timeout modinfo journalctl; do command -v "$cmd" >/dev/null; done
stock_core=$(readlink -f -- "$(modinfo -n typec_ucsi)")
stock_acpi=$(readlink -f -- "$(modinfo -n ucsi_acpi)")
[[ $stock_core == /nix/store/* && $stock_acpi == /nix/store/* ]] || exit 1
bash "$project/scripts/ucsi-probe-window.sh" --check
echo 'Trial preflight passed. Stock modules and exact lab binary found.'
[[ $mode == --run ]] || exit 0

umask 077
out=$(mktemp -d "$project/evidence/$(date -u +%Y%m%dT%H%M%SZ)-pdo-aba-XXXXXX")
exec > >(tee -a "$out/session.txt") 2>&1
changed=0
capture_pid=
start=$(date --iso-8601=seconds)

restore_stock() {
  (( changed )) || return 0
  echo 'Restoring stock UCSI modules...'
  if [[ -d /sys/module/ucsi_acpi ]]; then
    timeout --kill-after=5 20 modprobe -r ucsi_acpi || return 1
  fi
  if [[ -d /sys/module/typec_ucsi ]]; then
    timeout --kill-after=5 20 modprobe -r typec_ucsi || return 1
  fi
  timeout --kill-after=5 20 modprobe ucsi_acpi || return 1
  [[ -d /sys/module/ucsi_acpi && -d /sys/module/typec_ucsi &&
     ! -e /sys/module/typec_ucsi/parameters/lab_skip_partner_pdos ]] || return 1
  changed=0
  echo 'STOCK RESTORED: experimental parameter absent.'
}

cleanup() {
  local rc=$?
  trap - EXIT INT TERM HUP
  set +e
  if [[ -n $capture_pid ]]; then
    kill -TERM "$capture_pid" 2>/dev/null
    wait "$capture_pid"
    capture_pid=
  fi
  if ! restore_stock; then
    echo 'RESTORATION FAILED: reboot the unchanged normal system; do not force unload.'
    rc=1
  fi
  timeout 15 journalctl -k -b --since "$start" --no-pager -o short-monotonic > "$out/kernel.txt" 2>&1
  printf 'exit=%s\n' "$rc" > "$out/result.txt"
  if [[ ${SUDO_UID:-} =~ ^[0-9]+$ && ${SUDO_GID:-} =~ ^[0-9]+$ ]]; then
    chown -R -- "$SUDO_UID:$SUDO_GID" "$out"
  fi
  echo "Trial evidence: $out"
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

alert() {
  if [[ ${SUDO_UID:-} =~ ^[0-9]+$ ]]; then
    timeout 8 sudo -u "#$SUDO_UID" env "XDG_RUNTIME_DIR=/run/user/$SUDO_UID" \
      bash "$project/scripts/alert.sh" || echo 'SPEAKER ALERT FAILED: watch terminal prompts.'
  else
    echo 'No desktop user identity for speaker alert; watch terminal prompts.'
  fi
}

snapshot() {
  local dest=$1 connector device attribute
  mkdir -p "$dest"
  date --iso-8601=ns > "$dest/time.txt"
  for device in /sys/bus/thunderbolt/devices/*; do
    [[ -e $device ]] || continue
    printf '%s\n' "${device##*/}"
  done > "$dest/thunderbolt.txt"
  for connector in /sys/class/drm/card*-*; do
    [[ -r $connector/status ]] || continue
    printf '%s: %s\n' "${connector##*/}" "$(cat "$connector/status")"
    cat "$connector/edid" > "$dest/${connector##*/}.edid" 2>/dev/null || true
    cat "$connector/modes" > "$dest/${connector##*/}.modes" 2>/dev/null || true
  done > "$dest/drm.txt"
  for attribute in /sys/class/power_supply/BAT1/{capacity,status} /sys/class/power_supply/ACAD/online; do
    [[ -r $attribute ]] || continue
    printf '%s: %s\n' "$attribute" "$(cat "$attribute")"
  done > "$dest/power.txt"
}

printf 'A/B/A display-enumeration trial. Ctrl-C stops and restores stock.\nEvidence: %s\n' "$out"
for leg in A1 B A2; do
  flag=0
  [[ $leg != B ]] || flag=1
  legdir="$out/$leg"
  mkdir "$legdir"
  alert
  echo "$leg: Unplug ONLY LG at the laptop. Keep the expansion module and other connections unchanged."
  read -r -t 180 -p 'Press Enter when LG is disconnected (3-minute timeout): '
  sleep 10
  changed=1
  timeout --kill-after=5 20 modprobe -r ucsi_acpi
  timeout --kill-after=5 20 modprobe -r typec_ucsi
  timeout --kill-after=5 20 insmod "$module" "lab_skip_partner_pdos=$flag"
  timeout --kill-after=5 20 modprobe ucsi_acpi
  loaded=$(cat /sys/module/typec_ucsi/parameters/lab_skip_partner_pdos)
  [[ ( $flag == 0 && $loaded == N ) || ( $flag == 1 && $loaded == Y ) ]] || exit 1
  printf 'flag=%s\nloaded=%s\n' "$flag" "$loaded" > "$legdir/mode.txt"
  snapshot "$legdir/before"
  rg -q '^card[0-9]+-eDP-[0-9]+: connected$' "$legdir/before/drm.txt" || {
    echo 'Internal display not reported connected; stopping trial.'; exit 1;
  }
  trace_start=$SECONDS
  bash "$project/scripts/ucsi-probe-window.sh" --capture 180 > "$legdir/capture.txt" 2>&1 &
  capture_pid=$!
  ready_deadline=$((SECONDS + 20))
  until rg -q '^ENABLED:' "$legdir/capture.txt"; do
    kill -0 "$capture_pid" 2>/dev/null || { cat "$legdir/capture.txt"; exit 1; }
    (( SECONDS < ready_deadline )) || { echo 'Capture readiness timeout.'; exit 1; }
    sleep 1
  done
  alert
  echo "$leg READY: reconnect LG to the SAME left-rear module now."
  read -r -t 40 -p 'Press Enter immediately after reconnecting (40-second timeout): '
  (( SECONDS - trace_start <= 60 )) || { echo 'Reconnect too late for a comparable capture.'; exit 1; }
  date --iso-8601=ns > "$legdir/reconnected-at.txt"
  echo 'Recording for the remainder of the 180-second window (at least 120 seconds).'
  sample=0
  while kill -0 "$capture_pid" 2>/dev/null; do
    (( SECONDS - trace_start < 220 )) || { echo 'Capture completion timeout.'; exit 1; }
    snapshot "$legdir/sample-$sample"
    if (( sample % 6 == 0 )); then
      printf '%s recording: %ss elapsed. ' "$leg" "$((SECONDS - trace_start))"
      awk '/connected$/ && !/disconnected$/ {printf "%s ", $0}' "$legdir/sample-$sample/drm.txt"
      printf '\n'
    fi
    sample=$((sample + 1))
    sleep 5
  done
  wait "$capture_pid"
  capture_pid=
  cat "$legdir/capture.txt"
  rg -q '^RESTORED: removed temporary instance and probes\.' "$legdir/capture.txt"
  snapshot "$legdir/after"
  restore_stock
  echo "$leg COMPLETE. Display connector state:"
  cat "$legdir/after/drm.txt"
done
echo 'A/B/A COMPLETE; stock modules restored. Leave LG connected for analysis.'
