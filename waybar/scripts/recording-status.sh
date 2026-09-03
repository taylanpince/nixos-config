#!/usr/bin/env bash
# Combined Waybar recording indicator: merges voxtype + meeting-record into a
# single dot. Colour by priority:
#   recording (red) > transcribing (yellow) > idle (dim)
#
# Driven by Waybar's `interval` (polls both sources) plus `signal` 8, which
# meeting-record.sh already raises on state changes for an instant update.
# voxtype has no signal hook, so the interval poll covers it (flips within ~1s).

set -uo pipefail

MR_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}/meeting-record"
MR_STATE="$MR_DIR/state.json"
# meeting-record.sh runs whisper with --print-progress into this log.
WHISPER_LOG="$MR_DIR/whisper.log"

# voxtype: one-shot JSON status → class is idle|recording|transcribing.
# Empty (→ idle) if the daemon isn't running.
vox_class="$(voxtype status --format json 2>/dev/null | jq -r '.class // empty' 2>/dev/null)"
vox_class="${vox_class:-idle}"

# meeting-record: class written to its state file → stopped|recording|transcribing.
mr_class=""
if [[ -f "$MR_STATE" ]]; then
  mr_class="$(jq -r '.class // empty' "$MR_STATE" 2>/dev/null)"
fi
mr_class="${mr_class:-stopped}"

# Merge by priority. Substring match is safe: "transcribing" contains no
# "record", and recording always wins over transcribing which wins over idle.
case "$vox_class $mr_class" in
  *record*)    cls="recording" ;;
  *transcrib*) cls="transcribing" ;;
  *)           cls="idle" ;;
esac

# While a meeting is transcribing, surface whisper's progress % on hover.
# Round to 5% buckets: the module's output must stay byte-identical between
# updates or waybar redraws the bar on every `interval` tick, and each redraw
# dismisses any open tooltip bar-wide. Live 1% updates changed the output every
# second, so tooltips vanished during transcription; 5% steps change it ~20x
# total. (voxtype's own transcription has no progress log, so it just reads
# "transcribing".)
mr_label="$mr_class"
if [[ "$mr_class" == "transcribing" && -f "$WHISPER_LOG" ]]; then
  n="$(grep -oE 'progress = *[0-9]+%' "$WHISPER_LOG" 2>/dev/null | grep -oE '[0-9]+' | tail -n1)"
  [[ -n "$n" ]] && mr_label="transcribing ($(( n / 5 * 5 ))%)"
fi

printf '{"text":"●","class":"%s","alt":"%s","tooltip":"voxtype: %s · meeting: %s"}\n' \
  "$cls" "$cls" "$vox_class" "$mr_label"
