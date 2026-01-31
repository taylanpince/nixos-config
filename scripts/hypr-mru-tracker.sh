#!/run/current-system/sw/bin/bash
# hypr-mru-tracker.sh
# Keeps a Most-Recently-Used (MRU) list of focused window addresses for Hyprland.
#
# Writes: $XDG_CACHE_HOME/hypr/window-mru.txt  (newest first)
#
# Requires: socat, hyprctl
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1; }
need socat
need hyprctl

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hypr"
MRU_FILE="$CACHE_DIR/window-mru.txt"
mkdir -p "$CACHE_DIR"
touch "$MRU_FILE"

sig="${HYPRLAND_INSTANCE_SIGNATURE:-}"
if [[ -z "$sig" ]]; then
  echo "HYPRLAND_INSTANCE_SIGNATURE is not set (are you running under Hyprland?)" >&2
  exit 1
fi

sock="${XDG_RUNTIME_DIR}/hypr/${sig}/.socket2.sock"
if [[ ! -S "$sock" ]]; then
  echo "Hyprland event socket not found: $sock" >&2
  exit 1
fi

# Insert address at top of MRU file (dedupe)
bump() {
  local addr="$1"
  [[ -z "$addr" ]] && return 0
  # Basic validation: Hyprland addresses look like 0x...
  [[ "$addr" != 0x* ]] && return 0

  # Rewrite atomically
  local tmp
  tmp="$(mktemp)"
  {
    echo "$addr"
    grep -v -F "$addr" "$MRU_FILE" || true
  } | awk 'NF' | head -n 200 > "$tmp"
  mv "$tmp" "$MRU_FILE"
}

# Prime MRU with current active window
active_addr="$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty' 2>/dev/null || true)"
bump "$active_addr"

# Listen for focus changes
# Event lines look like: "activewindow>>Title,Class"
# We don't get the address directly, so we query hyprctl activewindow on each event.
socat -U - "UNIX-CONNECT:${sock}" | while IFS= read -r line; do
  case "$line" in
    activewindow*|activewindowv2*)
      addr="$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty' 2>/dev/null || true)"
      bump "$addr"
      ;;
  esac
done
