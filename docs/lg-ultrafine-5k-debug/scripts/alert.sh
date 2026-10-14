#!/usr/bin/env bash
# Explicitly play through laptop speakers, without changing default routing/volume.
set -eu
project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
sound="$project/evidence/manual-attention-v2.wav"
if [[ ! -f $sound ]]; then
  ffmpeg -nostdin -hide_banner -loglevel error -f lavfi -i 'sine=frequency=880:duration=3' -af 'volume=2,afade=t=in:d=0.1,afade=t=out:st=2.7:d=0.3' -ac 2 -y "$sound"
fi
speaker=$(pactl list short sinks | awk '$2 ~ /Speaker/ {print $2; exit}')
[[ -n $speaker ]] || { echo 'No laptop speaker sink found.' >&2; exit 1; }
paplay --device="$speaker" --volume=49152 "$sound"
