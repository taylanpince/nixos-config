#!/usr/bin/env bash
# Theme controls

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

show_theme_menu() {
  clear
  show_header
  gum style --foreground="$SUBTEXT" "Theme"
  echo ""
  
  local choice
  choice=$(gum choose --cursor.foreground="$ACCENT" \
    "󰸌  Random Wallpaper" \
    "󰋩  Select Wallpaper" \
    "󰌍  Back")

  case "$choice" in
    *Random*) random_wallpaper ;;
    *Select*) select_wallpaper ;;
    *Back*)   back_to_main ;;
  esac
}

random_wallpaper() {
  if [[ -d "$WALLPAPER_DIR" ]]; then
    local wallpaper
    wallpaper=$(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" \) | shuf -n 1)
    
    if [[ -n "$wallpaper" ]]; then
      set_wallpaper "$wallpaper"
      notify "Wallpaper changed" "success"
    else
      notify "No wallpapers found in $WALLPAPER_DIR" "error"
    fi
  else
    notify "Wallpaper directory not found: $WALLPAPER_DIR" "error"
  fi
  pause
  show_theme_menu
}

select_wallpaper() {
  if [[ ! -d "$WALLPAPER_DIR" ]]; then
    notify "Wallpaper directory not found: $WALLPAPER_DIR" "error"
    pause
    show_theme_menu
    return
  fi
  
  local wallpapers
  wallpapers=$(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" \) -printf "%f\n" | sort)
  
  if [[ -z "$wallpapers" ]]; then
    notify "No wallpapers found" "error"
    pause
    show_theme_menu
    return
  fi
  
  local selection
  selection=$(echo "$wallpapers" | gum filter --placeholder="Select wallpaper...")
  
  if [[ -n "$selection" ]]; then
    set_wallpaper "$WALLPAPER_DIR/$selection"
    notify "Wallpaper set to $selection" "success"
    pause
  fi
  show_theme_menu
}

set_wallpaper() {
  local path="$1"
  
  # Update hyprpaper config
  if command -v hyprpaper &> /dev/null; then
    hyprctl hyprpaper wallpaper "eDP-1,$path" 2>/dev/null || true
    hyprctl hyprpaper wallpaper "DP-4,$path" 2>/dev/null || true
  fi
  
  # Also try swaybg if available
  if pgrep -x swaybg &> /dev/null; then
    pkill swaybg
    swaybg -i "$path" -m fill &
  fi
}
