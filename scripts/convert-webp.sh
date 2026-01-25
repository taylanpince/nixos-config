#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./to-webp.sh [width] [files...]
# Examples:
#   ./to-webp.sh                 # width=1600, converts common images in current dir
#   ./to-webp.sh 1200            # width=1200, converts common images in current dir
#   ./to-webp.sh 1600 *.jpg      # width=1600, converts only matched files
#   ./to-webp.sh 2000 img.png    # single file

width="${1:-1600}"

# If first arg is numeric, shift it off; remaining args are file globs / names.
if [[ "${1:-}" =~ ^[0-9]+$ ]]; then
  shift
fi

# If no files provided, use a sensible default set in the current directory.
if [[ $# -eq 0 ]]; then
  shopt -s nullglob nocaseglob
  set -- *.jpg *.jpeg *.png *.tif *.tiff *.webp
fi

# Basic validation
if ! command -v magick >/dev/null 2>&1; then
  echo "Error: ImageMagick 'magick' not found. Install imagemagick." >&2
  exit 1
fi

for f in "$@"; do
  [[ -f "$f" ]] || { echo "Skipping (not a file): $f" >&2; continue; }

  base="${f%.*}"
  out="${base}.${width}.webp"

  # -auto-orient: respects EXIF rotation
  # -resize WxW>: only shrinks if larger than target
  # -strip: removes metadata
  # -quality 82: good default for photos; adjust if you want
  magick "$f" \
    -auto-orient \
    -resize "${width}x${width}>" \
    -strip \
    -quality 82 \
    "$out"

  echo "Wrote: $out"
done

