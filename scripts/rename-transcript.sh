#!/usr/bin/env bash
#
# rename-transcript.sh — rename an auto-recorded transcript.
#
# Lists unnamed transcripts (timestamp-named .txt files) in ~/Documents/transcripts,
# lets you pick one with fzf, prompts for a title, renames it to <Title>-<YYYY-MM-DD>.txt
# (date taken from the recording's own timestamp), optionally moves it to the 1-1s folder,
# and deletes the matching .wav after a single confirmation. Ctrl-D in the list deletes
# the highlighted transcript instead. Loops back to the list until none are left or you
# quit with Esc.

set -euo pipefail

DIR="$HOME/Documents/transcripts"
ONE_ON_ONE_DIR="$DIR/1-1s"

# Unnamed transcripts look like: 2026-09-03_17-36-19.txt
pattern='^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}\.txt$'

# Preview pane shows the opening lines of the highlighted transcript.
preview_cmd="cd $(printf '%q' "$DIR") && echo \"\$(wc -l < {}) lines\" && echo && head -n 30 {}"

shopt -s nullglob

# --- Delete ---------------------------------------------------------------------
delete_transcript() {
  local selected="$1"
  local src_txt="$DIR/$selected"
  local src_wav="$DIR/${selected%.txt}.wav"

  read -r -p "Delete $selected? [y/N] " go
  if [[ ! "$go" =~ ^[Yy] ]]; then
    echo "Kept."
    return
  fi

  local delete_wav=""
  if [[ -f "$src_wav" ]]; then
    read -r -p "Delete the audio too (${selected%.txt}.wav, $(du -h "$src_wav" | cut -f1))? [y/N] " delete_wav
  fi

  rm -f "$src_txt"
  echo "Deleted: $selected"
  if [[ "$delete_wav" =~ ^[Yy] ]]; then
    rm -f "$src_wav"
    echo "Deleted: ${selected%.txt}.wav"
  fi
}

# --- Rename ---------------------------------------------------------------------
rename_transcript() {
  local selected="$1"

  # Date is the first 10 chars of the filename (YYYY-MM-DD).
  local date_part="${selected:0:10}"

  local title
  read -r -p "Title for this transcript: " title
  if [[ -z "${title// /}" ]]; then
    echo "No title entered. Skipping."
    return
  fi
  # Trim leading/trailing whitespace, then turn spaces into hyphens.
  title="${title#"${title%%[![:space:]]*}"}"
  title="${title%"${title##*[![:space:]]}"}"
  title="$(printf '%s' "$title" | tr -s '[:space:]' '-')"

  local new_name="${title}-${date_part}.txt"

  local is_one dest_dir dest_display
  read -r -p "Is this a 1:1? [y/N] " is_one
  if [[ "$is_one" =~ ^[Yy] ]]; then
    dest_dir="$ONE_ON_ONE_DIR"
    dest_display="1-1s/$new_name"
  else
    dest_dir="$DIR"
    dest_display="$new_name"
  fi
  mkdir -p "$dest_dir"

  local dest_path="$dest_dir/$new_name"
  if [[ -e "$dest_path" ]]; then
    echo "Error: $dest_display already exists. Skipping."
    return
  fi

  local src_txt="$DIR/$selected"
  local src_wav="$DIR/${selected%.txt}.wav"

  echo
  echo "Rename: $selected -> $dest_display"
  if [[ -f "$src_wav" ]]; then
    echo "Delete: ${selected%.txt}.wav ($(du -h "$src_wav" | cut -f1))"
  fi
  local go
  read -r -p "Proceed? [y/N] " go
  if [[ ! "$go" =~ ^[Yy] ]]; then
    echo "Cancelled."
    return
  fi

  mv -n "$src_txt" "$dest_path"
  [[ -f "$src_wav" ]] && rm -f "$src_wav"

  echo "Done: $dest_display"
}

# --- Main loop ------------------------------------------------------------------
while true; do
  candidates=()
  for f in "$DIR"/*.txt; do
    base="$(basename "$f")"
    if [[ "$base" =~ $pattern ]]; then
      candidates+=("$base")
    fi
  done

  if [[ ${#candidates[@]} -eq 0 ]]; then
    echo "No unnamed transcripts left in $DIR"
    exit 0
  fi

  # --expect makes fzf print the key pressed (empty for Enter) above the selection.
  out="$(printf '%s\n' "${candidates[@]}" \
    | fzf --prompt="Pick a transcript: " --height=60% --reverse --no-multi \
          --header="Enter: rename · Ctrl-D: delete · Esc: quit" \
          --expect=ctrl-d \
          --preview="$preview_cmd" --preview-window='down,60%,wrap,border-top')" || {
    echo "Bye."
    exit 0
  }
  key="$(sed -n 1p <<<"$out")"
  selected="$(sed -n 2p <<<"$out")"
  [[ -n "$selected" ]] || { echo "Bye."; exit 0; }

  if [[ "$key" == "ctrl-d" ]]; then
    delete_transcript "$selected"
  else
    rename_transcript "$selected"
  fi
  echo
done
