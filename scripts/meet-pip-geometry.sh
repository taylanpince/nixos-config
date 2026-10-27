#!/usr/bin/env bash
# Remember where the Meet picture-in-picture window was left. Brave opens a
# brand-new PiP window on every tab switch, so the meet-pip window rule's fixed
# move/size would win each time. While a PiP window is open we sample its
# geometry once a second (Hyprland emits no event for floating moves/resizes),
# and when a new one opens we put it back where the last one was. Pinned windows
# also follow the active workspace, so switching workspaces on the other LG tile
# drags the PiP across at the same monitor-relative offset; we move it back to
# where it was left.
set -u

sig="${HYPRLAND_INSTANCE_SIGNATURE:-}"
[ -n "$sig" ] || exit 0
sock="${XDG_RUNTIME_DIR}/hypr/${sig}/.socket2.sock"
state="${XDG_STATE_HOME:-$HOME/.local/state}/meet-pip-geometry"
title_re='^Meet - '
command -v socat >/dev/null 2>&1 || exit 0
mkdir -p "$(dirname "$state")"

pip=""      # address (0x...) of the PiP window being tracked
saved=""    # last geometry written, "x y w h"

# Only restore onto a monitor that still exists (dock unplugged, etc.).
on_screen() {
  hyprctl monitors -j | jq -e --argjson x "$1" --argjson y "$2" \
    'any(.[]; $x >= .x and $x < .x + .width and $y >= .y and $y < .y + .height)' >/dev/null
}

restore() {
  local addr="$1" x y w h
  sleep 0.1   # let the meet-pip rule (float/pin/move/size) land first
  # A Brave tab titled "Meet - ..." matches too; only the pinned float is PiP.
  hyprctl clients -j | jq -e --arg a "$addr" \
    'any(.[]; .address == $a and .floating and .pinned)' >/dev/null || return
  pip="$addr"
  [ -s "$state" ] || return
  read -r x y w h < "$state" || return
  on_screen "$x" "$y" || return
  hyprctl --batch "dispatch resizewindowpixel exact $w $h,address:$addr; dispatch movewindowpixel exact $x $y,address:$addr" >/dev/null
  saved="$x $y $w $h"
}

geometry() {
  hyprctl clients -j | jq -r --arg a "$pip" \
    '.[] | select(.address == $a and .floating and .pinned) | "\(.at[0]) \(.at[1]) \(.size[0]) \(.size[1])"'
}

sample() {
  local geo
  geo="$(geometry)"
  if [ -z "$geo" ]; then pip=""; return; fi
  [ "$geo" = "$saved" ] && return
  printf '%s\n' "$geo" > "$state"
  saved="$geo"
}

# Undo the workspace switch dragging the PiP onto another monitor. Runs before
# sample(), so the dragged position never overwrites the saved one.
reposition() {
  local geo x y
  [ -n "$pip" ] && [ -n "$saved" ] || return
  sleep 0.05
  geo="$(geometry)"
  [ -n "$geo" ] && [ "${geo% * *}" != "${saved% * *}" ] || return
  read -r x y _ <<< "$saved"
  on_screen "$x" "$y" && hyprctl dispatch movewindowpixel "exact $x $y,address:$pip" >/dev/null
}

socat -U - UNIX-CONNECT:"$sock" | while true; do
  if read -r -t 1 line; then
    case "$line" in
      openwindow\>\>*)
        IFS=, read -r addr _ _ title <<< "${line#openwindow>>}"
        [[ $title =~ $title_re ]] && restore "0x$addr" ;;
      windowtitlev2\>\>*)
        # PiP windows can open untitled and get the Meet title a moment later.
        IFS=, read -r addr title <<< "${line#windowtitlev2>>}"
        [ "0x$addr" != "$pip" ] && [[ $title =~ $title_re ]] && restore "0x$addr" ;;
      workspacev2\>\>*)
        reposition ;;
      closewindow\>\>*)
        [ "0x${line#closewindow>>}" = "$pip" ] && pip="" ;;
    esac
  elif [ $? -le 128 ]; then
    exit 0   # socket closed (Hyprland exited)
  fi
  [ -n "$pip" ] && sample
done
