#!/usr/bin/env bash
set -euo pipefail

# toggle recording in OBS
obs-do toggle-record

# toggle the key overlay app (OBS captures its window when running)
if pgrep -f 'showmethekey-gtk' >/dev/null || pgrep -f 'showmethekey-(cli|gtk)|showmethekey' >/dev/null; then
  # kill GUI (user)
  pkill -f 'showmethekey-gtk' 2>/dev/null || true

  # kill backend (root via pkexec)
  pkexec pkill -f 'showmethekey-(cli|gtk)|showmethekey' 2>/dev/null || true
else
  (showmethekey-gtk --no-app-window >/dev/null 2>&1 & disown) || true
fi
