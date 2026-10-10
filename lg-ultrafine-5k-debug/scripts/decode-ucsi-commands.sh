#!/usr/bin/env bash
# Add command arguments to probe trace text. No hardware access.
set -euo pipefail
[[ $# == 1 && -r $1 ]] || { echo 'Usage: decode-ucsi-commands.sh trace.txt' >&2; exit 2; }
while IFS= read -r line || [[ -n $line ]]; do
  printf '%s' "$line"
  if [[ $line =~ command=(0x[[:xdigit:]]+) ]]; then
    command=${BASH_REMATCH[1]}
    opcode=$((command & 255))
    connector=$(((command >> 16) & 127))
    case $opcode in
      1) name=PPM_RESET; connector=0 ;;
      2) name=CANCEL; connector=0 ;;
      3) name=CONNECTOR_RESET ;;
      4) name=ACK_CC_CI; connector=0 ;;
      5) name=SET_NOTIFICATION_ENABLE; connector=0 ;;
      6) name=GET_CAPABILITY; connector=0 ;;
      7) name=GET_CONNECTOR_CAPABILITY ;;
      8) name=SET_CCOM ;;
      9) name=SET_UOR ;;
      10) name=SET_PDM ;;
      11) name=SET_PDR ;;
      12) name=GET_ALTERNATE_MODES; connector=$(((command >> 24) & 127)) ;;
      13) name=GET_CAM_SUPPORTED ;;
      14) name=GET_CURRENT_CAM ;;
      15) name=SET_NEW_CAM ;;
      16) name=GET_PDOS ;;
      17) name=GET_CABLE_PROPERTY ;;
      18) name=GET_CONNECTOR_STATUS ;;
      19) name=GET_ERROR_STATUS ;;
      21) name=GET_PD_MESSAGE ;;
      *) printf -v name 'COMMAND_0x%02x' "$opcode" ;;
    esac
    printf ' | %s connector=%d' "$name" "$connector"
    if (( connector > 0 )); then printf ' (sysfs port%d)' "$((connector - 1))"; fi
    if (( opcode == 16 )); then
      printf ' partner=%d source_pdos=%d offset=%d count=%d' \
        "$(((command >> 23) & 1))" "$(((command >> 34) & 1))" \
        "$(((command >> 24) & 255))" "$((((command >> 32) & 3) + 1))"
    elif (( opcode == 21 )); then
      printf ' recipient=%d offset=%d bytes=%d type=%d' \
        "$(((command >> 23) & 7))" "$(((command >> 26) & 255))" \
        "$(((command >> 34) & 255))" "$(((command >> 42) & 7))"
    fi
  fi
  printf '\n'
done < "$1"
