#!/usr/bin/env bash
# Network controls

show_network_menu() {
  clear
  show_header
  gum style --foreground="$SUBTEXT" "Network"
  echo ""
  
  # Show current status
  local wifi_status
  wifi_status=$(nmcli -t -f WIFI g 2>/dev/null || echo "unknown")
  local conn
  conn=$(nmcli -t -f NAME c show --active 2>/dev/null | head -1 || echo "none")
  
  gum style --foreground="$SUBTEXT" "WiFi: $wifi_status | Connected: $conn"
  echo ""
  
  local choice
  choice=$(gum choose --cursor.foreground="$ACCENT" \
    "󰖩  WiFi Networks" \
    "󰖪  Toggle WiFi" \
    "󰌘  VPN" \
    "󰌍  Back")

  case "$choice" in
    *Networks*) select_wifi ;;
    *Toggle*)   toggle_wifi ;;
    *VPN*)      show_vpn_menu ;;
    *Back*)     back_to_main ;;
  esac
}

select_wifi() {
  clear
  show_header
  gum style --foreground="$SUBTEXT" "Available Networks"
  echo ""
  
  spinner "Scanning..." nmcli dev wifi rescan 2>/dev/null || true
  
  local networks
  networks=$(nmcli -t -f SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null | grep -v "^:" | head -15)
  
  if [[ -z "$networks" ]]; then
    notify "No networks found" "warning"
    pause
    show_network_menu
    return
  fi
  
  local network
  network=$(echo "$networks" | while IFS=: read -r ssid signal security; do
    echo "$ssid ($signal% $security)"
  done | gum filter --placeholder="Select network...")
  
  if [[ -n "$network" ]]; then
    local ssid
    ssid=$(echo "$network" | sed 's/ (.*//')
    
    if nmcli -t -f NAME c show | grep -q "^$ssid$"; then
      spinner "Connecting to $ssid..." nmcli c up "$ssid"
    else
      local password
      password=$(gum input --password --placeholder="Enter password for $ssid")
      if [[ -n "$password" ]]; then
        spinner "Connecting to $ssid..." nmcli dev wifi connect "$ssid" password "$password"
      fi
    fi
    
    if [[ $? -eq 0 ]]; then
      notify "Connected to $ssid" "success"
    else
      notify "Failed to connect" "error"
    fi
    pause
  fi
  show_network_menu
}

toggle_wifi() {
  local status
  status=$(nmcli -t -f WIFI g 2>/dev/null)
  
  if [[ "$status" == "enabled" ]]; then
    nmcli radio wifi off
    notify "WiFi disabled" "success"
  else
    nmcli radio wifi on
    notify "WiFi enabled" "success"
  fi
  pause
  show_network_menu
}

show_vpn_menu() {
  clear
  show_header
  gum style --foreground="$SUBTEXT" "VPN Connections"
  echo ""
  
  local vpns
  vpns=$(nmcli -t -f NAME,TYPE c show | grep vpn | cut -d: -f1)
  
  if [[ -z "$vpns" ]]; then
    # Check for Tailscale
    if command -v tailscale &> /dev/null; then
      local ts_status
      ts_status=$(tailscale status --json 2>/dev/null | jq -r '.BackendState' || echo "unknown")
      gum style --foreground="$SUBTEXT" "Tailscale: $ts_status"
      echo ""
      
      local action
      action=$(gum choose --cursor.foreground="$ACCENT" \
        "󰌘  Tailscale Up" \
        "󰌙  Tailscale Down" \
        "󰈈  Status" \
        "󰌍  Back")
      
      case "$action" in
        *Up*)     sudo tailscale up && notify "Tailscale connected" "success" ;;
        *Down*)   sudo tailscale down && notify "Tailscale disconnected" "success" ;;
        *Status*) tailscale status | gum pager ;;
      esac
      pause
    else
      notify "No VPN connections configured" "warning"
      pause
    fi
  else
    local vpn
    vpn=$(echo "$vpns" | gum choose --cursor.foreground="$ACCENT")
    if [[ -n "$vpn" ]]; then
      if nmcli c show --active | grep -q "$vpn"; then
        spinner "Disconnecting $vpn..." nmcli c down "$vpn"
        notify "VPN disconnected" "success"
      else
        spinner "Connecting $vpn..." nmcli c up "$vpn"
        notify "VPN connected" "success"
      fi
      pause
    fi
  fi
  show_network_menu
}
