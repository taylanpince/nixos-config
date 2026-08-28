#!/usr/bin/env bash
# Toggle-based meeting recorder.
#
# Records the default sink monitor (whatever Brave/Meet is playing) mixed
# with the default mic into a 16 kHz mono WAV under ~/Documents/transcripts,
# then runs whisper-cli in the background to produce a .txt alongside.
#
# State for the waybar indicator is written to $STATE_FILE and waybar is
# nudged with SIGRTMIN+8 so its custom/meeting-record module re-execs.

set -uo pipefail

STATE_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}/meeting-record"
STATE_FILE="$STATE_DIR/state.json"
PID_FILE="$STATE_DIR/ffmpeg.pid"
META_FILE="$STATE_DIR/current.env"
LOG_FILE="$STATE_DIR/last.log"

OUT_DIR="${MEETING_TRANSCRIPT_DIR:-$HOME/Documents/transcripts}"
MODEL="${WHISPER_MODEL:-/etc/whisper-models/ggml-medium.bin}"
LANG="${WHISPER_LANG:-en}"
WAYBAR_SIGNAL="${MEETING_WAYBAR_SIGNAL:-8}"

mkdir -p "$STATE_DIR" "$OUT_DIR"

write_state() {
  local cls="$1" tip="$2"
  printf '{"text":"●","class":"%s","tooltip":"%s","alt":"%s"}\n' \
    "$cls" "$tip" "$cls" > "$STATE_FILE"
  pkill -RTMIN+"$WAYBAR_SIGNAL" waybar 2>/dev/null || true
}

notify() {
  notify-send -a meeting-record "$@" 2>/dev/null || true
}

is_recording() {
  [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null
}

# A recording that was started but never transcribed — e.g. ffmpeg exited on
# its own because the capture device (Bluetooth headset, USB mic) disconnected
# mid-meeting, so stop never saw a live process. The WAV is on disk and valid;
# it just needs finalizing.
has_pending_capture() {
  [[ -f "$META_FILE" ]] || return 1
  local wav; wav="$(sed -n 's/^WAV=//p' "$META_FILE")"
  [[ -n "$wav" && -s "$wav" ]]
}

current_class() {
  [[ -f "$STATE_FILE" ]] || { echo stopped; return; }
  sed -n 's/.*"class":"\([^"]*\)".*/\1/p' "$STATE_FILE"
}

start_recording() {
  if is_recording; then
    notify "Already recording" "$(basename "$(source "$META_FILE"; echo "$WAV")")"
    return 0
  fi

  local ts base wav sink_monitor mic_source
  ts=$(date +%Y-%m-%d_%H-%M-%S)
  base="$OUT_DIR/$ts"
  wav="$base.wav"
  sink_monitor="$(pactl get-default-sink).monitor"
  mic_source="$(pactl get-default-source)"

  # Keep stereo so whisper --diarize can separate remote party (L, from the
  # sink monitor) from mic (R, you). Each side is downmixed to mono first
  # (webcam mics and Meet's monitor are 2ch) and then joined as L/R.
  # apad on both sides keeps the timeline rolling when the mic goes
  # SUSPENDED between utterances — otherwise the join stops at the shorter
  # input and drops the remote party's audio after that point.
  ffmpeg -hide_banner -loglevel warning -nostdin -y \
    -f pulse -i "$sink_monitor" \
    -f pulse -i "$mic_source" \
    -filter_complex "\
      [0:a]aresample=16000,pan=mono|c0=c0+c1,apad[l];\
      [1:a]aresample=16000,pan=mono|c0=c0+c1,apad[r];\
      [l][r]join=inputs=2:channel_layout=stereo[a]" \
    -map "[a]" -shortest -c:a pcm_s16le \
    "$wav" \
    </dev/null >"$LOG_FILE" 2>&1 &

  local ff_pid=$!
  echo "$ff_pid" > "$PID_FILE"

  cat > "$META_FILE" <<EOF
BASE=$base
WAV=$wav
STARTED=$(date +%s)
SINK_MONITOR=$sink_monitor
MIC_SOURCE=$mic_source
EOF

  # Give ffmpeg a moment to actually attach; if it died immediately, report.
  sleep 0.3
  if ! kill -0 "$ff_pid" 2>/dev/null; then
    rm -f "$PID_FILE"
    write_state stopped "meeting: failed to start"
    notify -u critical "Recording failed to start" "See $LOG_FILE"
    return 1
  fi

  write_state recording "meeting: recording → $(basename "$wav")"
  notify "Recording meeting" "$(basename "$wav")"
}

stop_recording() {
  local was_live=0
  if is_recording; then
    was_live=1
    local pid; pid=$(cat "$PID_FILE")
    # SIGINT lets ffmpeg finalize the WAV header.
    kill -INT "$pid" 2>/dev/null
    for _ in $(seq 1 50); do
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.1
    done
    kill -KILL "$pid" 2>/dev/null || true
  fi
  rm -f "$PID_FILE"

  # Nothing live and nothing left behind to finalize.
  if [[ "$was_live" -eq 0 ]] && ! has_pending_capture; then
    notify "Not recording" ""
    # Don't stomp on an in-flight transcription — its background job owns the
    # state and will reset it when done.
    [[ "$(current_class)" == "transcribing" ]] || write_state stopped "meeting: idle"
    return 0
  fi

  # Either we just stopped a live capture, or ffmpeg had already died and left
  # an untranscribed WAV. Either way, finalize it.
  # shellcheck disable=SC1090
  source "$META_FILE"
  # Consume the meta so a second stop/toggle won't re-transcribe the same WAV.
  rm -f "$META_FILE"

  finalize_and_transcribe "$BASE" "$WAV"
}

# Validate the WAV + model, then kick off transcription. Shared by
# stop_recording and the `transcribe` recovery subcommand.
finalize_and_transcribe() {
  local base="$1" wav="$2"

  if [[ ! -s "$wav" ]]; then
    write_state stopped "meeting: no audio"
    notify -u critical "Recording produced no audio" "See $LOG_FILE"
    return 1
  fi

  if [[ ! -f "$MODEL" ]]; then
    write_state stopped "meeting: model missing"
    notify -u critical "Whisper model missing" "$MODEL — WAV kept at $(basename "$wav")"
    return 1
  fi

  write_state transcribing "meeting: transcribing $(basename "$wav")"
  notify "Transcribing" "$(basename "$wav")"

  run_transcribe "$base" "$wav"
}

# Detach so the caller (hyprland bind) returns immediately. Set
# MEETING_TRANSCRIBE_SYNC=1 to run in the foreground (used by tests).
run_transcribe() {
  if [[ -n "${MEETING_TRANSCRIBE_SYNC:-}" ]]; then
    transcribe "$1" "$2"
  else
    ( transcribe "$1" "$2" ) &
    disown 2>/dev/null || true
  fi
}

# Recover an orphaned/existing recording by transcribing its WAV directly.
recover_wav() {
  local wav="${1:-}"
  if [[ -z "$wav" || ! -s "$wav" ]]; then
    echo "usage: $0 transcribe <recording.wav>  (must exist and be non-empty)" >&2
    return 1
  fi
  finalize_and_transcribe "${wav%.wav}" "$wav"
}

transcribe() {
  local base="$1" wav="$2"
  local log="$STATE_DIR/whisper.log"

  if whisper-cli \
      --model "$MODEL" \
      --language "$LANG" \
      --file "$wav" \
      --diarize \
      --output-txt \
      --output-file "$base" \
      --print-progress \
      >"$log" 2>&1; then
    # By construction L=sink monitor (remote), R=mic (you) — rename whisper's
    # generic `(speaker N)` labels so the transcript reads at a glance
    # instead of forcing you to remember the channel order.
    if [[ -f "$base.txt" ]]; then
      sed -i -e 's/(speaker 0)/[Them]/g' -e 's/(speaker 1)/[Me]/g' "$base.txt"
    fi
    write_state stopped "meeting: idle"
    notify "Transcript ready" "$(basename "$base").txt"
  else
    write_state stopped "meeting: transcription failed"
    notify -u critical "Transcription failed" "See $log — WAV kept at $(basename "$wav")"
  fi
}

case "${1:-toggle}" in
  start)  start_recording ;;
  stop)   stop_recording ;;
  toggle) if is_recording || has_pending_capture; then stop_recording; else start_recording; fi ;;
  transcribe|recover) recover_wav "${2:-}" ;;
  status)
    if [[ -f "$STATE_FILE" ]]; then cat "$STATE_FILE"
    else printf '{"text":"●","class":"stopped","tooltip":"meeting: idle","alt":"stopped"}\n'
    fi
    ;;
  *) echo "usage: $0 {start|stop|toggle|transcribe <wav>|status}" >&2; exit 1 ;;
esac
