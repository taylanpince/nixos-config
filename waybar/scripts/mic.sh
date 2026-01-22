#!/usr/bin/env bash
set -euo pipefail

toggle() {
  pactl set-source-mute @DEFAULT_SOURCE@ toggle
}

status_json() {
  local muted
  muted="$(pactl get-source-mute @DEFAULT_SOURCE@ | awk '{print $2}')"

  if [[ "$muted" == "yes" ]]; then
    printf '{"text":"󰍭","tooltip":"Mic: muted","class":"muted"}\n'
  else
    printf '{"text":"󰍬","tooltip":"Mic: live","class":"live"}\n'
  fi
}

if [[ "${1:-}" == "--toggle" ]]; then
  toggle
fi

status_json