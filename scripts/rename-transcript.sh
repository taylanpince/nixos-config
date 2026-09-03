#!/usr/bin/env bash
#
# rename-transcript.sh — rename an auto-recorded transcript.
#
# Lists unnamed transcripts (timestamp-named .txt files) in ~/Documents/transcripts,
# lets you pick one with fzf, prompts for a title, renames it to <Title>-<YYYY-MM-DD>.txt
# (date taken from the recording's own timestamp), optionally moves it to the 1-1s folder,
# and deletes the matching .wav after a single confirmation.

set -euo pipefail

DIR="$HOME/Documents/transcripts"
ONE_ON_ONE_DIR="$DIR/1-1s"

# Unnamed transcripts look like: 2026-09-03_17-36-19.txt
pattern='^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}\.txt$'

# --- Collect unnamed transcripts ------------------------------------------------
shopt -s nullglob
candidates=()
for f in "$DIR"/*.txt; do
  base="$(basename "$f")"
  if [[ "$base" =~ $pattern ]]; then
    candidates+=("$base")
  fi
done

if [[ ${#candidates[@]} -eq 0 ]]; then
  echo "No unnamed transcripts in $DIR"
  exit 0
fi

# --- Pick one -------------------------------------------------------------------
selected="$(printf '%s\n' "${candidates[@]}" \
  | fzf --prompt="Pick a transcript: " --height=40% --reverse --no-multi)" || {
  echo "Cancelled."
  exit 0
}
[[ -n "$selected" ]] || { echo "Cancelled."; exit 0; }

# Date is the first 10 chars of the filename (YYYY-MM-DD).
date_part="${selected:0:10}"

# --- Title ----------------------------------------------------------------------
read -r -p "Title for this transcript: " title
if [[ -z "${title// /}" ]]; then
  echo "No title entered. Aborting."
  exit 1
fi
# Trim leading/trailing whitespace, then turn spaces into hyphens.
title="${title#"${title%%[![:space:]]*}"}"
title="${title%"${title##*[![:space:]]}"}"
title="$(printf '%s' "$title" | tr -s '[:space:]' '-')"

new_name="${title}-${date_part}.txt"

# --- 1:1? -----------------------------------------------------------------------
read -r -p "Is this a 1:1? [y/N] " is_one
if [[ "$is_one" =~ ^[Yy] ]]; then
  dest_dir="$ONE_ON_ONE_DIR"
  dest_display="1-1s/$new_name"
else
  dest_dir="$DIR"
  dest_display="$new_name"
fi
mkdir -p "$dest_dir"

dest_path="$dest_dir/$new_name"
if [[ -e "$dest_path" ]]; then
  echo "Error: $dest_display already exists. Aborting."
  exit 1
fi

# --- Confirm & apply ------------------------------------------------------------
src_txt="$DIR/$selected"
src_wav="$DIR/${selected%.txt}.wav"

echo
echo "Rename: $selected -> $dest_display"
if [[ -f "$src_wav" ]]; then
  echo "Delete: ${selected%.txt}.wav ($(du -h "$src_wav" | cut -f1))"
fi
read -r -p "Proceed? [y/N] " go
if [[ ! "$go" =~ ^[Yy] ]]; then
  echo "Cancelled."
  exit 0
fi

mv -n "$src_txt" "$dest_path"
[[ -f "$src_wav" ]] && rm -f "$src_wav"

echo "Done: $dest_display"
