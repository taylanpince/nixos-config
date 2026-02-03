#!/usr/bin/env bash

# Store entries in temp file to preserve exact content
tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

cliphist list | head -n 200 > "$tmpfile"

# Check if we have entries
if [ ! -s "$tmpfile" ]; then
    exit 0
fi

# Show only content (no IDs) in wofi
selected=$(cut -f2- "$tmpfile" | \
    wofi --dmenu --normal-window --prompt "Clipboard" \
        --style ~/.config/wofi/style.css \
        --conf ~/.config/wofi/config \
        --width 900 --height 600)

# Exit if nothing selected
if [ -z "$selected" ]; then
    exit 0
fi

# Find matching line by comparing content after the tab
while IFS= read -r line; do
    content="${line#*	}"
    if [ "$content" = "$selected" ]; then
        echo "$line" | cliphist decode | wl-copy
        exit 0
    fi
done < "$tmpfile"
