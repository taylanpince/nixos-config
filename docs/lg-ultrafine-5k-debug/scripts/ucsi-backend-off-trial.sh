#!/usr/bin/env bash
# Approved bounded UCSI ACPI unbind/rebind test. No module replacement or firmware writes.
set -euo pipefail
mode=${1:---check}
[[ $# -le 1 && ( $mode == --check || $mode == --run ) ]] || exit 2
project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
device=USBC000:00
driver=/sys/bus/platform/drivers/ucsi_acpi
devpath="/sys/bus/platform/devices/$device"
ec_tool=/nix/store/g0zppkc1w8f96rhns7vbm6gdm0xl8mmh-framework-tool-0.6.2/bin/framework_tool
[[ $(uname -r) == 6.18.44 ]] || { echo 'Unexpected kernel.' >&2; exit 1; }
[[ $(cat /sys/class/dmi/id/sys_vendor) == Framework &&
   $(cat /sys/class/dmi/id/product_name) == 'Laptop 13 (AMD Ryzen AI 300 Series)' ]] || exit 1
(( EUID == 0 )) || { echo 'Run with sudo in a local terminal.' >&2; exit 1; }
# Shared with the PDO runner, so the two experiments cannot overlap.
exec 9>/run/lock/lg-ucsi-pdo-trial.lock
flock -n 9 || { echo 'Another UCSI trial is running.' >&2; exit 1; }
[[ -t 0 || $mode == --check ]] || exit 1
[[ $(cat /sys/class/power_supply/BAT1/capacity) -ge 30 ]] || {
  echo 'Battery below 30%; charge before testing.' >&2; exit 1;
}
[[ $(readlink -f "$devpath/driver") == "$driver" && -w $driver/unbind && -w $driver/bind ]] || {
  echo 'Expected bound UCSI ACPI device not found.' >&2; exit 1;
}
[[ -d /sys/module/thunderbolt && -e /sys/bus/thunderbolt/devices/0-0 &&
   -e /sys/bus/thunderbolt/devices/1-0 ]] || { echo 'Expected USB4 hosts missing.' >&2; exit 1; }
[[ ! -e /sys/module/typec_ucsi/parameters/lab_skip_partner_pdos ]] || {
  echo 'Restore stock UCSI before this test.' >&2; exit 1;
}
if rg -q 'ucsi' /sys/kernel/tracing/kprobe_events; then
  echo 'Stop existing UCSI probes first.' >&2; exit 1
fi
for cmd in timeout journalctl flock sudo; do command -v "$cmd" >/dev/null; done
[[ -x $ec_tool ]] || { echo 'Pinned EC diagnostic tool missing.' >&2; exit 1; }
bash "$project/scripts/ucsi-probe-window.sh" --check
echo 'Preflight passed; backend still attached. No driver state changed.'
[[ $mode == --run ]] || exit 0

umask 077
out=$(mktemp -d "$project/evidence/$(date -u +%Y%m%dT%H%M%SZ)-ucsi-backend-off-XXXXXX")
exec > >(tee -a "$out/session.txt") 2>&1
changed=0
capture_pid=
start=$(date --iso-8601=seconds)

write_binding() {
  # Arguments remain data; no interpolated command or unbounded shell write.
  # shellcheck disable=SC2016 # Expansion belongs to the inner shell.
  timeout --kill-after=5 25 bash -c 'printf "%s" "$1" > "$2"' _ "$device" "$driver/$1"
}

restore_backend() {
  local until_ready p ready
  (( changed )) || return 0
  echo 'Restoring stock UCSI ACPI binding...'
  if [[ ! -L $devpath/driver ]]; then write_binding bind || return 1; fi
  [[ $(readlink -f "$devpath/driver") == "$driver" ]] || return 1
  until_ready=$((SECONDS + 30))
  while (( SECONDS < until_ready )); do
    ready=1
    for p in 0 1 2 3; do [[ -e /sys/class/typec/port$p ]] || ready=0; done
    if (( ready )); then
      changed=0
      echo 'RESTORED: stock UCSI backend bound and all four Type-C ports registered.'
      return 0
    fi
    sleep 1
  done
  echo 'Binding returned, but Type-C ports did not all reappear.'
  return 1
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
  if ! restore_backend; then
    echo 'RESTORATION FAILED: reboot the unchanged normal system. Do not force driver removal.'
    rc=1
  fi
  timeout 15 journalctl -k -b --since "$start" -o short-monotonic --no-pager > "$out/kernel.txt" 2>&1
  printf 'exit=%s\n' "$rc" > "$out/result.txt"
  if [[ ${SUDO_UID:-} =~ ^[0-9]+$ && ${SUDO_GID:-} =~ ^[0-9]+$ ]]; then
    chown -R -- "$SUDO_UID:$SUDO_GID" "$out"
  fi
  echo "Evidence: $out"
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
    echo 'No desktop user for audio; watch terminal prompts.'
  fi
}

snapshot() {
  local dest=$1 connector entry attribute
  mkdir -p "$dest"
  date --iso-8601=ns > "$dest/time.txt"
  if [[ -L $devpath/driver ]]; then
    readlink -f "$devpath/driver" > "$dest/backend.txt"
  else
    printf 'unbound\n' > "$dest/backend.txt"
  fi
  for entry in /sys/bus/thunderbolt/devices/*; do
    [[ -e $entry ]] || continue
    printf '%s\n' "${entry##*/}"
  done > "$dest/thunderbolt.txt"
  for connector in /sys/class/drm/card*-*; do
    [[ -r $connector/status ]] || continue
    printf '%s: %s\n' "${connector##*/}" "$(cat "$connector/status")"
    cat "$connector/edid" > "$dest/${connector##*/}.edid" 2>/dev/null || true
    cat "$connector/modes" > "$dest/${connector##*/}.modes" 2>/dev/null || true
  done > "$dest/drm.txt"
  for attribute in /sys/class/power_supply/BAT1/{status,capacity} /sys/class/power_supply/ACAD/online; do
    [[ -r $attribute ]] || continue
    printf '%s: %s\n' "$attribute" "$(cat "$attribute")"
  done > "$dest/power.txt"
}

echo "UCSI backend-off display test. Ctrl-C restores binding. Evidence: $out"
snapshot "$out/before"
rg -q '^card[0-9]+-eDP-[0-9]+: connected$' "$out/before/drm.txt" || exit 1
alert
echo 'Unplug ONLY LG at the laptop. Keep the left-rear module and other connections unchanged.'
read -r -t 180 -p 'Press Enter when LG is disconnected (3-minute timeout): '
sleep 10
changed=1
write_binding unbind
[[ ! -L $devpath/driver ]] || { echo 'Backend still attached; stopping.'; exit 1; }
[[ -d /sys/module/thunderbolt && -e /sys/bus/thunderbolt/devices/0-0 &&
   -e /sys/bus/thunderbolt/devices/1-0 ]] || { echo 'USB4 hosts changed unexpectedly.'; exit 1; }
snapshot "$out/unbound-before-connect"
rg -q '^card[0-9]+-eDP-[0-9]+: connected$' "$out/unbound-before-connect/drm.txt" || exit 1
trace_start=$SECONDS
bash "$project/scripts/ucsi-probe-window.sh" --capture 180 > "$out/capture.txt" 2>&1 &
capture_pid=$!
ready_deadline=$((SECONDS + 20))
until rg -q '^ENABLED:' "$out/capture.txt"; do
  kill -0 "$capture_pid" 2>/dev/null || { cat "$out/capture.txt"; exit 1; }
  (( SECONDS < ready_deadline )) || { echo 'Capture readiness timeout.'; exit 1; }
  sleep 1
done
alert
echo 'READY: UCSI backend detached; Thunderbolt remains running. Reconnect LG to the SAME left-rear module.'
read -r -t 40 -p 'Press Enter immediately after reconnecting (40-second timeout): '
(( SECONDS - trace_start <= 60 )) || { echo 'Reconnect too late for a valid capture.'; exit 1; }
date --iso-8601=ns > "$out/reconnected-at.txt"
echo 'Recording for the remainder of 180 seconds; stock binding will then be restored automatically.'
sample=0
while kill -0 "$capture_pid" 2>/dev/null; do
  [[ ! -L $devpath/driver ]] || { echo 'Backend reattached during observation; stopping.'; exit 1; }
  [[ -d /sys/module/thunderbolt ]] || { echo 'Thunderbolt driver disappeared; stopping.'; exit 1; }
  (( SECONDS - trace_start < 220 )) || { echo 'Capture completion timeout.'; exit 1; }
  snapshot "$out/sample-$sample"
  if (( sample % 6 == 0 )); then
    printf 'Recording: %ss elapsed. ' "$((SECONDS - trace_start))"
    awk '/connected$/ && !/disconnected$/ {printf "%s ", $0}' "$out/sample-$sample/drm.txt"
    printf '\n'
  fi
  sample=$((sample + 1))
  sleep 5
done
wait "$capture_pid"
capture_pid=
cat "$out/capture.txt"
rg -q '^RESTORED: removed temporary instance and probes\.' "$out/capture.txt"
snapshot "$out/unbound-after"
[[ ! -L $devpath/driver ]] || { echo 'Backend reattached before endpoint checks.'; exit 1; }
# Endpoint EC reads only, after the main observation; no PD controls or reset.
for query in pdports pd-info; do
  timeout 20 "$ec_tool" --driver cros-ec "--$query" > "$out/ec-$query.txt" 2>&1 || \
    printf 'EC read %s failed; inspect saved output.\n' "$query"
done
restore_backend
echo 'Observing restored stock binding for 30 seconds; leave LG connected.'
for sample in 0 1 2 3 4 5; do snapshot "$out/restored-$sample"; sleep 5; done
snapshot "$out/after"
echo 'COMPLETE: stock UCSI restored. Leave LG connected for analysis.'
cat "$out/after/drm.txt"
