#!/usr/bin/env bash
set -euo pipefail

powered() {
  bluetoothctl show 2>/dev/null | awk -F': ' '/Powered/ {print $2}'
}

connected_count() {
  bluetoothctl devices Connected 2>/dev/null | wc -l | tr -d ' '
}

status_json() {
  local p c icon tip cls
  p="$(powered || echo no)"
  c="$(connected_count || echo 0)"

  if [[ "$p" != "yes" ]]; then
    icon="󰂲"
    tip="Bluetooth: off (right-click to toggle)"
    cls="off"
  else
    if (( c > 0 )); then
      icon="󰂱"
      tip="Bluetooth: on, connected: $c\nClick: manager\nRight-click: toggle power"
      cls="on"
    else
      icon="󰂯"
      tip="Bluetooth: on, no devices\nClick: manager\nRight-click: toggle power"
      cls="on"
    fi
  fi

  printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$icon" "$tip" "$cls"
}

toggle_power() {
  local p
  p="$(powered || echo no)"
  if [[ "$p" == "yes" ]]; then
    bluetoothctl power off >/dev/null
  else
    bluetoothctl power on >/dev/null
  fi
}

case "${1:-}" in
  --status) status_json ;;
  --toggle-power) toggle_power ;;
  *) echo "usage: $0 --status|--toggle-power" >&2; exit 2 ;;
esac

