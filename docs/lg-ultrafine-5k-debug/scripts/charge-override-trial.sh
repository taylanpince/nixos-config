#!/usr/bin/env bash
# Charge-port override trial: does the LG's PD session survive on a rear USB4 port
# when the EC never selects that port as the charge input?
#
# Temporary changes, all reverted on exit (normal, Ctrl-C, TERM, HUP):
#   * EC charge-port override set to "dontcharge" (host command 0x0114, verified
#     supported on lilac-4.0.2), restored to "off" by the cleanup trap.
#   * UCSI/Thunderbolt trace probes and an EC console stream, created and removed
#     by scripts/ucsi-probe-window.sh.
# No firmware, kernel module, PD role/mode command or persistent setting is touched.
# While the override is active the laptop runs from its battery.
#
# Usage:
#   sudo bash scripts/charge-override-trial.sh --check          # preflight only
#   sudo bash scripts/charge-override-trial.sh --run [seconds]  # default 240 (60-300)
set -euo pipefail
mode=${1:---check}
duration=${2:-240}
[[ $mode == --check || $mode == --run ]] || { echo 'Usage: charge-override-trial.sh [--check | --run [seconds]]' >&2; exit 2; }
if [[ ! $duration =~ ^[0-9]{2,3}$ ]] || (( 10#$duration < 60 || 10#$duration > 300 )); then
  echo 'Duration must be 60-300 seconds.' >&2; exit 2
fi
duration=$((10#$duration))

project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ectool=/nix/store/3bqchzi9v7jr8ragwrvd6a3wnaicxbdj-fw-ectool-0-unstable-2024-04-23/bin/ectool
fwtool=/nix/store/g0zppkc1w8f96rhns7vbm6gdm0xl8mmh-framework-tool-0.6.2/bin/framework_tool
probe=$project/scripts/ucsi-probe-window.sh
collect=$project/scripts/collect.sh

(( EUID == 0 )) || { echo 'Run with sudo in a local terminal.' >&2; exit 1; }
for f in "$ectool" "$fwtool" "$probe" "$collect"; do
  [[ -x $f || -r $f ]] || { echo "Missing: $f" >&2; exit 1; }
done
[[ -c /dev/cros_ec ]] || { echo '/dev/cros_ec missing.' >&2; exit 1; }
bash "$probe" --check >/dev/null || { echo 'ucsi-probe-window.sh preflight failed; nothing changed.' >&2; exit 1; }
"$ectool" --interface=dev cmdversions 0x0114 >/dev/null 2>&1 || {
  echo 'EC does not report PD_CHARGE_PORT_OVERRIDE support; nothing changed.' >&2; exit 1; }
cap=$(cat /sys/class/power_supply/BAT1/capacity)
(( cap >= 40 )) || { echo "Battery at ${cap}%; need at least 40% because the override stops charging." >&2; exit 1; }
if [[ $mode == --check ]]; then
  echo "Preflight passed (battery ${cap}%). No change made."
  exit 0
fi

umask 077
exec 9>"$project/evidence/.charge-override-trial.lock"
flock -n 9 || { echo 'Another trial holds the lock.' >&2; exit 1; }
out=$(mktemp -d "$project/evidence/$(date -u +%Y%m%dT%H%M%SZ)-charge-override-trial-XXXXXX")
date --iso-8601=seconds > "$out/started-at.txt"
override_set=0
capture_pid=
tty=/dev/tty

ec() { timeout 20 "$ectool" --interface=dev "$@"; }
fw() { timeout 20 "$fwtool" --driver cros-ec "$@"; }
state() {
  local tag=$1
  {
    printf '=== %s @ %s uptime=%s\n' "$tag" "$(date --iso-8601=ns)" "$(cut -d' ' -f1 /proc/uptime)"
    printf -- '--- chargestate\n'; ec chargestate show 2>&1 || true
    printf -- '--- pdports\n'; fw --pdports 2>&1 || true
    printf -- '--- battery: %s %s%%  ACAD=%s\n' "$(cat /sys/class/power_supply/BAT1/status)" \
      "$(cat /sys/class/power_supply/BAT1/capacity)" "$(cat /sys/class/power_supply/ACAD/online)"
    for i in 1 2 3 4; do
      s=/sys/class/power_supply/ucsi-source-psy-USBC000:00$i
      printf -- '--- psy%s online=%s %smV %smA\n' "$i" "$(cat "$s/online")" "$(cat "$s/voltage_now")" "$(cat "$s/current_now")"
    done
    for p in 0 1 2 3; do
      d=/sys/class/typec/port$p
      printf -- '--- port%s partner=%s pd=%s cable=%s\n' "$p" \
        "$([[ -d $d-partner ]] && cat "$d-partner/accessory_mode" || echo none)" \
        "$([[ -d $d-partner ]] && cat "$d-partner/supports_usb_power_delivery" || echo -)" \
        "$([[ -d $d-cable ]] && cat "$d-cable/type" || echo -)"
    done
    printf -- '--- thunderbolt: %s\n' "$(find /sys/bus/thunderbolt/devices/ -mindepth 1 -maxdepth 1 -printf '%f ')"
    printf -- '--- drm: %s\n' "$(for s in /sys/class/drm/card*-*/status; do printf '%s=%s ' "$(basename "$(dirname "$s")")" "$(cat "$s")"; done)"
  } >> "$out/state.txt" 2>&1
}

cleanup() {
  local rc=$?
  trap - EXIT INT TERM HUP
  set +e
  if [[ -n $capture_pid ]] && kill -0 "$capture_pid" 2>/dev/null; then
    kill -TERM "$capture_pid"; wait "$capture_pid"
  fi
  if (( override_set )); then
    if ec chargeoverride off >> "$out/override-restore.txt" 2>&1; then
      printf 'OVERRIDE RESTORED: chargeoverride off\n' | tee -a "$out/override-restore.txt"
    else
      printf 'OVERRIDE RESTORE FAILED. Run manually: sudo %s --interface=dev chargeoverride off\n' "$ectool" | tee -a "$out/override-restore.txt" >&2
      rc=1
    fi
    sleep 3
    state after-restore
  fi
  date --iso-8601=seconds > "$out/finished-at.txt"
  if [[ ${SUDO_UID:-} =~ ^[0-9]+$ && ${SUDO_GID:-} =~ ^[0-9]+$ ]]; then
    chown -R -- "$SUDO_UID:$SUDO_GID" "$out"
  fi
  printf 'Evidence: %s\n' "$out"
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

echo "Trial directory: $out"
state before-override

# 1. Apply the override while the LG is still on the front-right port, and show that it bites.
ec chargeoverride dontcharge > "$out/override-set.txt" 2>&1
override_set=1
echo 'Override set: dontcharge. Sampling for 6 seconds to confirm the EC stopped sinking...'
sleep 6
state after-override
printf 'Now: battery=%s ACAD=%s chg_input=%s\n' "$(cat /sys/class/power_supply/BAT1/status)" \
  "$(cat /sys/class/power_supply/ACAD/online)" "$(ec chargestate show 2>/dev/null | awk -F'= ' '/chg_input_current/ {print $2}')"

# 2. Operator moves the cable under capture.
read -r -p 'STEP 1: Unplug the LG cable from the laptop. Press Enter once it is out. ' < "$tty"
date --iso-8601=ns > "$out/unplugged-at.txt"
sleep 5
state after-unplug

bash "$probe" --capture-with-ec "$duration" > "$out/capture-stdout.txt" 2>&1 &
capture_pid=$!
for _ in $(seq 1 60); do
  grep -q '^ENABLED' "$out/capture-stdout.txt" 2>/dev/null && break
  kill -0 "$capture_pid" 2>/dev/null || { echo 'Capture exited before ENABLED; see capture-stdout.txt.' >&2; exit 1; }
  sleep 1
done
grep -q '^ENABLED' "$out/capture-stdout.txt" || { echo 'Capture did not report ENABLED within 60 s.' >&2; exit 1; }

read -r -p 'STEP 2: Plug the LG into a REAR USB4 port now, then press Enter immediately. ' < "$tty"
date --iso-8601=ns > "$out/plugged-at.txt"
echo "Observing for the rest of the ${duration}-second window; snapshots every 5 s. Leave everything alone."
while kill -0 "$capture_pid" 2>/dev/null; do
  {
    printf '%s up=%s bat=%s acad=%s psy4=%s/%s/%s port3=%s tb=[%s] dp_connected=[%s]\n' \
      "$(date +%T.%N)" "$(cut -d' ' -f1 /proc/uptime)" \
      "$(cat /sys/class/power_supply/BAT1/status)" "$(cat /sys/class/power_supply/ACAD/online)" \
      "$(cat /sys/class/power_supply/ucsi-source-psy-USBC000:004/online)" \
      "$(cat /sys/class/power_supply/ucsi-source-psy-USBC000:004/voltage_now)" \
      "$(cat /sys/class/power_supply/ucsi-source-psy-USBC000:004/current_now)" \
      "$([[ -d /sys/class/typec/port3-partner ]] && cat /sys/class/typec/port3-partner/accessory_mode || echo none)" \
      "$(find /sys/bus/thunderbolt/devices/ -mindepth 1 -maxdepth 1 -printf '%f\n' | grep -vE '^(0-0|1-0|domain[01])$' | tr '\n' ' ')" \
      "$(grep -l '^connected' /sys/class/drm/card*-DP-*/status 2>/dev/null | xargs -rn1 dirname | xargs -rn1 basename | tr '\n' ' ')"
  } >> "$out/snapshots.txt"
  sleep 5
done
wait "$capture_pid" || true
capture_pid=
state after-capture
bash "$collect" rear-left-dontcharge-after > "$out/collect.txt" 2>&1 || true

echo
echo '================ SUMMARY ================'
echo "External Thunderbolt routers seen: $(grep -c 'tb=\[[^]]' "$out/snapshots.txt" || true) of $(wc -l < "$out/snapshots.txt") snapshots"
echo "Connected external DP seen:        $(grep -c 'dp_connected=\[[^]]' "$out/snapshots.txt" || true) of $(wc -l < "$out/snapshots.txt") snapshots"
echo "port3 partner states seen:         $(awk '{for(i=1;i<=NF;i++) if($i ~ /^port3=/) print substr($i,7)}' "$out/snapshots.txt" | sort | uniq -c | tr '\n' ';')"
echo "psy4 (rear-left) online samples:   $(grep -c 'psy4=1/' "$out/snapshots.txt" || true)"
echo 'Final EC view of port 3:'
fw --pdports 2>/dev/null | awk '/USB-C Port 3/,/Active Port/'
echo 'The cleanup trap restores chargeoverride off next.'
