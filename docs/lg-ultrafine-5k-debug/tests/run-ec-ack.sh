#!/usr/bin/env bash
# Reproduce false success in pinned public EC code, then test the RFC guard.
# Uses local source only; never accesses hardware or builds/loads firmware.
set -euo pipefail
project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_file=${1:-"$project/evidence/engineering-source/ec/cypd_ccg8.c"}
expected=c3f336b336df4422ff5efeaea7e3e535fec3d4269099ef8dab6d14ffc759698b
actual=$(sha256sum -- "$source_file")
[[ ${actual%% *} == "$expected" ]] || { echo 'Unexpected source hash' >&2; exit 1; }
work=$(mktemp -d /tmp/lg-ec-ack.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/zephyr/program/framework/src"
cp -- "$source_file" "$work/zephyr/program/framework/src/cypd_ccg8.c"

build_fixture() {
  awk '/^int cypd_write_reg8_wait_ack\(/ {copy=1} copy {print} copy && /^}/ {exit}' \
    "$work/zephyr/program/framework/src/cypd_ccg8.c" > "$work/cypd-ack-under-test.inc"
  test -s "$work/cypd-ack-under-test.inc"
  "${CC:-gcc}" -std=c11 -Wall -Wextra -Werror -Wno-unused-but-set-variable \
    -I "$work" "$project/tests/ec-ack-regression.c" -o "$work/fixture"
}

build_fixture
echo 'Original public source (expect exactly three false-success failures):'
baseline_status=0
"$work/fixture" > "$work/baseline.txt" || baseline_status=$?
cat "$work/baseline.txt"
[[ $baseline_status == 3 ]] || { echo 'Unexpected baseline result' >&2; exit 1; }
for case_name in 'captured IRQ=0, P1=0x0886' 'matching IRQ, async contract event' 'wrong-port ACK'; do
  grep -Fqx "FAIL: $case_name: result=0 expected=6 clear=0 expected=0" "$work/baseline.txt"
done

patch --batch --fuzz=0 -d "$work" -p1 < \
  "$project/patches/0002-rfc-ccg8-reject-unacknowledged-completion.patch"
build_fixture
echo 'RFC guard (expect all eight cases to pass):'
"$work/fixture"
echo 'Offline reproduction and guard checks passed; no firmware was built or changed.'
