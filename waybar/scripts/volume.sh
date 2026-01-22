#!/usr/bin/env bash
set -euo pipefail

sink='@DEFAULT_AUDIO_SINK@'

get() {
  # wpctl get-volume prints: "Volume: 0.52 [MUTED]"
  local out vol muted
  out="$(wpctl get-volume "$sink")"
  vol="$(awk '{print $2}' <<<"$out")"
  muted="$(grep -q MUTED <<<"$out" && echo yes || echo no)"

  # vol is 0.00-1.00 float
  # choose icon buckets
  if [[ "$muted" == "yes" ]]; then
    icon="󰝟"
    tip="Audio: muted"
  else
    # crude float compare using awk
    icon="$(awk -v v="$vol" 'BEGIN{
      if (v < 0.01) print "󰕿";
      else if (v < 0.33) print "󰖀";
      else print "󰕾";
    }')"
    tip="Scroll: volume ±5%\nClick: volume menu\nRight click: pavucontrol"
  fi

  printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$icon" "$tip" "$muted"
}

menu() {
  choice="$(printf "Mute toggle\n0%%\n25%%\n50%%\n75%%\n100%%\nOpen mixer\n" | rofi -dmenu -p "Volume" )" || exit 0
  case "$choice" in
    "Mute toggle") wpctl set-mute "$sink" toggle ;;
    "0%")   wpctl set-volume "$sink" 0% ;;
    "25%")  wpctl set-volume "$sink" 25% ;;
    "50%")  wpctl set-volume "$sink" 50% ;;
    "75%")  wpctl set-volume "$sink" 75% ;;
    "100%") wpctl set-volume "$sink" 100% ;;
    "Open mixer") pavucontrol >/dev/null 2>&1 & ;;
  esac
}

if [[ "${1:-}" == "--menu" ]]; then
  menu
else
  get
fi

