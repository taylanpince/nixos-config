#!/usr/bin/env bash
# Switch swaync config between laptop and external display sizes.
# Called by display-hotplug.sh when monitor state changes.

SWAYNC_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/swaync"

have_ext() {
  hyprctl monitors 2>/dev/null | grep -q "Monitor DP-4 "
}

if have_ext; then
  cp "$SWAYNC_DIR/config.external.json" "$SWAYNC_DIR/config.json"
  cp "$SWAYNC_DIR/style.external.css"   "$SWAYNC_DIR/style.css"
else
  cp "$SWAYNC_DIR/config.laptop.json" "$SWAYNC_DIR/config.json"
  cp "$SWAYNC_DIR/style.laptop.css"   "$SWAYNC_DIR/style.css"
fi

swaync-client --reload-config
