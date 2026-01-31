#!/run/current-system/sw/bin/bash
set -euo pipefail

STYLE="${XDG_CONFIG_HOME:-$HOME/.config}/wofi/style.css"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}/wofi/config"

# MRU list written by hypr-mru-tracker.sh
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hypr"
MRU_FILE="$CACHE_DIR/window-mru.txt"

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

trim() { sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }

get_kv_from_desktop() {
  local file="$1" key="$2"
  grep -m1 -E "^${key}=" "$file" | sed -E "s/^${key}=//"
}

resolve_icon_path() {
  local icon="$1"
  icon="$(printf '%s' "$icon" | trim)"
  [ -z "$icon" ] && { printf '%s' ""; return 0; }

  if [[ "$icon" == /* ]] && [ -f "$icon" ]; then
    printf '%s' "$icon"
    return 0
  fi

  if [[ "$icon" == *.png || "$icon" == *.svg || "$icon" == *.xpm ]]; then
    for dir in "${ICON_DIRS[@]}"; do
      [ -f "$dir/$icon" ] && { printf '%s' "$dir/$icon"; return 0; }
    done
  fi

  for dir in "${ICON_DIRS[@]}"; do
    local found=""
    found="$(find -L "$dir" -maxdepth 6 -type f \( \
        -name "${icon}.png" -o -name "${icon}.svg" -o -name "${icon}.xpm" \
      \) 2>/dev/null | head -n 1 || true)"
    [ -n "$found" ] && { printf '%s' "$found"; return 0; }
  done

  printf '%s' ""
}

desktop_from_class_override() {
  local cls="$1"
  local f=""
  case "$cls" in
    brave-browser|Brave-browser|brave|Brave)
      for dir in "${DESKTOP_DIRS[@]}"; do
        f="$dir/com.brave.Browser.desktop"
        [ -f "$f" ] && { printf '%s' "$f"; return 0; }
      done
      ;;
  esac
  printf '%s' ""
}

find_best_desktop_for_class() {
  local cls="$1"
  local best=""

  best="$(desktop_from_class_override "$cls")"
  [ -n "$best" ] && { printf '%s' "$best"; return 0; }

  for dir in "${DESKTOP_DIRS[@]}"; do
    best="$(grep -RIl --include='*.desktop' -m1 -E "^StartupWMClass=${cls}$" "$dir" 2>/dev/null || true)"
    [ -n "$best" ] && { printf '%s' "$best"; return 0; }
  done

  for dir in "${DESKTOP_DIRS[@]}"; do
    best="$(find "$dir" -maxdepth 1 -type f -name "*${cls}*.desktop" 2>/dev/null | head -n 1 || true)"
    [ -n "$best" ] && { printf '%s' "$best"; return 0; }
  done

  for dir in "${DESKTOP_DIRS[@]}"; do
    best="$(grep -RIl --include='*.desktop' -m1 -F "$cls" "$dir" 2>/dev/null || true)"
    [ -n "$best" ] && { printf '%s' "$best"; return 0; }
  done

  printf '%s' ""
}

pretty_label_for_client() {
  local cls="$1" title="$2"
  local desktop="" name="" icon="" icon_path=""

  desktop="$(find_best_desktop_for_class "$cls")"
  if [ -n "$desktop" ]; then
    name="$(get_kv_from_desktop "$desktop" "Name" | trim)"
    icon="$(get_kv_from_desktop "$desktop" "Icon" | trim)"
    icon_path="$(resolve_icon_path "$icon")"
  fi

  if [[ -z "$icon_path" && ( "$cls" == "brave-browser" || "$cls" == "Brave-browser" ) ]]; then
    icon_path="$(resolve_icon_path "com.brave.Browser")"
    [ -z "$icon_path" ] && icon_path="$(resolve_icon_path "brave-browser")"
    [ -z "$icon_path" ] && icon_path="$(resolve_icon_path "brave")"
  fi
  if [[ -z "$name" && ( "$cls" == "brave-browser" || "$cls" == "Brave-browser" ) ]]; then
    name="Brave Browser"
  fi

  [ -z "$name" ] && name="$cls"

  name="${name//$'\t'/ }"
  name="${name//$'\n'/ }"
  title="${title//$'\t'/ }"
  title="${title//$'\n'/ }"

  if [ -n "$icon_path" ]; then
    printf 'img:%s:text:%s — %s' "$icon_path" "$name" "$title"
  else
    printf '%s — %s' "$name" "$title"
  fi
}

clients_json="$(hyprctl clients -j 2>/dev/null || true)"
[ -z "$clients_json" ] && exit 0

declare -A brave_pids=()
while IFS=$'\t' read -r pid cls icls title; do
  [[ -z "${pid:-}" || "$pid" == "0" ]] && continue
  if [[ "$cls" == brave* || "$icls" == brave* || "$title" == *" - Brave" ]]; then
    brave_pids["$pid"]=1
  fi
done < <(
  jq -r '
    .[]
    | select(.mapped == true)
    | select((.workspace.name | startswith("special:")) | not)
    | "\(.pid)\t\(.class)\t\(.initialClass)\t\(.title)"
  ' <<<"$clients_json" 2>/dev/null
)

# Read MRU file into an associative map: address -> rank (0 is most recent)
declare -A rank=()
if [[ -f "$MRU_FILE" ]]; then
  i=0
  while IFS= read -r addr; do
    [[ -z "$addr" ]] && continue
    rank["$addr"]=$i
    i=$((i+1))
  done < "$MRU_FILE"
fi

# Build list with a sort key: known addresses first by rank, then unknowns by title
# We'll emit: key<TAB>label<TAB>addr
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

jq -r '
  .[]
  | select(.mapped == true)
  | select((.workspace.name | startswith("special:")) | not)
  | "\(.pid)\t\(.class)\t\(.initialClass)\t\(.title)\t\(.initialTitle)\t\(.address)"
' <<<"$clients_json" | while IFS=$'\t' read -r pid cls icls title ititle addr; do
  effective_cls="$cls"
  if [[ -n "${brave_pids[$pid]+x}" ]]; then
    if [[ "$cls" == brave-* || "$icls" == brave-* ]]; then
      effective_cls="$cls"
    else
      if [[ "$title" == *" - Brave" || "$ititle" == *" - Brave" ]]; then
        effective_cls="brave-browser"
      fi
    fi
  fi

  label="$(pretty_label_for_client "$effective_cls" "$title")"

  if [[ -n "${rank[$addr]+x}" ]]; then
    # pad rank so sort works lexicographically
    printf '0:%05d\t%s\t%s\n' "${rank[$addr]}" "$label" "$addr" >> "$tmp"
  else
    # unknowns come after, sorted by label
    # we include label as part of key for stable alphabetical among unknowns
    printf '1:%s\t%s\t%s\n' "$label" "$label" "$addr" >> "$tmp"
  fi
done

mapfile -t sorted < <(sort -t $'\t' -k1,1 "$tmp")

labels=()
addrs=()
for line in "${sorted[@]}"; do
  # key \t label \t addr
  lbl="${line#*$'\t'}"
  addr="${lbl##*$'\t'}"
  lbl="${lbl%$'\t'*}"
  labels+=("$lbl")
  addrs+=("$addr")
done


# macOS-style default: first selection should be the *previously* focused window,
# not the currently active one. If the current active window is at the top,
# swap the first two entries so the previous window becomes index 0.
active_addr="$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty' 2>/dev/null || true)"
if [[ -n "$active_addr" && "${#addrs[@]}" -ge 2 && "${addrs[0]}" == "$active_addr" ]]; then
  tmp_lbl="${labels[0]}"; labels[0]="${labels[1]}"; labels[1]="$tmp_lbl"
  tmp_addr="${addrs[0]}"; addrs[0]="${addrs[1]}"; addrs[1]="$tmp_addr"
fi


[ "${#labels[@]}" -eq 0 ] && exit 0

tmpconf="$(mktemp)"
trap 'rm -f "$tmpconf"' EXIT
if [[ -f "$CONF" ]]; then
  cat "$CONF" > "$tmpconf"
fi
{
  echo ""
  echo "# window switcher override"
  echo "dmenu-print_line_num=true"
} >> "$tmpconf"

idx="$(
  printf '%s\n' "${labels[@]}" |
    wofi --dmenu --prompt "Windows" \
      --allow-images \
      --style "$STYLE" --conf "$tmpconf" \
      --width 700 --height 600
)"

[ -z "${idx:-}" ] && exit 0
[[ "$idx" =~ ^[0-9]+$ ]] || exit 0

if [[ "$idx" -ge "${#addrs[@]}" && "$idx" -gt 0 ]]; then
  idx=$((idx - 1))
fi

addr="${addrs[$idx]:-}"
[ -n "$addr" ] && hyprctl dispatch focuswindow "address:${addr}" >/dev/null 2>&1 || true
