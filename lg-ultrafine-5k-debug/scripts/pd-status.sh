#!/usr/bin/env bash
# Read-only Framework firmware and PD queries via the existing cros-ec driver.
# No reset, enable/disable, write, flash, or raw host-command flags are used.
set -u
tool=/nix/store/g0zppkc1w8f96rhns7vbm6gdm0xl8mmh-framework-tool-0.6.2/bin/framework_tool
[[ -x $tool ]] || { echo 'Pinned Framework tool is missing.' >&2; exit 1; }
for query in versions pdports pd-info; do
  printf '\nQuery: --driver cros-ec --%s at %s\n' "$query" "$(date --iso-8601=seconds)"
  timeout 20 "$tool" --driver cros-ec "--$query" 2>&1
  printf 'Query exit status: %s\n' "$?"
done
