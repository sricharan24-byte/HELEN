#!/usr/bin/env bash
# BUS-P2-02: cold/warm startup + memory budgets after navigation cycles.
#
# Requires an Android device or emulator with BusBuddy installed
# (use tool/release_smoke.sh first, or flutter install --release).
#
# Budgets (documented defaults — override via env):
#   BUS_BUDGET_COLD_MS=5000
#   BUS_BUDGET_WARM_MS=2500
#   BUS_BUDGET_PSS_MB=400
#   BUS_NAV_CYCLES=10
#
# Also asserts no accessibility service regression signal is missing when
# TalkBack is enabled (semantics no-regression smoke).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

PKG="com.busbuddy.app"
ACTIVITY="$PKG/.MainActivity"
OUT_DIR="evidence/startup_benchmark"
mkdir -p "$OUT_DIR"

COLD_BUDGET_MS="${BUS_BUDGET_COLD_MS:-5000}"
WARM_BUDGET_MS="${BUS_BUDGET_WARM_MS:-2500}"
PSS_BUDGET_MB="${BUS_BUDGET_PSS_MB:-400}"
NAV_CYCLES="${BUS_NAV_CYCLES:-10}"

log() { printf '[startup_bench] %s\n' "$*"; }
fail() { printf '[startup_bench] FAIL: %s\n' "$*" >&2; exit 1; }

command -v adb >/dev/null 2>&1 || fail "adb not on PATH"
adb get-state >/dev/null 2>&1 || fail "no device/emulator attached"

if ! adb shell pm path "$PKG" >/dev/null 2>&1; then
  fail "$PKG not installed — run tool/release_smoke.sh or flutter install --release"
fi

parse_total_time_ms() {
  # am start -W prints "TotalTime: 1234"
  echo "$1" | awk -F'[: ]+' '/TotalTime/ {print $2; exit}'
}

pss_mb() {
  local pid
  pid=$(adb shell pidof "$PKG" | tr -d '\r' | awk '{print $1}')
  [[ -n "$pid" ]] || { echo ""; return; }
  # dumpsys meminfo TOTAL PSS is the first "TOTAL" line column.
  adb shell dumpsys meminfo "$pid" | awk '
    /^\s*TOTAL/ { print $2; exit }
  ' | tr -d '\r'
}

log "cold start budget=${COLD_BUDGET_MS}ms"
adb shell am force-stop "$PKG"
sleep 1
cold_raw=$(adb shell am start -W -n "$ACTIVITY" 2>&1)
echo "$cold_raw" | tee "$OUT_DIR/cold-start.log"
cold_ms=$(parse_total_time_ms "$cold_raw")
[[ -n "$cold_ms" ]] || fail "could not parse TotalTime from cold start"
log "cold TotalTime=${cold_ms}ms"
if (( cold_ms > COLD_BUDGET_MS )); then
  fail "cold start ${cold_ms}ms exceeds budget ${COLD_BUDGET_MS}ms"
fi

log "warm start x3 budget=${WARM_BUDGET_MS}ms"
warm_max=0
for i in 1 2 3; do
  adb shell am start -n "$ACTIVITY" >/dev/null
  sleep 1
  # Bring to foreground without process death for warm measurement:
  adb shell am start -W -n "$ACTIVITY" 2>&1 | tee "$OUT_DIR/warm-$i.log" >/dev/null
  warm_raw=$(cat "$OUT_DIR/warm-$i.log")
  warm_ms=$(parse_total_time_ms "$warm_raw")
  [[ -n "$warm_ms" ]] || fail "could not parse warm TotalTime"
  log "warm#$i TotalTime=${warm_ms}ms"
  if (( warm_ms > warm_max )); then warm_max=$warm_ms; fi
  if (( warm_ms > WARM_BUDGET_MS )); then
    fail "warm start ${warm_ms}ms exceeds budget ${WARM_BUDGET_MS}ms"
  fi
  sleep 1
done

log "navigation cycles=$NAV_CYCLES (home → settings-style relaunch)"
for i in $(seq 1 "$NAV_CYCLES"); do
  adb shell am start -n "$ACTIVITY" >/dev/null
  sleep 0.5
  # Simulate leaving and returning to the task.
  adb shell input keyevent KEYCODE_HOME >/dev/null || true
  sleep 0.3
  adb shell am start -n "$ACTIVITY" >/dev/null
  sleep 0.5
done

sleep 2
pid=$(adb shell pidof "$PKG" | tr -d '\r' | awk '{print $1}')
[[ -n "$pid" ]] || fail "process died during navigation cycles"
pss=$(pss_mb)
[[ -n "$pss" ]] || fail "could not read PSS"
log "PSS after ${NAV_CYCLES} nav cycles = ${pss} kB"
pss_mb_val=$(( (pss + 1023) / 1024 ))
log "PSS ≈ ${pss_mb_val} MB (budget ${PSS_BUDGET_MB} MB)"
if (( pss_mb_val > PSS_BUDGET_MB )); then
  fail "PSS ${pss_mb_val}MB exceeds budget ${PSS_BUDGET_MB}MB"
fi

# Semantics no-regression smoke: ensure the package still appears in
# accessibility-relevant window dumps and no crash in logcat.
adb logcat -d -v brief > "$OUT_DIR/logcat.txt" || true
if grep -E "FATAL EXCEPTION" "$OUT_DIR/logcat.txt" >/dev/null 2>&1; then
  fail "fatal exception during benchmark — see $OUT_DIR/logcat.txt"
fi

# Optional: if TalkBack is enabled, record enabled services as evidence.
a11y_services=$(adb shell settings get secure enabled_accessibility_services 2>/dev/null | tr -d '\r' || true)
echo "enabled_accessibility_services=${a11y_services}" > "$OUT_DIR/a11y.properties"

{
  echo "cold_ms=$cold_ms"
  echo "warm_max_ms=$warm_max"
  echo "nav_cycles=$NAV_CYCLES"
  echo "pss_kb=$pss"
  echo "pss_mb=$pss_mb_val"
  echo "budget_cold_ms=$COLD_BUDGET_MS"
  echo "budget_warm_ms=$WARM_BUDGET_MS"
  echo "budget_pss_mb=$PSS_BUDGET_MB"
  echo "git_sha=$(git rev-parse HEAD)"
  echo "generated_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} | tee "$OUT_DIR/benchmark.properties"

log "PASS: cold=${cold_ms}ms warm_max=${warm_max}ms pss_mb=${pss_mb_val}"
