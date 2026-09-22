#!/usr/bin/env bash
# Tests for gpu-clock.sh. Drives the script against a fake sysfs tree so every
# state can be produced on demand — a real wedged SMU only happens after a bad
# resume and can't be induced.
#
# Run: ./gpu-clock.test.sh

set -uo pipefail

SCRIPT="$(dirname "$(realpath "$0")")/gpu-clock.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASSED=0
FAILED=0

ok() { printf '  \033[32mok\033[0m   %s\n' "$1"; PASSED=$((PASSED + 1)); }
no() {
  printf '  \033[31mFAIL\033[0m %s\n       expected: %s\n       actual:   %s\n' "$1" "$2" "$3"
  FAILED=$((FAILED + 1))
}
assert_eq() { [[ "$2" == "$3" ]] && ok "$1" || no "$1" "$2" "$3"; }

# Build a fake DRM tree. The sclk table mimics this APU's min/current*/max
# layout; freq1_input is the independent hwmon reading the script trusts.
fake_gpu() { # <root> <min_mhz> <cur_mhz> <max_mhz> <busy_pct>
  local dev="$1/card0/device"
  mkdir -p "$dev/hwmon/hwmon5"
  printf '0: %sMhz \n1: %sMhz *\n2: %sMhz \n' "$2" "$3" "$4" >"$dev/pp_dpm_sclk"
  printf '%s\n' "$5" >"$dev/gpu_busy_percent"
  printf '%s\n' "$(( $3 * 1000000 ))" >"$dev/hwmon/hwmon5/freq1_input"
  printf '12000000\n' >"$dev/hwmon/hwmon5/power1_average"
  printf '55000\n' >"$dev/hwmon/hwmon5/temp1_input"
}

# Fresh sandbox per test: its own fake sysfs, its own state dir, its own
# notification log. Without this, trip counters leak between cases.
new_case() { # <name> -> sets ROOT, STATE, NOTIFYLOG
  CASE="$1"
  ROOT="$TMP/$CASE/drm"; STATE="$TMP/$CASE/state"; NOTIFYLOG="$TMP/$CASE/notify.log"
  mkdir -p "$ROOT" "$STATE"
  : >"$NOTIFYLOG"
  cat >"$TMP/$CASE/notify.sh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$NOTIFYLOG"
EOF
  chmod +x "$TMP/$CASE/notify.sh"
}

# One poll of the module.
poll() {
  GPU_DRM_ROOT="$ROOT" GPU_STATE_DIR="$STATE" GPU_NOTIFY_CMD="$TMP/$CASE/notify.sh" \
    bash "$SCRIPT"
}
field() { poll | jq -r ".$1"; }
notify_count() { wc -l <"$NOTIFYLOG" | tr -d ' '; }

echo "gpu-clock.sh"

# --- no false positives on healthy hardware ------------------------------
# The critical one: at genuine idle the GPU correctly sits at its floor clock.
# A naive "clock == 600" check would scream here on every healthy machine.
new_case idle_at_floor
fake_gpu "$ROOT" 600 600 2900 4
assert_eq "silent at genuine idle (floor clock, no load)" "ok" "$(field class)"
# Asserted as one string so a missing script (empty output) can't pass this.
assert_eq "  renders nothing at idle" "ok|" "$(poll | jq -r '.class + "|" + .text')"

new_case healthy_load
fake_gpu "$ROOT" 600 2900 2900 95
assert_eq "silent under load when clock ramps" "ok" "$(field class)"

new_case partial_ramp
fake_gpu "$ROOT" 600 1664 2900 60
assert_eq "silent at a healthy mid-range clock" "ok" "$(field class)"

# --- the fault, and that it needs to be sustained ------------------------
new_case trip
fake_gpu "$ROOT" 600 601 2900 90
assert_eq "one bad poll does not trip" "ok" "$(field class)"
assert_eq "two bad polls do not trip" "ok" "$(field class)"
assert_eq "third consecutive bad poll trips" "wedged" "$(field class)"
[[ -n "$(field text)" ]] && ok "  wedged state renders text" || no "  wedged state renders text" "non-empty" ""
[[ "$(field text)" == *601* ]] && ok "  text reports the measured clock" || no "  text reports the measured clock" "*601*" "$(field text)"

# --- notification fires once per trip, not once per poll -----------------
new_case notify_once
fake_gpu "$ROOT" 600 601 2900 90
poll >/dev/null; poll >/dev/null; poll >/dev/null
assert_eq "notifies on trip" "1" "$(notify_count)"
poll >/dev/null; poll >/dev/null
assert_eq "does not re-notify while still wedged" "1" "$(notify_count)"

# --- recovery clears the fault and re-arms -------------------------------
new_case recovery
fake_gpu "$ROOT" 600 601 2900 90
poll >/dev/null; poll >/dev/null; poll >/dev/null
assert_eq "wedged before recovery" "wedged" "$(field class)"
fake_gpu "$ROOT" 600 2900 2900 90
assert_eq "clears as soon as the clock rises" "ok" "$(field class)"
assert_eq "  notification count unchanged by recovery" "1" "$(notify_count)"
fake_gpu "$ROOT" 600 601 2900 90
poll >/dev/null; poll >/dev/null
assert_eq "counter reset by recovery (needs 3 again)" "wedged" "$(field class)"
assert_eq "  re-arms and notifies on the next trip" "2" "$(notify_count)"

# --- a brief burst must not trip -----------------------------------------
new_case burst
fake_gpu "$ROOT" 600 601 2900 90
poll >/dev/null; poll >/dev/null
fake_gpu "$ROOT" 600 2900 2900 95
poll >/dev/null
fake_gpu "$ROOT" 600 601 2900 90
assert_eq "interrupted run of bad polls restarts the count" "ok" "$(field class)"

# --- load without a stuck clock, and a stuck clock without load ----------
new_case floor_but_lightly_loaded
fake_gpu "$ROOT" 600 601 2900 20
poll >/dev/null; poll >/dev/null
assert_eq "floor clock at low load is not a fault" "ok" "$(field class)"

# --- never break the bar -------------------------------------------------
new_case no_amdgpu
assert_eq "empty JSON when no amdgpu card is present" "ok" "$(field class)"
poll >/dev/null 2>&1
assert_eq "  exits 0 with no card" "0" "$?"
[[ -n "$(poll)" ]] && ok "  still emits a JSON line" || no "  still emits a JSON line" "non-empty" ""

new_case unreadable_sysfs
mkdir -p "$ROOT/card0/device"
printf 'garbage\n' >"$ROOT/card0/device/pp_dpm_sclk"
assert_eq "malformed sysfs degrades to ok, not a crash" "ok" "$(field class)"

echo
if [[ $FAILED -eq 0 ]]; then
  printf '\033[32m%d passed\033[0m\n' "$PASSED"
else
  printf '\033[31m%d failed\033[0m, %d passed\n' "$FAILED" "$PASSED"
fi
exit $(( FAILED > 0 ))
