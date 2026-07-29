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

  # amix with duration=longest keeps recording as long as either input is
  # producing samples — the mic source can go SUSPENDED between utterances,
  # and the monitor keeps the timeline flowing.
  ffmpeg -hide_banner -loglevel warning -nostdin -y \
    -f pulse -i "$sink_monitor" \
    -f pulse -i "$mic_source" \
    -filter_complex "[0:a][1:a]amix=inputs=2:duration=longest:dropout_transition=0,aresample=16000,pan=mono|c0=c0" \
    -c:a pcm_s16le \
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
  if ! is_recording; then
    notify "Not recording" ""
    write_state stopped "meeting: idle"
    return 0
  fi

  local pid; pid=$(cat "$PID_FILE")
  # SIGINT lets ffmpeg finalize the WAV header.
  kill -INT "$pid" 2>/dev/null
  for _ in $(seq 1 50); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.1
  done
  kill -KILL "$pid" 2>/dev/null || true
  rm -f "$PID_FILE"

  # shellcheck disable=SC1090
  source "$META_FILE"

  if [[ ! -s "$WAV" ]]; then
    write_state stopped "meeting: no audio"
    notify -u critical "Recording produced no audio" "See $LOG_FILE"
    return 1
  fi

  if [[ ! -f "$MODEL" ]]; then
    write_state stopped "meeting: model missing"
    notify -u critical "Whisper model missing" "$MODEL — WAV kept at $(basename "$WAV")"
    return 1
  fi

  write_state transcribing "meeting: transcribing $(basename "$WAV")"
  notify "Transcribing" "$(basename "$WAV")"

  # Detach so the caller (hyprland bind) returns immediately.
  ( transcribe "$BASE" "$WAV" ) &
  disown 2>/dev/null || true
}

transcribe() {
  local base="$1" wav="$2"
  local log="$STATE_DIR/whisper.log"

  if whisper-cli \
      --model "$MODEL" \
      --language "$LANG" \
      --file "$wav" \
      --output-txt \
      --output-file "$base" \
      --print-progress \
      >"$log" 2>&1; then
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
  toggle) if is_recording; then stop_recording; else start_recording; fi ;;
  status)
    if [[ -f "$STATE_FILE" ]]; then cat "$STATE_FILE"
    else printf '{"text":"●","class":"stopped","tooltip":"meeting: idle","alt":"stopped"}\n'
    fi
    ;;
  *) echo "usage: $0 {start|stop|toggle|status}" >&2; exit 1 ;;
esac
