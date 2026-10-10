#!/usr/bin/env bash
# Read existing EC console and status; no console commands, reset or PD writes.
set -euo pipefail
(( EUID == 0 )) || { echo 'Run with sudo in a local terminal.' >&2; exit 1; }
tool=/nix/store/g0zppkc1w8f96rhns7vbm6gdm0xl8mmh-framework-tool-0.6.2/bin/framework_tool
[[ -x $tool ]] || { echo 'Pinned Framework tool is missing.' >&2; exit 1; }
project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
umask 077
out=$(mktemp -d "$project/evidence/$(date -u +%Y%m%dT%H%M%SZ)-ec-console-XXXXXX")
finish() {
  local rc=$?
  trap - EXIT
  if [[ ${SUDO_UID:-} =~ ^[0-9]+$ && ${SUDO_GID:-} =~ ^[0-9]+$ ]]; then
    chown -R -- "$SUDO_UID:$SUDO_GID" "$out"
  fi
  printf 'SAVED: %s\n' "$out"
  exit "$rc"
}
trap finish EXIT
trap 'exit 130' INT TERM HUP
query() {
  local name=$1 rc=0
  shift
  date --iso-8601=ns > "$out/$name.started-at.txt"
  timeout 20 "$tool" --driver cros-ec "$@" > "$out/$name.txt" 2>&1 || rc=$?
  printf '%s\t%d\n' "$name" "$rc" | tee -a "$out/exit-status.tsv"
}
# Console first: retain old events before later diagnostic host commands.
query console --console recent
query uptime --uptimeinfo
query pdports --pdports
query pd-info --pd-info
