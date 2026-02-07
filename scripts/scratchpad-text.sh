#!/usr/bin/env bash
set -euo pipefail

WS="notes"
CLASS="org.gnome.TextEditor"

is_special_visible() {
  hyprctl monitors -j | jq -e --arg ws "special:${WS}" \
    '.[] | select(.focused==true) | .specialWorkspace.name == $ws' >/dev/null
}

have_window() {
  hyprctl clients -j | jq -e --arg c "$CLASS" \
    '.[] | select(.class==$c)' >/dev/null
}

focus_window() {
  hyprctl dispatch focuswindow "class:^(${CLASS})$" >/dev/null 2>&1 || true
}

# If special workspace is visible, hide it and DO NOT focus anything on it.
if is_special_visible; then
  hyprctl dispatch togglespecialworkspace "${WS}" >/dev/null
  exit 0
fi

# Otherwise, ensure the window exists
if ! have_window; then
  setsid -f gnome-text-editor >/dev/null 2>&1 || true

  # wait for the window
  for _ in $(seq 1 60); do
    sleep 0.05
    have_window && break
  done

  # move it to the special workspace (only once, on first creation)
  focus_window
  hyprctl dispatch movetoworkspace "special:${WS}" >/dev/null
fi

# Show + focus
hyprctl dispatch togglespecialworkspace "${WS}" >/dev/null
focus_window

