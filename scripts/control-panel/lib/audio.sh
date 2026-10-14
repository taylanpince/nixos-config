#!/usr/bin/env bash
# Audio controls

show_audio_menu() {
  clear
  show_header
  gum style --foreground="$SUBTEXT" "Audio"
  echo ""
  
  # Show current volume
  local vol
  vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print int($2*100)}')
  gum style --foreground="$SUBTEXT" "Volume: ${vol:-?}%"
  echo ""
  
  local choice
  choice=$(gum choose --cursor.foreground="$ACCENT" \
    "󰕾  Volume" \
    "󰓃  Output Device" \
    "󰍬  Input Device" \
    "󰖁  Mute Toggle" \
    "󰌍  Back")

  case "$choice" in
    *Volume*) set_volume ;;
    *Output*) select_output ;;
    *Input*)  select_input ;;
    *Mute*)   toggle_mute ;;
    *Back*)   back_to_main ;;
  esac
}

set_volume() {
  local level
  level=$(gum choose --cursor.foreground="$ACCENT" \
    "100%" \
    "75%" \
    "50%" \
    "25%" \
    "10%" \
    "0%" \
    "← Back")

  if [[ "$level" != "← Back" ]]; then
    local val
    val=$(echo "$level" | tr -d '%')
    wpctl set-volume @DEFAULT_AUDIO_SINK@ "${val}%"
    notify "Volume set to $level" "success"
    pause
  fi
  show_audio_menu
}

select_output() {
  clear
  show_header
  gum style --foreground="$SUBTEXT" "Output Devices"
  echo ""
  
  local devices
  devices=$(wpctl status | sed -n '/Sinks:/,/Sources:/p' | grep -E '^\s+[0-9]+\.' | sed 's/^[ \t]*//')
  
  if [[ -z "$devices" ]]; then
    notify "No output devices found" "error"
    pause
    show_audio_menu
    return
  fi
  
  local device
  device=$(echo "$devices" | gum choose --cursor.foreground="$ACCENT")
  
  if [[ -n "$device" ]]; then
    local id
    id=$(echo "$device" | grep -oE '^[0-9]+')
    wpctl set-default "$id"
    notify "Output device changed" "success"
    pause
  fi
  show_audio_menu
}

select_input() {
  clear
  show_header
  gum style --foreground="$SUBTEXT" "Input Devices"
  echo ""
  
  local devices
  devices=$(wpctl status | sed -n '/Sources:/,/Filters:/p' | grep -E '^\s+[0-9]+\.' | sed 's/^[ \t]*//')
  
  if [[ -z "$devices" ]]; then
    notify "No input devices found" "error"
    pause
    show_audio_menu
    return
  fi
  
  local device
  device=$(echo "$devices" | gum choose --cursor.foreground="$ACCENT")
  
  if [[ -n "$device" ]]; then
    local id
    id=$(echo "$device" | grep -oE '^[0-9]+')
    wpctl set-default "$id"
    notify "Input device changed" "success"
    pause
  fi
  show_audio_menu
}

toggle_mute() {
  wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
  local muted
  muted=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q MUTED && echo "yes" || echo "no")
  if [[ "$muted" == "yes" ]]; then
    notify "Audio muted" "warning"
  else
    notify "Audio unmuted" "success"
  fi
  pause
  show_audio_menu
}
