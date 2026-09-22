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

# BUS-P2-01: main manifest must remain INTERNET-only.
# Match only real <uses-permission> tags (not comments that mention removed
# permissions as rationale).
manifest=android/app/src/main/AndroidManifest.xml
declared_perms="$(grep -oE 'android:name="android\.permission\.[A-Z_]+"' "$manifest" \
  | sed 's/android:name="//;s/"//' | sort -u || true)"
if [[ "$declared_perms" == "android.permission.INTERNET" ]]; then
  note "manifest permission minimization holds (INTERNET only)"
else
  err "manifest permission set drifted from BUS-P2-01 contract: got [$declared_perms]"
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
