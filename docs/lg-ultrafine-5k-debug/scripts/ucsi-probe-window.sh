#!/usr/bin/env bash
# Temporary instrumentation only. See docs/LOCAL-ENGINEERING.md before capture.
# No PD commands, driver reloads, module parameters or firmware writes.
set -euo pipefail
mode=${1:---check}
duration=${2:-120}
[[ $mode == --check || $mode == --capture || $mode == --capture-with-ec ]] || {
  echo 'Usage: ucsi-probe-window.sh [--check | --capture [seconds] | --capture-with-ec [seconds]]' >&2; exit 2;
}
if [[ ! $duration =~ ^[0-9]{1,3}$ ]] || (( 10#$duration < 10 || 10#$duration > 300 )); then
  echo 'Duration must be 10–300 seconds.' >&2; exit 2;
fi
duration=$((10#$duration))
ec_tool=/nix/store/g0zppkc1w8f96rhns7vbm6gdm0xl8mmh-framework-tool-0.6.2/bin/framework_tool
if [[ $mode == --capture-with-ec && ! -x $ec_tool ]]; then
  echo 'Pinned Framework tool is missing; nothing changed.' >&2; exit 1
fi
(( EUID == 0 )) || { echo 'Run with sudo in a local terminal.' >&2; exit 1; }
[[ $(uname -r) == 6.18.44 && $(uname -m) == x86_64 ]] || {
  echo 'Probe signatures were reviewed for x86_64 Linux 6.18.44 only.' >&2; exit 1;
}
tracefs=/sys/kernel/tracing
[[ -d $tracefs/instances && -w $tracefs/kprobe_events ]] || {
  echo 'Mounted tracefs with kprobe support is required; nothing changed.' >&2; exit 1;
}
for symbol in ucsi_acpi_async_control ucsi_send_command_common; do
  awk -v symbol="$symbol" '$3 == symbol {found=1} END {exit !found}' /proc/kallsyms || {
    echo "Missing kernel symbol: $symbol; nothing changed." >&2; exit 1;
  }
done
[[ -e $tracefs/events/ucsi/ucsi_connector_change/enable ]] || {
  echo 'UCSI connector tracepoint unavailable; nothing changed.' >&2; exit 1;
}
if [[ $mode == --check ]]; then
  echo 'Preflight passed; no tracing changed. Probe registration still needs runtime validation.'
  exit 0
fi

umask 077
project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
out=$(mktemp -d "$project/evidence/$(date -u +%Y%m%dT%H%M%SZ)-ucsi-probes-XXXXXX")
group="lg_ucsi_${$}"
instance="$tracefs/instances/$group"
[[ ! -e $instance && ! -e $tracefs/events/$group ]] || {
  echo 'Trace name collision; nothing changed.' >&2; exit 1;
}
created=0
probes=()
ec_pid=
start=$(date --iso-8601=seconds)
cleanup() {
  local rc=$? failed=0 event stat ec_rc
  trap - EXIT INT TERM HUP
  set +e
  if (( created )); then
    printf '0\n' > "$instance/tracing_on" || failed=1
    cat "$instance/trace" > "$out/trace.txt" || failed=1
    if [[ -w $instance/options/fields ]]; then
      printf '1\n' > "$instance/options/fields"
      cat "$instance/trace" > "$out/trace-fields.txt"
    fi
    for stat in "$instance"/per_cpu/cpu*/stats; do
      printf '\n%s\n' "$stat"
      cat "$stat"
    done > "$out/buffer-stats.txt"
    printf '0\n' > "$instance/events/enable" || failed=1
    rmdir "$instance" || failed=1
  fi
  if ((${#probes[@]})); then
    awk -v group="$group" 'index($1, group) {print}' "$tracefs/kprobe_profile" > "$out/probe-stats.txt"
  fi
  for event in "${probes[@]}"; do
    printf -- '-:%s/%s\n' "$group" "$event" >> "$tracefs/kprobe_events" || failed=1
  done
  if [[ -n $ec_pid ]]; then
    kill -TERM "$ec_pid" 2>/dev/null
    wait "$ec_pid"
    ec_rc=$?
    printf '%s\n' "$ec_rc" > "$out/ec-follow-exit-status.txt"
    # timeout returns 143 when terminated by cleanup, or 124 at its deadline.
    if (( ec_rc != 143 && ec_rc != 124 )); then
      printf 'EC stream ended unexpectedly (status %d); inspect ec-console-live.txt.\n' "$ec_rc" >&2
      rc=1
    fi
  fi
  timeout 15 journalctl -k -b --since "$start" -o short-monotonic --no-pager > "$out/kernel.txt" 2>&1
  date --iso-8601=seconds > "$out/finished-at.txt"
  if (( failed )); then
    printf 'CLEANUP INCOMPLETE: instance=%s group=%s; see documentation.\n' "$instance" "$group" | tee "$out/cleanup.txt" >&2
    rc=1
  else
    printf 'RESTORED: removed temporary instance and probes.\n' | tee "$out/cleanup.txt"
  fi
  if [[ ${SUDO_UID:-} =~ ^[0-9]+$ && ${SUDO_GID:-} =~ ^[0-9]+$ ]]; then
    chown -R -- "$SUDO_UID:$SUDO_GID" "$out"
  fi
  printf 'Evidence: %s\n' "$out"
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP
printf '%s\n' "$start" > "$out/started-at.txt"
uname -a > "$out/uname.txt"
printf '%s\n' "$group" > "$out/probe-group.txt"
cat > "$out/probes.txt" <<EOF
p:$group/${group}_request typec_ucsi:ucsi_send_command_common command=\$arg2:x64
p:$group/${group}_write ucsi_acpi:ucsi_acpi_async_control command=\$arg2:x64
r128:$group/${group}_result typec_ucsi:ucsi_send_command_common ret=\$retval:s32
EOF
mkdir "$instance"
created=1
printf '0\n' > "$instance/tracing_on"
printf 'nop\n' > "$instance/current_tracer"
printf 'mono\n' > "$instance/trace_clock"
printf '1024\n' > "$instance/buffer_size_kb"
while IFS= read -r definition; do
  event=${definition%% *}
  event=${event##*/}
  printf '%s\n' "$definition" >> "$tracefs/kprobe_events"
  probes+=("$event")
done < "$out/probes.txt"
for event in "$instance/events/$group"/* "$instance/events/ucsi"/*; do
  [[ -f $event/enable ]] || continue
  cat "$event/format" > "$out/format-$(basename "$event").txt"
  printf '1\n' > "$event/enable"
done
if [[ -f $instance/events/thunderbolt/enable ]]; then
  printf '1\n' > "$instance/events/thunderbolt/enable"
fi
if [[ $mode == --capture-with-ec ]]; then
  {
    date --iso-8601=ns
    cat /proc/uptime
    timeout 20 "$ec_tool" --driver cros-ec --uptimeinfo
    cat /proc/uptime
    date --iso-8601=ns
  } > "$out/ec-clock-anchor.txt" 2>&1
  timeout --kill-after=3 "$((duration + 15))" "$ec_tool" --driver cros-ec --console follow > "$out/ec-console-live.txt" 2>&1 &
  ec_pid=$!
  sleep 1
  kill -0 "$ec_pid" 2>/dev/null || {
    echo 'EC stream exited before capture; saving output and cleaning up.' >&2; exit 1;
  }
fi
printf '1\n' > "$instance/tracing_on"
printf 'LG UCSI observation begins\n' > "$instance/trace_marker"
printf 'ENABLED: %s seconds. Unplug LG, wait 10 seconds, reconnect SAME port/module/cable.\n' "$duration"
printf 'Keep this terminal open; Ctrl-C also saves and removes the probes.\n'
deadline=$((SECONDS + duration))
while (( SECONDS < deadline )); do
  if [[ $mode == --capture-with-ec ]]; then
    {
      date --iso-8601=ns
      cat /proc/uptime
      for attribute in /sys/class/power_supply/BAT1/{status,capacity} \
        /sys/class/power_supply/ACAD/online \
        /sys/class/power_supply/ucsi-source-psy-USBC000:004/{online,usb_type,voltage_now,current_max}; do
        if [[ -r $attribute ]]; then
          printf '%s: ' "$attribute"
          cat "$attribute" || true
        fi
      done
    } >> "$out/power-live.txt"
  fi
  sleep 1
done
