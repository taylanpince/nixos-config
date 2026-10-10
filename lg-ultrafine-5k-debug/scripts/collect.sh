#!/usr/bin/env bash
# Read-only host snapshot. Run as the desktop user; never invokes sudo.
set -u
umask 077
project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
label=${1:?Usage: collect.sh RUN_LABEL}
[[ $label =~ ^[a-zA-Z0-9_-]+$ ]] || { echo 'Use letters, numbers, underscores or hyphens.' >&2; exit 2; }
out=$(mktemp -d "$project/evidence/$(date +%Y%m%dT%H%M%S)-${label}-XXXXXX")
capture() {
  local name=$1
  shift
  if command -v "$1" >/dev/null 2>&1; then
    timeout 25 "$@" > "$out/$name" 2>&1
    printf '%s\t%s\n' "$name" "$?" >> "$out/exit-status.tsv"
  else
    printf 'UNAVAILABLE: %s\n' "$1" > "$out/$name"
    printf '%s\t127\n' "$name" >> "$out/exit-status.tsv"
  fi
}
date --iso-8601=seconds > "$out/captured-at.txt"
capture uname.txt uname -a
capture os-release.txt cat /etc/os-release
capture bios.txt cat /sys/class/dmi/id/bios_version /sys/class/dmi/id/bios_date
capture kernel.txt journalctl -k -b --no-pager -o short-monotonic
capture hyprland-version.txt hyprctl version
capture hyprland-monitors.json hyprctl -j monitors all
capture bolt.txt boltctl list -a
capture usb-tree.txt lsusb -t
capture pci.txt lspci -nnk
capture drm-info.txt drm_info
capture system.txt readlink -f /run/current-system
capture thunderbolt-list.txt ls -l /sys/bus/thunderbolt/devices/
{
  for d in /sys/bus/thunderbolt/devices/*; do
    [[ -e $d ]] || continue
    printf '\n%s\n' "$d"
    for a in device_name vendor_name authorized security generation rx_speed tx_speed rx_lanes tx_lanes nvm_version iommu_dma_protection power/control power/runtime_status; do
      [[ -r $d/$a ]] || continue
      printf '%s: ' "$a"
      cat "$d/$a"
    done
  done
} > "$out/thunderbolt-attributes.txt" 2>&1
{
  for d in /sys/class/typec/*; do
    [[ -e $d ]] || continue
    printf '\n%s\n' "$d"
    for a in data_role power_role port_type power_operation_mode preferred_role usb_power_delivery_revision usb_typec_revision accessory_mode supports_usb_power_delivery number_of_alternate_modes type plug_type; do
      [[ -r $d/$a ]] || continue
      printf '%s: ' "$a"
      cat "$d/$a"
    done
  done
} > "$out/typec.txt" 2>&1
{
  for p in /sys/class/typec/port*-partner/identity/* /sys/class/typec/port*-cable/identity/* /sys/class/typec/port*-partner.*/svid /sys/class/typec/port*-partner.*/active /sys/class/typec/port*-partner.*/vdo; do
    [[ -r $p && -f $p ]] || continue
    printf '%s: ' "$p"
    cat "$p"
  done
} > "$out/typec-identity.txt" 2>&1
{
  for d in /sys/class/power_supply/*; do
    [[ -e $d ]] || continue
    printf '\n%s\n' "$d"
    for a in type online status capacity voltage_now current_now; do
      [[ -r $d/$a ]] || continue
      printf '%s: ' "$a"
      cat "$d/$a"
    done
  done
} > "$out/power.txt" 2>&1
{
  for d in /sys/bus/usb/devices/*; do
    [[ -r $d/idVendor ]] || continue
    printf '\n%s\n' "$d"
    for a in idVendor idProduct manufacturer product speed; do
      [[ -r $d/$a ]] || continue
      printf '%s: ' "$a"
      cat "$d/$a"
    done
  done
} > "$out/usb-devices.txt" 2>&1
mkdir "$out/edid"
for d in /sys/class/drm/card*-*; do
  [[ -r $d/status ]] || continue
  name=${d##*/}
  printf '%s: %s\n' "$name" "$(cat "$d/status")" >> "$out/drm-status.txt"
  for a in status enabled modes; do
    [[ -r $d/$a ]] && cat "$d/$a" > "$out/edid/$name.$a"
  done
  [[ -r $d/edid ]] && cat "$d/edid" > "$out/edid/$name.bin"
  if [[ -s $out/edid/$name.bin ]] && command -v edid-decode >/dev/null 2>&1; then
    timeout 10 edid-decode "$out/edid/$name.bin" > "$out/edid/$name.decoded.txt" 2>&1
  fi
done
printf '%s\n' "$out"
