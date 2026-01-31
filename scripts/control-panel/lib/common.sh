#!/usr/bin/env bash
# Common functions and variables

# Colors (Catppuccin Mocha)
export ACCENT="#cba6f7"      # Mauve
export SUCCESS="#a6e3a1"     # Green
export WARNING="#f9e2af"     # Yellow
export ERROR="#f38ba8"       # Red
export TEXT="#cdd6f4"        # Text
export SUBTEXT="#a6adc8"     # Subtext0

show_header() {
  gum style \
    --foreground="$ACCENT" \
    --border="rounded" \
    --border-foreground="$ACCENT" \
    --padding="0 2" \
    --margin="1" \
    "󱄅  NixOS Control Panel"
}

confirm() {
  gum confirm --affirmative="Yes" --negative="No" "$1"
}

notify() {
  local msg="$1"
  local level="${2:-info}"
  
  case "$level" in
    success) gum style --foreground="$SUCCESS" "✓ $msg" ;;
    warning) gum style --foreground="$WARNING" "⚠ $msg" ;;
    error)   gum style --foreground="$ERROR" "✗ $msg" ;;
    *)       gum style --foreground="$TEXT" "→ $msg" ;;
  esac
}

spinner() {
  gum spin --spinner dot --title "$1" -- "${@:2}"
}

pause() {
  echo ""
  gum style --foreground="$SUBTEXT" "Press any key to continue..."
  read -n 1 -s
}

back_to_main() {
  return 0
}
