#!/usr/bin/env bash
set -euo pipefail

# wf-recorder toggle with dunst notifications
# - If wf-recorder is running: stop it (graceful) and notify
# - If not running: select region with slurp, start recording, notify
#
# Dependencies: wf-recorder, slurp, dunst (notify-send), (optional) jq for nicer checks
# Install on NixOS: wf-recorder slurp libnotify dunst

APP="wf-recorder"
ICON="video-x-generic"
VIDEOS_DIR="${XDG_VIDEOS_DIR:-$HOME/Videos}"
STAMP="$(date +%F_%H-%M-%S)"
OUT_FILE="$VIDEOS_DIR/recording_${STAMP}.mp4"

notify() {
  # dunst listens to notify-send (libnotify)
  notify-send -a "$APP" -i "$ICON" "$@"
}

is_running() {
  pgrep -x wf-recorder >/dev/null 2>&1
}

stop() {
  # Graceful stop (equivalent to Ctrl+C)
  pkill -INT wf-recorder >/dev/null 2>&1 || true
}

start() {
  mkdir -p "$VIDEOS_DIR"

  # Pick a region; slurp returns non-zero if cancelled
  if ! GEOM="$(slurp)"; then
    notify "Recording cancelled"
    exit 0
  fi

  notify "Recording started" "Saving to: $(basename "$OUT_FILE")"
  # Blocks until stopped; that's fine for Hyprland exec binds
  wf-recorder -g "$GEOM" -f "$OUT_FILE" \
    && notify "Recording saved" "$OUT_FILE" \
    || notify "Recording stopped" "Output may be incomplete: $OUT_FILE"
}

if is_running; then
  stop
  notify "Recording stopped"
  exit 0
fi

start

