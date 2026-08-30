#!/usr/bin/env bash
# Display controls

show_display_menu() {
  clear
  show_header
  gum style --foreground="$SUBTEXT" "Display"
  echo ""
  
  local choice
  choice=$(gum choose --cursor.foreground="$ACCENT" \
    "󰃟  Brightness" \
    "󰍹  Monitors" \
    "󰌍  Back")

  case "$choice" in
    *Brightness*) set_brightness ;;
    *Monitors*)   show_monitors ;;
    *Back*)       back_to_main ;;
  esac
}

set_brightness() {
  if ! command -v brightnessctl &> /dev/null; then
    notify "brightnessctl not available" "error"
    pause
    show_display_menu
    return
  fi

  local current
  current=$(brightnessctl -m | cut -d',' -f4 | tr -d '%')
  
  gum style --foreground="$SUBTEXT" "Current brightness: ${current}%"
  echo ""
  
  local level
  level=$(gum choose --cursor.foreground="$ACCENT" \
    "100%" \
    "75%" \
    "50%" \
    "25%" \
    "10%" \
    "← Back")

  if [[ "$level" != "← Back" ]]; then
    brightnessctl set "$level"
    notify "Brightness set to $level" "success"
    pause
  fi
  show_display_menu
}

show_monitors() {
  clear
  show_header
  gum style --foreground="$SUBTEXT" "Connected Monitors"
  echo ""
  
  hyprctl monitors -j | jq -r '.[] | "󰍹 \(.name): \(.width)x\(.height)@\(.refreshRate)Hz"' 2>/dev/null || \
    notify "Could not get monitor info" "error"
  
  pause
  show_display_menu
}
