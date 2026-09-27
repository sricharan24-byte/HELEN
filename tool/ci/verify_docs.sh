#!/usr/bin/env bash
# BUS-P2-03: fail documentation / public-claim drift when named files are
# absent or ADR/release claims lack the supporting paths CI depends on.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

fail=0
note() { printf 'OK  %s\n' "$1"; }
err() { printf 'FAIL %s\n' "$1" >&2; fail=1; }

required_files=(
  README.md
  progress.md
  AGENTS.md
  docs/adr/ADR-001-phase1-domain-and-a11y-contracts.md
  docs/adr/ADR-002-phase2-accessibility-and-safety-architecture.md
  docs/adr/ADR-003-production-readiness-and-audit-resolution.md
  docs/adr/ADR-004-android-native-voice-io.md
  docs/audit/gpt6_astra_feedback_phase2.txt
  docs/audit/gpt6_astra_paper.txt
  .github/workflows/ci.yml
  tool/ci/verify_docs.sh
  tool/release_smoke.sh
  tool/startup_memory_benchmark.sh
  test/platform/android_configuration_test.dart
  test/platform/permission_flow_test.dart
  test/platform/docs_verification_test.dart
  android/app/src/main/AndroidManifest.xml
  android/app/proguard-rules.pro
  android/app/build.gradle.kts
  analysis_options.yaml
  lib/core/tokens/app_semantic_colors.dart
  lib/core/tokens/app_spacing.dart
  lib/core/a11y/enlarging_text_scaler.dart
)

for f in "${required_files[@]}"; do
  if [[ -f "$f" ]]; then
    note "$f"
  else
    err "missing required file: $f"
  fi
done

# README must not claim a missing ADR path.
if grep -q 'ADR-002' README.md; then
  if [[ -f docs/adr/ADR-002-phase2-accessibility-and-safety-architecture.md ]]; then
    note "README ADR-002 reference resolves"
  else
    err "README references ADR-002 but file is absent"
  fi
fi

# P2 release configuration claims must be present in gradle (BUS-P2-02).
gradle=android/app/build.gradle.kts
if grep -q 'isMinifyEnabled = true' "$gradle" && grep -q 'isShrinkResources = true' "$gradle"; then
  note "release minify+shrink flags present"
else
  err "release build missing minify/shrink flags"
fi

# BUS-P2-01: the main manifest must declare exactly the audited permission set —
# no more, no less. Match only real <uses-permission> tags (not comments that
# mention removed permissions as rationale).
#   INTERNET              — OSM tiles, OSRM routing, Gemini Live WebSocket
#   RECORD_AUDIO          — AudioRecord capture streamed to the live session
#                           (ADR-004); requested just-in-time behind an announced
#                           rationale, with a text-only denial fallback
#   MODIFY_AUDIO_SETTINGS — normal level; keeps the voice-communication route so
#                           hardware echo cancellation suppresses self-listen
# Adding a permission here is a deliberate contract change, not a convenience:
# update ADR-004, the manifest rationale comment, and
# test/platform/docs_verification_test.dart in the same change.
manifest=android/app/src/main/AndroidManifest.xml
expected_perms=$'android.permission.INTERNET\nandroid.permission.MODIFY_AUDIO_SETTINGS\nandroid.permission.RECORD_AUDIO'
declared_perms="$(grep -oE 'android:name="android\.permission\.[A-Z_]+"' "$manifest" \
  | sed 's/android:name="//;s/"//' | sort -u || true)"
if [[ "$declared_perms" == "$expected_perms" ]]; then
  note "manifest permission minimization holds (audited set: INTERNET, RECORD_AUDIO, MODIFY_AUDIO_SETTINGS)"
else
  err "manifest permission set drifted from the BUS-P2-01/ADR-004 contract: got [$declared_perms]"
fi

# The dangerous permission must stay behind a just-in-time runtime request with
# an accessible denial fallback (BUS-P0-01 privacy / BUS-P1-08 honesty).
channel=android/app/src/main/kotlin/com/busbuddy/app/BusBuddyVoiceChannel.kt
if [[ -f "$channel" ]] && grep -q 'Manifest.permission.RECORD_AUDIO' "$channel" \
  && grep -q 'AudioRecord' "$channel"; then
  note "RECORD_AUDIO is requested at runtime by a real capture capability"
else
  err "RECORD_AUDIO declared without a runtime request and AudioRecord consumer"
fi

# The Dart-side contract check must agree with the shell gate, or CI enforces two
# different permission contracts.
if grep -q 'MODIFY_AUDIO_SETTINGS' test/platform/docs_verification_test.dart; then
  note "docs_verification_test.dart permission contract matches the gate"
else
  err "docs_verification_test.dart is out of sync with the verify_docs.sh permission contract"
fi

# Flavor manifests must not reintroduce removed permissions.
while IFS= read -r extra; do
  if grep -qE 'ACCESS_FINE_LOCATION|ACCESS_COARSE_LOCATION|RECORD_AUDIO' "$extra"; then
    err "flavor manifest reintroduces removed permission: $extra"
  else
    note "flavor manifest clean: $extra"
  fi
done < <(find android/app/src -name AndroidManifest.xml ! -path '*/main/*' 2>/dev/null || true)

# Strict analysis options (BUS-P2-04) must stay enabled.
if grep -q 'strict-casts: true' analysis_options.yaml \
  && grep -q 'strict-inference: true' analysis_options.yaml \
  && grep -q 'strict-raw-types: true' analysis_options.yaml; then
  note "strict analysis language flags present"
else
  err "analysis_options.yaml missing strict-* language flags"
fi

# CI must report tests itself — no hand-maintained badge-only counts required.
if grep -q 'flutter test' .github/workflows/ci.yml; then
  note "CI runs flutter test"
else
  err "CI workflow does not run flutter test"
fi

if [[ "$fail" -ne 0 ]]; then
  echo "docs verification FAILED" >&2
  exit 1
fi

echo "docs verification PASSED"
