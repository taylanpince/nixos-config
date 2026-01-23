#!/usr/bin/env bash
set -euo pipefail

EXT="DP-4"
INT="eDP-1"

MAIN_FROM=1
MAIN_TO=8
AUX_FROM=9
AUX_TO=16

sock="${XDG_RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"

have_ext() {
  hyprctl monitors 2>/dev/null | grep -q "Monitor ${EXT} "
}

move_range_to() {
  local from="$1" to="$2" mon="$3"
  local ws
  for ws in $(seq "$from" "$to"); do
    hyprctl dispatch moveworkspacetomonitor "$ws" "$mon" >/dev/null 2>&1 || true
  done
}

reconcile() {
  if have_ext; then
    # External is primary: main on external, aux on laptop
    move_range_to "$MAIN_FROM" "$MAIN_TO" "$EXT"
    move_range_to "$AUX_FROM"  "$AUX_TO"  "$INT"

    # IMPORTANT: force each monitor to be on a workspace in its range
    hyprctl --batch \
      "dispatch focusmonitor ${INT}; dispatch workspace ${AUX_FROM}; \
       dispatch focusmonitor ${EXT}; dispatch workspace ${MAIN_FROM}" \
      >/dev/null 2>&1 || true
  else
    # Undocked: everything lives on the laptop
    move_range_to "$MAIN_FROM" "$AUX_TO" "$INT"
    hyprctl --batch \
      "dispatch focusmonitor ${INT}; dispatch workspace ${MAIN_FROM}" \
      >/dev/null 2>&1 || true
  fi
}

update_waybar() {
  ~/config/scripts/switch-waybar-config.sh || true
}

handle() {
  case "$1" in
    monitoradded*"$EXT"*)   reconcile ;;
    monitorremoved*"$EXT"*) reconcile ;;
  esac
  update_waybar
}

reconcile
update_waybar

socat -U - UNIX-CONNECT:"$sock" | while read -r line; do
  handle "$line"
done

