#!/usr/bin/env bash
# Read-only EC/PD probe using fw-ectool (Chromium EC host commands) and framework_tool.
# Purpose: learn which PD host commands the Lilac EC answers, and read the EC's own
# view of a live connection: CC state, roles, discovered SVIDs/VDOs, mux state, PD log.
#
# Every command here is a status read. No swaps, resets, mode entry, charge override,
# GPIO writes or firmware operations are issued. `pdlog` drains the EC's PD event log
# buffer (read-and-clear); that is its only side effect.
#
# Usage (needs root for /dev/cros_ec):
#   sudo bash scripts/ec-pd-probe.sh [PORT]      # PORT defaults to 1 (front-right)
# Output: evidence/<timestamp>-ec-pd-probe-<port>-XXXXXX/
set -u
umask 077
project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
port=${1:-1}
[[ $port =~ ^[0-3]$ ]] || { echo 'PORT must be 0-3' >&2; exit 2; }
ectool=/nix/store/3bqchzi9v7jr8ragwrvd6a3wnaicxbdj-fw-ectool-0-unstable-2024-04-23/bin/ectool
fwtool=/nix/store/g0zppkc1w8f96rhns7vbm6gdm0xl8mmh-framework-tool-0.6.2/bin/framework_tool
[[ -x $ectool ]] || { echo "fw-ectool missing at $ectool (nix build .#nixosConfigurations.bloomware.pkgs.fw-ectool)" >&2; exit 1; }
[[ -x $fwtool ]] || { echo "framework_tool missing at $fwtool" >&2; exit 1; }
[[ $EUID -eq 0 ]] || { echo 'Run with sudo: /dev/cros_ec is root-only.' >&2; exit 1; }
[[ -c /dev/cros_ec ]] || { echo '/dev/cros_ec not present.' >&2; exit 1; }

out=$(mktemp -d "$project/evidence/$(date +%Y%m%dT%H%M%S)-ec-pd-probe-port${port}-XXXXXX")
date --iso-8601=seconds > "$out/captured-at.txt"
cut -d' ' -f1 /proc/uptime > "$out/uptime-at-start.txt"

# fw-ectool talks to the kernel cros_ec chardev; fall back to autodetect if that flag is rejected.
ec() {
  local name=$1; shift
  {
    printf '$ ectool %s\n' "$*"
    if ! timeout 20 "$ectool" --interface=dev "$@" 2>&1; then
      printf '[--interface=dev failed, retrying autodetect]\n'
      timeout 20 "$ectool" "$@" 2>&1
    fi
    printf '[exit %s]\n' "$?"
  } > "$out/$name" 2>&1
  printf '%s\t%s\n' "$name" "$(tail -1 "$out/$name")" >> "$out/index.tsv"
}

# 1. Which PD-related host commands does this EC implement? (cmdversions is a pure query)
# 0x0101 USB_PD_CONTROL  0x0102 USB_PD_PORTS  0x0103 USB_PD_POWER_INFO
# 0x0112 USB_PD_DEV_INFO 0x0113 USB_PD_DISCOVERY 0x0114 PD_CHARGE_PORT_OVERRIDE
# 0x0115 PD_GET_LOG_ENTRY 0x0116 USB_PD_GET_AMODE 0x0117 USB_PD_SET_AMODE
# 0x0119 PD_CONTROL 0x011A USB_PD_MUX_INFO 0x011B PD_CHIP_INFO
# 0x0131 TYPEC_DISCOVERY 0x0132 TYPEC_CONTROL 0x0133 TYPEC_STATUS
# 0x0099 CHARGE_PORT_COUNT? (skip) 0x00A0 CHARGE_STATE 0x0096 CHARGE_CONTROL
for cmd in 0x0101 0x0102 0x0103 0x0112 0x0113 0x0114 0x0115 0x0116 0x0117 0x0119 0x011A 0x011B 0x0131 0x0132 0x0133 0x0096 0x00A0; do
  ec "cmdversions-$cmd.txt" cmdversions "$cmd"
done

# 2. EC identity and feature bits.
ec version.txt version
ec boardversion.txt boardversion
ec uptimeinfo.txt uptimeinfo

# 3. PD port status reads (no arguments = read-only).
for p in 0 1 2 3; do
  ec "usbpd-port$p.txt" usbpd "$p"
done
ec usbpdpower.txt usbpdpower
ec usbpdmuxinfo.txt usbpdmuxinfo
ec chargestate.txt chargestate show
ec "pdchipinfo-port$port.txt" pdchipinfo "$port"
ec "infopddev-port$port.txt" infopddev "$port"
ec "pdgetmode-port$port.txt" pdgetmode "$port"

# 4. Type-C discovery / status (newer host commands; may be unsupported on this EC).
ec "typecstatus-port$port.txt" typecstatus "$port"
ec "typecdiscovery-port$port-sop.txt" typecdiscovery "$port" 0
ec "typecdiscovery-port$port-sop-prime.txt" typecdiscovery "$port" 1

# 5. EC PD event log (read-and-clear) and recent console.
ec pdlog.txt pdlog
ec console.txt console

# 6. Framework tool's own views for cross-checking.
{
  printf '$ framework_tool --driver cros-ec --pdports\n'
  timeout 20 "$fwtool" --driver cros-ec --pdports 2>&1
  printf '[exit %s]\n' "$?"
} > "$out/framework-pdports.txt"
{
  printf '$ framework_tool --driver cros-ec --console recent\n'
  timeout 20 "$fwtool" --driver cros-ec --console recent 2>&1
  printf '[exit %s]\n' "$?"
} > "$out/framework-console-recent.txt"

# 7. Kernel-side state at the same moment, for correlation.
for d in /sys/class/typec/port${port} /sys/class/typec/port${port}-partner /sys/class/typec/port${port}-cable; do
  [[ -d $d ]] || continue
  printf '\n%s\n' "$d"
  for f in data_role power_role power_operation_mode accessory_mode supports_usb_power_delivery number_of_alternate_modes type plug_type; do
    [[ -r $d/$f ]] && printf '%s: %s\n' "$f" "$(cat "$d/$f")"
  done
done > "$out/typec-sysfs.txt"
grep -H . /sys/class/power_supply/ucsi-source-psy-USBC000:00*/{online,voltage_now,current_now} > "$out/ucsi-psy.txt" 2>&1
cat /sys/class/power_supply/BAT1/status /sys/class/power_supply/BAT1/capacity > "$out/battery.txt" 2>&1

cut -d' ' -f1 /proc/uptime > "$out/uptime-at-end.txt"
chown -R "${SUDO_UID:-0}:${SUDO_GID:-0}" "$out"
printf 'DONE: %s\n' "$out"
printf 'Supported-looking commands (exit 0):\n'
awk -F'\t' '$2 ~ /exit 0/ {print "  " $1}' "$out/index.tsv"
