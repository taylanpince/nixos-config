#!/run/current-system/sw/bin/bash
# XDPH custom share picker using wofi (Hyprland / NixOS)
#
# Goals:
# - Works with xdg-desktop-portal-hyprland (XDPH) selection protocol (hyprland-share-picker compatible) citeturn1search8
# - NO IDs shown in UI (we map labels -> actions)
# - Screens use /screen:<name> (matches common hyprland-share-picker scripts) citeturn2view0
# - Windows: handle XDPH_WINDOW_SHARING_LIST entries that may embed [HA>]<handle>
#   by emitting the *handle* part (digits after [HA>]) if present.
# - Filters out the picker window itself to avoid selecting wofi and then it disappearing.
set -euo pipefail

STYLE="${XDG_CONFIG_HOME:-$HOME/.config}/wofi/style.css"

need() { command -v "$1" >/dev/null 2>&1; }
need wofi
need jq
need hyprctl

# Store menu entries (visible) and map them to actions (hidden)
declare -a entries=()
declare -A action_by_entry=()

add_entry() {
  local entry="$1"
  local action="$2"

  # Deduplicate in case of identical titles
  if [[ -n "${action_by_entry[$entry]+x}" ]]; then
    local n=2
    while [[ -n "${action_by_entry["$entry (#$n)"]+x}" ]]; do
      n=$((n+1))
    done
    entry="$entry (#$n)"
  fi

  entries+=("$entry")
  action_by_entry["$entry"]="$action"
}

# -------------------------
# Screens (monitors)
# -------------------------
# Use /screen:<name> (what most hyprland-share-picker-compatible scripts output) citeturn2view0
while IFS=$'\t' read -r name desc; do
  [[ -z "${name:-}" ]] && continue
  if [[ -n "${desc:-}" && "${desc:-}" != "null" ]]; then
    add_entry "Screen: ${name} — ${desc}" "[SELECTION]/screen:${name}"
  else
    add_entry "Screen: ${name}" "[SELECTION]/screen:${name}"
  fi
done < <(hyprctl monitors -j | jq -r '.[] | "\(.name)\t\(.description // "")"')

# -------------------------
# Windows (from XDPH env)
# -------------------------
windows_raw="${XDPH_WINDOW_SHARING_LIST:-}"
if [[ -n "$windows_raw" ]]; then
  # Parse XDPH_WINDOW_SHARING_LIST:
  # <idToken>[HC>]<class>[HT>]<title>[HE>]...
  # Some setups include <idToken> like: 94409289709312[HA>]1581183872
  # In that case, use the numeric handle after [HA>] as the actual window id.
  while IFS=$'\t' read -r idtoken wclass wtitle; do
    [[ -z "${idtoken:-}" ]] && continue
    [[ -z "${wtitle:-}" ]] && continue

    # Skip scratchpad and the picker itself
    if [[ "$wclass" == "kitty-scratchpad" || "$wtitle" == "kitty-scratchpad" ]]; then
      continue
    fi
    if [[ "$wclass" == "wofi" || "$wtitle" == "Share…" || "$wtitle" == "Share..." ]]; then
      continue
    fi

    # Normalize title whitespace
    wtitle="${wtitle//$'\n'/ }"
    wtitle="${wtitle//$'\t'/ }"

    wid="$idtoken"
    if [[ "$idtoken" == *"[HA>]"* ]]; then
      # everything after the last [HA>] is the handle
      wid="${idtoken##*\[HA>\]}"
    fi
    # Trim spaces
    wid="${wid#"${wid%%[![:space:]]*}"}"
    wid="${wid%"${wid##*[![:space:]]}"}"

    # Display class too (helps disambiguate browser apps)
    add_entry "Window: ${wtitle}  •  ${wclass}" "[SELECTION]/window:${wid}"
  done < <(
    awk -F'\\[HE>\\]' '
      {
        for (i=1; i<=NF; i++) {
          if ($i == "") continue;

          split($i, a, "\\[HC>\\]");
          id = a[1];

          split(a[2], b, "\\[HT>\\]");
          cls = b[1];
          title = b[2];

          if (id != "" && title != "")
            print id "\t" cls "\t" title;
        }
      }' <<< "$windows_raw"
  )
fi

# -------------------------
# Region (optional)
# -------------------------
if need slurp; then
  add_entry "Region: Select area…" "__REGION__"
fi

[[ "${#entries[@]}" -eq 0 ]] && exit 1

choice="$(
  printf '%s\n' "${entries[@]}" |
    wofi --dmenu --prompt "Share…" \
      --normal-window \
      --style "$STYLE" \
      --width 900 --height 520
)"

[[ -z "${choice:-}" ]] && exit 1

sel="${action_by_entry[$choice]:-}"
[[ -z "${sel:-}" ]] && exit 1

if [[ "$sel" == "__REGION__" ]]; then
  region="$(slurp -f '%o@%x,%y,%w,%h')" || exit 1
  [[ -n "${region:-}" ]] || exit 1
  echo "[SELECTION]/region:${region}"
else
  echo "$sel"
fi
