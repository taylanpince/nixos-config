#!/usr/bin/env bash
set -euo pipefail

NAME="scratchpad"
CLASS="kitty-scratchpad"

# if the scratchpad kitty exists, just toggle visibility
if hyprctl clients -j | jq -e --arg c "$CLASS" '.[] | select(.class == $c)' >/dev/null; then
  hyprctl dispatch togglespecialworkspace "$NAME"
  exit 0
fi

# otherwise spawn it (it will be moved to the special workspace by window rules)
kitty --class "$CLASS" --title "$CLASS" & disown

# give it a moment to appear, then show the special workspace
sleep 0.1
hyprctl dispatch togglespecialworkspace "$NAME"

