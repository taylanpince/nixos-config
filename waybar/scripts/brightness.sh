#!/usr/bin/env bash
set -euo pipefail

pct() {
  local cur max
  cur="$(brightnessctl g)"
  max="$(brightnessctl m)"
  awk -v c="$cur" -v m="$max" 'BEGIN{printf "%.0f", (c/m)*100}'
}

icon_for() {
  local p="$1"
  if (( p <= 5 )); then echo "󰃞"
  elif (( p <= 25 )); then echo "󰃟"
  elif (( p <= 50 )); then echo "󰃠"
  elif (( p <= 75 )); then echo "󰃡"
  else echo "󰃢"
  fi
}

status_json() {
  local p icon
  p="$(pct)"
  icon="$(icon_for "$p")"
  printf '{"text":"%s","tooltip":"Brightness: %s%%\\nScroll: ±5%%\\nClick: menu"}\n' "$icon" "$p"
}

menu() {
  local choice
  choice="$(printf "0%%\n25%%\n50%%\n75%%\n100%%\n" | rofi -dmenu -p "Brightness")" || exit 0
  brightnessctl s "$choice" >/dev/null
}

case "${1:-}" in
  --status) status_json ;;
  --menu) menu ;;
  *) echo "usage: $0 --status|--menu" >&2; exit 2 ;;
esac

