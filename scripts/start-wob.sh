#!/usr/bin/env bash
# Single source of truth for launching the wob OSD daemon.
# Called by Hyprland exec-once and by theme.sh (to restart after a palette swap).
set -euo pipefail

PIPE="${WOB_PIPE:-/tmp/wobpipe}"

pkill -x wob 2>/dev/null || true
rm -f "$PIPE"
mkfifo -m 600 "$PIPE"
tail -f "$PIPE" | wob &
