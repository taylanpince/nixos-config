#!/usr/bin/env bash
set -euo pipefail

STYLE="${XDG_CONFIG_HOME:-$HOME/.config}/wofi/style.css"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}/wofi/config"

# --- Desktop file search paths (NixOS-friendly) ---
USER_APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
SYS_APPS_1="/run/current-system/sw/share/applications"
SYS_APPS_2="/usr/share/applications"
SYS_APPS_3="/etc/profiles/per-user/${USER:-$(whoami)}/share/applications"

DESKTOP_DIRS=()
for d in "$USER_APPS" "$SYS_APPS_3" "$SYS_APPS_1" "$SYS_APPS_2"; do
  [ -d "$d" ] && DESKTOP_DIRS+=("$d")
done

# Icon lookup paths (best-effort)
ICON_DIRS=()
for d in \
  "${XDG_DATA_HOME:-$HOME/.local/share}/icons" \
  "$HOME/.icons" \
  "/usr/share/icons" \
  "/usr/share/pixmaps" \
  "/run/current-system/sw/share/icons" \
  "/run/current-system/sw/share/pixmaps"
do
  [ -d "$d" ] && ICON_DIRS+=("$d")
done

# --- helpers ---
trim() { sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }

get_kv_from_desktop() {
  # args: desktop_file key
  # prints first matching value (handles "Key=Value")
  local file="$1" key="$2"
  grep -m1 -E "^${key}=" "$file" | sed -E "s/^${key}=//"
}

resolve_icon_path() {
  # args: Icon value
  local icon="$1"
  icon="$(printf '%s' "$icon" | trim)"

  # Absolute path
  if [[ "$icon" == /* ]] && [ -f "$icon" ]; then
    printf '%s' "$icon"
    return 0
  fi

  # If it's something like "foo.png" and exists somewhere obvious
  if [[ "$icon" == *.png || "$icon" == *.svg || "$icon" == *.xpm ]]; then
    for dir in "${ICON_DIRS[@]}"; do
      if [ -f "$dir/$icon" ]; then
        printf '%s' "$dir/$icon"
        return 0
      fi
    done
  fi

  # Theme/icon-name lookup: try icon.{png,svg,xpm} anywhere in ICON_DIRS (bounded depth)
  for dir in "${ICON_DIRS[@]}"; do
    # keep it cheap-ish
    local found=""
    found="$(find -L "$dir" -maxdepth 5 -type f \( \
        -name "${icon}.png" -o -name "${icon}.svg" -o -name "${icon}.xpm" \
      \) 2>/dev/null | head -n 1 || true)"
    if [ -n "$found" ]; then
      printf '%s' "$found"
      return 0
    fi
  done

  # give up
  printf '%s' ""
}

find_best_desktop_for_class() {
  # args: class
  local cls="$1"
  local best=""

  # 1) StartupWMClass exact match
  for dir in "${DESKTOP_DIRS[@]}"; do
    best="$(grep -RIl --include='*.desktop' -m1 -E "^StartupWMClass=${cls}$" "$dir" 2>/dev/null || true)"
    [ -n "$best" ] && { printf '%s' "$best"; return 0; }
  done

  # 2) filename contains the class (very common for PWAs)
  for dir in "${DESKTOP_DIRS[@]}"; do
    best="$(find "$dir" -maxdepth 1 -type f -name "*${cls}*.desktop" 2>/dev/null | head -n 1 || true)"
    [ -n "$best" ] && { printf '%s' "$best"; return 0; }
  done

  # 3) Exec contains the class (fallback)
  for dir in "${DESKTOP_DIRS[@]}"; do
    best="$(grep -RIl --include='*.desktop' -m1 -F "$cls" "$dir" 2>/dev/null || true)"
    [ -n "$best" ] && { printf '%s' "$best"; return 0; }
  done

  printf '%s' ""
}

pretty_label_for_client() {
  # args: class title
  local cls="$1" title="$2"
  local desktop="" name="" icon="" icon_path=""

  desktop="$(find_best_desktop_for_class "$cls")"
  if [ -n "$desktop" ]; then
    name="$(get_kv_from_desktop "$desktop" "Name" | trim)"
    icon="$(get_kv_from_desktop "$desktop" "Icon" | trim)"
    icon_path="$(resolve_icon_path "$icon")"
  fi

  # Fallbacks
  [ -z "$name" ] && name="$cls"

  # Sanitize tabs/newlines for dmenu output
  name="${name//$'\t'/ }"
  name="${name//$'\n'/ }"
  title="${title//$'\t'/ }"
  title="${title//$'\n'/ }"

  # Compose label: icon + "Name — Title"
  if [ -n "$icon_path" ]; then
    printf 'img:%s:text:%s — %s' "$icon_path" "$name" "$title"
  else
    printf '%s — %s' "$name" "$title"
  fi
}

# --- build list of windows (exclude special:*) ---
list="$(
  hyprctl clients -j 2>/dev/null | jq -r '
    .[]
    | select(.mapped == true)
    | select((.workspace.name | startswith("special:")) | not)
    | "\(.workspace.name)\t\(.class)\t\(.title)\t\(.address)"
  ' 2>/dev/null
)"

[ -z "$list" ] && exit 0

# Convert to labels + parallel address array (address is NOT printed)
labels=()
addrs=()

while IFS=$'\t' read -r ws cls title addr; do
  label="$(pretty_label_for_client "$cls" "$title")"
  labels+=("$label")
  addrs+=("$addr")
done <<< "$list"

[ "${#labels[@]}" -eq 0 ] && exit 0

# Use a temporary config that enables line-number output for dmenu
tmpconf="$(mktemp)"
trap 'rm -f "$tmpconf"' EXIT
cat "$CONF" > "$tmpconf"
printf '\n# window switcher override\n' >> "$tmpconf"
printf 'dmenu-print_line_num=true\n' >> "$tmpconf"

choice="$(
  printf '%s\n' "${labels[@]}" |
    wofi --dmenu --prompt "Windows" \
      --allow-images --parse-action \
      --style "$STYLE" --conf "$tmpconf" \
      --width 700 --height 600
)"

[ -z "${choice}" ] && exit 0

# wofi prints the selected line number; handle 0-based vs 1-based safely
idx="$choice"
if ! [[ "$idx" =~ ^[0-9]+$ ]]; then
  exit 0
fi

if [ "$idx" -ge "${#addrs[@]}" ] && [ "$idx" -gt 0 ]; then
  idx=$((idx - 1))
fi

addr="${addrs[$idx]:-}"
[ -n "$addr" ] && hyprctl dispatch focuswindow "address:${addr}" >/dev/null 2>&1 || true

