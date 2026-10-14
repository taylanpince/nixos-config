#!/usr/bin/env bash
# Run only after explicit approval. Changes only temporary Thunderbolt logging.
# Collect events separately with trace.sh as the logged-in desktop user.
set -eu
duration=${1:-180}
[[ $duration =~ ^[0-9]+$ ]] && (( duration >= 1 && duration <= 300 )) || {
  echo 'Duration must be 1–300 seconds.' >&2
  exit 2
}
(( EUID == 0 )) || { echo 'Requires root and explicit owner approval.' >&2; exit 1; }
control=/proc/dynamic_debug/control
[[ -r $control && -w $control ]] || {
  echo 'Dynamic-debug control is unavailable; no changes made.' >&2
  exit 1
}
counts=$(awk '$2 ~ /^\[thunderbolt\]/ {total++; if ($3 ~ /p/) enabled++} END {print total+0, enabled+0}' "$control")
read -r total enabled <<< "$counts"
(( total > 0 )) || { echo 'No Thunderbolt callsites found; no changes made.' >&2; exit 1; }
(( enabled == 0 )) || {
  echo 'Existing Thunderbolt debug output is enabled; refusing to overwrite its state.' >&2
  exit 1
}
restore() {
  printf 'module thunderbolt -p\n' > "$control"
  if awk '$2 ~ /^\[thunderbolt\]/ && $3 ~ /p/ {found=1} END {exit found ? 1 : 0}' "$control"; then
    printf 'RESTORED: Thunderbolt printing disabled at %s\n' "$(date --iso-8601=seconds)"
  else
    echo 'RESTORE CHECK FAILED: manually disable module thunderbolt printing.' >&2
    return 1
  fi
}
trap restore EXIT
trap 'exit 130' INT TERM HUP
printf 'module thunderbolt +p\n' > "$control"
printf 'ENABLED: %s callsites; automatic restore in %s seconds; %s\n' "$total" "$duration" "$(date --iso-8601=seconds)"
deadline=$((SECONDS + duration))
while (( SECONDS < deadline )); do sleep 1; done
