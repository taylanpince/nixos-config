#!/usr/bin/env bash
# This experiment's specific Kingston USB only. Defaults to read-only checks.
set -euo pipefail
project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
image="$project/evidence/fedora-media/Fedora-Workstation-Live-44-1.7.x86_64.iso"
target=/dev/disk/by-id/usb-Kingston_DataTraveler_3.0_E0D55E6CBD05196139C100F4-0:0
expected_hash=1620295f6a00c27c3208f0c00b8ece4eab1ec69b9002152d97488bf26a426ddf
expected_size=2851612672
mode=${1:---check}
fail() { printf 'STOP: %s\n' "$*" >&2; exit 1; }
[[ $# -le 1 && ( $mode == --check || $mode == --write ) ]] || fail 'Use --check or --write.'
[[ -f $image ]] || fail 'Verified image is not ready.'
[[ $(stat -c %s "$image") == "$expected_size" ]] || fail 'Image size mismatch.'
printf '%s  %s\n' "$expected_hash" "$image" | sha256sum -c -
check_target() {
  [[ -b $target ]] || fail 'The identified Kingston USB is not connected.'
  device=$(readlink -f -- "$target")
  [[ $(lsblk -dnro TYPE "$device") == disk ]] || fail 'Target is not a whole disk.'
  [[ $(lsblk -dnro TRAN "$device") == usb ]] || fail 'Target is not USB.'
  [[ $(lsblk -dnro RM "$device") == 1 ]] || fail 'Target is not removable.'
  [[ $(lsblk -dnro SERIAL "$device") == E0D55E6CBD05196139C100F4 ]] || fail 'USB serial mismatch.'
  [[ $(lsblk -bdnro SIZE "$device") == 61991813120 ]] || fail 'USB capacity mismatch.'
  # Refuse mounted partitions, device-mapper holders and active swap.
  local mounts nodes swap_node node_path
  mounts=$(lsblk -nr -o MOUNTPOINTS "$device")
  [[ ! $mounts =~ [^[:space:]] ]] || fail 'USB has mounted filesystems or active swap; unmount them first.'
  while read -r node_path; do
    [[ -z $node_path ]] && continue
    for holder in "/sys/class/block/${node_path##*/}/holders/"*; do
      [[ ! -e $holder ]] || fail "USB node has an active holder: $holder"
    done
  done < <(lsblk -nrpo NAME "$device")
  nodes=$(lsblk -nrpo NAME "$device")
  while read -r swap_node; do
    [[ -z $swap_node ]] && continue
    while read -r node_path; do
      [[ $swap_node != "$node_path" ]] || fail 'USB contains active swap.'
    done <<< "$nodes"
  done < <(swapon --noheadings --raw --show=NAME)
}
check_target
lsblk -o NAME,SIZE,MODEL,FSTYPE,LABEL,MOUNTPOINTS "$device"
printf '\nTarget: %s\nImage: %s\n' "$target" "$image"
if [[ $mode == --check ]]; then
  printf 'Read-only preflight passed. No device data changed.\n'
  exit 0
fi
(( EUID == 0 )) || fail 'Run --write with sudo in your local terminal.'
[[ -t 0 ]] || fail 'Writing requires an interactive terminal.'
printf '\nThis replaces the Kingston USB contents, including its Ubuntu image and writable partition.\n'
printf 'Type ERASE KINGSTON to write Fedora to this USB: '
read -r confirmation
[[ $confirmation == 'ERASE KINGSTON' ]] || fail 'Cancelled; no device data changed.'
check_target
dd if="$image" of="$target" bs=4M conv=fsync status=progress
printf '\nVerifying the written image against the USB...\n'
cmp -n "$expected_size" -- "$image" "$target"
printf 'VERIFIED: Fedora image written and read back successfully.\n'
printf 'Keep the USB connected. Boot it with F12 when the evidence-transfer plan is ready.\n'
