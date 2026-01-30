#!/usr/bin/env bash
set -euo pipefail

prompt=$(wofi --dmenu --prompt "AI → shell command")
[ -z "$prompt" ] && exit 0

notify-send -t 1000 "AI" "Generating command…"

out=$(
  aichat --no-stream \
    "$prompt. Return exactly one shell command. Do not include Markdown, code fences, backticks, comments, explanations, or prompts."
)

printf '%s' "$out" | wl-copy

notify-send -t 1500 "AI" "Command copied to clipboard"

