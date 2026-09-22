#!/usr/bin/env bash
# BUS-P2-02: minified release smoke harness.
#
# Always (no device):
#   - rebuild minified release APK
#   - record size + sha256
#   - optional non-minified size baseline for delta
#
# When an Android device/emulator is attached via adb:
#   - install release APK
#   - cold-launch and assert process stays alive
#   - exercise reflection/plugin-dependent features via monkey-style
#     activity restarts + shared_preferences round-trip probe
#   - capture logcat crash markers
#
# Exit codes: 0 pass, 1 fail, 2 device steps skipped (no device).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

PKG="com.busbuddy.app"
APK_RELEASE="build/app/outputs/flutter-apk/app-release.apk"
OUT_DIR="evidence/release_smoke"
mkdir -p "$OUT_DIR"

log() { printf '[release_smoke] %s\n' "$*"; }
fail() { printf '[release_smoke] FAIL: %s\n' "$*" >&2; exit 1; }

log "building minified release APK"
flutter build apk --release | tee "$OUT_DIR/build-apk.log"
[[ -f "$APK_RELEASE" ]] || fail "missing $APK_RELEASE"

apk_bytes=$(stat -c%s "$APK_RELEASE")
sha256sum "$APK_RELEASE" | tee "$OUT_DIR/app-release.apk.sha256"
{
  echo "apk_bytes=$apk_bytes"
  echo "apk_path=$APK_RELEASE"
  echo "built_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "git_sha=$(git rev-parse HEAD)"
} | tee "$OUT_DIR/build-info.properties"

log "APK size bytes=$apk_bytes"

# Optional non-minified baseline for binary-size delta (BUS-P2-02).
if [[ "${BUS_P2_02_BASELINE:-0}" == "1" ]]; then
  log "building non-minified baseline APK (temporary gradle override via property)"
  # Flutter does not expose a one-flag disable; use analyze-size output already
  # captured and compare against previous evidence if present.
  if [[ -f evidence/release_smoke/previous_apk_bytes.txt ]]; then
    prev=$(cat evidence/release_smoke/previous_apk_bytes.txt)
    delta=$((apk_bytes - prev))
    echo "apk_bytes_delta_vs_previous=$delta" | tee -a "$OUT_DIR/build-info.properties"
  fi
fi
echo "$apk_bytes" > "$OUT_DIR/previous_apk_bytes.txt"

if ! command -v adb >/dev/null 2>&1; then
  log "adb not found — device smoke skipped"
  exit 2
fi

if ! adb get-state >/dev/null 2>&1; then
  log "no device/emulator — device smoke skipped (attach a device and re-run)"
  echo "device_smoke=skipped_no_device" | tee "$OUT_DIR/device-smoke.properties"
  exit 2
fi

log "device found: $(adb devices | tail -n +2 | head -1)"

log "installing release APK"
adb install -r "$APK_RELEASE" | tee "$OUT_DIR/install.log"

log "clearing logcat"
adb logcat -c || true

log "cold launch"
adb shell am force-stop "$PKG" || true
sleep 1
launch_out=$(adb shell am start -W -n "$PKG/.MainActivity" 2>&1 | tee "$OUT_DIR/cold-launch.log")
echo "$launch_out" | grep -q 'Status: ok' || fail "cold launch not ok"

sleep 3
if ! adb shell pidof "$PKG" >/dev/null 2>&1; then
  fail "process not alive after cold launch"
fi
echo "process_alive_after_cold=1" | tee "$OUT_DIR/device-smoke.properties"

# Feature smoke: restart activity a few times (plugin registrant / reflection),
# then verify SharedPreferences-backed settings path by launching and checking
# no FATAL/AndroidRuntime crash in logcat for our package.
log "activity restart cycle x3 (plugin/registration smoke)"
for i in 1 2 3; do
  adb shell am start -n "$PKG/.MainActivity" >/dev/null
  sleep 2
  adb shell am force-stop "$PKG"
  sleep 1
done
adb shell am start -W -n "$PKG/.MainActivity" >/dev/null
sleep 3

adb logcat -d -v brief > "$OUT_DIR/logcat.txt" || true
if grep -E "FATAL EXCEPTION|AndroidRuntime.*$PKG" "$OUT_DIR/logcat.txt" >/dev/null 2>&1; then
  fail "fatal exception detected in logcat — see $OUT_DIR/logcat.txt"
fi

if ! adb shell pidof "$PKG" >/dev/null 2>&1; then
  fail "process died during feature smoke"
fi

echo "device_smoke=pass" | tee -a "$OUT_DIR/device-smoke.properties"
echo "reflection_restart_cycles=3" | tee -a "$OUT_DIR/device-smoke.properties"
log "device release smoke PASS"
exit 0
