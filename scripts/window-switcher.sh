#!/usr/bin/env bash

STYLE="${XDG_CONFIG_HOME:-$HOME/.config}/wofi/style.css"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}/wofi/config"

# Build list: ws | class | title | address
list="$(
  hyprctl clients -j 2>/dev/null | jq -r '
    .[]
    | select(.mapped == true)
    | select((.workspace.name | startswith("special:")) | not)
    | "\(.class)\t\(.title)"
  '
)"

# If list is empty, do nothing (quietly).
[ -z "$list" ] && exit 0

choice="$(
  printf '%s\n' "$list" |
    wofi --dmenu --normal-window --prompt "Windows" \
      --style "$STYLE" --conf "$CONF"
)"

[ -z "$choice" ] && exit 0

addr="$(printf '%s' "$choice" | cut -f4)"
[ -z "$addr" ] && exit 0

hyprctl dispatch focuswindow "address:${addr}" >/dev/null 2>&1 || true
