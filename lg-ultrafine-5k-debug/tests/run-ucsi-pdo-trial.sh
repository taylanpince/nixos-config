#!/usr/bin/env bash
# Offline test of actual patched functions; no module loading or device access.
set -euo pipefail
project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_file=${1:-"$project/evidence/engineering-source/linux-6.18.44/drivers/usb/typec/ucsi/ucsi.c"}
expected=3f5099110bce861814b9f9ca68f6fceb50b1d13999ea2d8b71f6fa84d8080fb4
actual=$(sha256sum -- "$source_file")
[[ ${actual%% *} == "$expected" ]] || { echo 'Unexpected source hash' >&2; exit 1; }
work=$(mktemp -d /tmp/lg-ucsi-pdo.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/drivers/usb/typec/ucsi"
cp -- "$source_file" "$work/drivers/usb/typec/ucsi/ucsi.c"
patch --batch --fuzz=0 -p1 -d "$work" < "$project/patches/0003-lab-ucsi-skip-partner-pdos.patch"
awk '/^static bool ucsi_lab_skip_partner_pdos\(/ || /^static int ucsi_get_pdos\(/ {copy=1} copy {print} copy && /^}/ {copy=0}' \
  "$work/drivers/usb/typec/ucsi/ucsi.c" > "$work/ucsi-pdo-under-test.inc"
"${CC:-gcc}" -std=c11 -Wall -Wextra -Werror -I "$work" \
  "$project/tests/ucsi-pdo-trial.c" -o "$work/test"
"$work/test"
