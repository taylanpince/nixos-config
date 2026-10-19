#!/usr/bin/env bash
# System controls

show_system_menu() {
  clear
  show_header
  gum style --foreground="$SUBTEXT" "System"
  echo ""
  
  local choice
  choice=$(gum choose --cursor.foreground="$ACCENT" \
    "󰓅  Power Profile" \
    "󰤄  Sleep" \
    "󰜉  Reboot" \
    "󰐥  Shutdown" \
    "󰒓  Services" \
    "󰌍  Back")

  case "$choice" in
    *Power*)    set_power_profile ;;
    *Sleep*)    do_sleep ;;
    *Reboot*)   do_reboot ;;
    *Shutdown*) do_shutdown ;;
    *Services*) show_services ;;
    *Back*)     back_to_main ;;
  esac
}

set_power_profile() {
  if ! command -v powerprofilesctl &> /dev/null; then
    notify "power-profiles-daemon not available" "error"
    pause
    show_system_menu
    return
  fi

  local current
  current=$(powerprofilesctl get 2>/dev/null || echo "unknown")
  
  gum style --foreground="$SUBTEXT" "Current: $current"
  echo ""
  
  local profile
  profile=$(gum choose --cursor.foreground="$ACCENT" \
    "performance" \
    "balanced" \
    "power-saver" \
    "← Back")

  if [[ "$profile" != "← Back" ]]; then
    powerprofilesctl set "$profile"
    notify "Power profile set to $profile" "success"
    pause
  fi
  show_system_menu
}

do_sleep() {
  if confirm "Suspend the system?"; then
    systemctl suspend
  fi
  show_system_menu
}

do_reboot() {
  if confirm "Reboot now?"; then
    systemctl reboot
  fi
  show_system_menu
}

do_shutdown() {
  if confirm "Shutdown now?"; then
    systemctl poweroff
  fi
  show_system_menu
}

show_services() {
  clear
  show_header
  gum style --foreground="$SUBTEXT" "System Services"
  echo ""
  
  local services
  services=$(systemctl list-units --type=service --state=running --no-pager --no-legend | head -20 | awk '{print $1}')
  
  local service
  service=$(echo "$services" | gum filter --placeholder="Search services...")
  
  if [[ -n "$service" ]]; then
    local action
    action=$(gum choose --cursor.foreground="$ACCENT" \
      "󰈈  Status" \
      "󰜉  Restart" \
      "󰓛  Stop" \
      "󰌍  Back")
    
    case "$action" in
      *Status*)  systemctl status "$service" --no-pager | gum pager ;;
      *Restart*) 
        if confirm "Restart $service?"; then
          spinner "Restarting $service..." sudo systemctl restart "$service"
          notify "Service restarted" "success"
        fi
        ;;
      *Stop*)
        if confirm "Stop $service?"; then
          spinner "Stopping $service..." sudo systemctl stop "$service"
          notify "Service stopped" "success"
        fi
        ;;
    esac
    pause
  fi
  show_system_menu
}
