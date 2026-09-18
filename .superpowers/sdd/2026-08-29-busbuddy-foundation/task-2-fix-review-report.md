# Task 2 Fix Review Report

**Date:** 2026-08-29
**Reviewer:** MiMo (read-only automated review)
**Verdict:** ✅ **APPROVED**

---

## Review Checklist

### 1. Route equality/hashCode Contract — Fixed ✅

The `Route.hashCode` getter now uses `Object.hashAll` with a spread of `orderedStopIds`
elements instead of the prior `Object.hash(...)` which passed the list object itself
(identity-hash). This correctly aligns `hashCode` with the element-by-element comparison
in `operator ==`.

**Verified in source:** `lib/data/models/transport_models.dart` lines for `Route`:

```dart
int get hashCode =>
    Object.hashAll([id, displayName, direction, ...orderedStopIds]);
```

### 2. Tests Genuinely Cover the Fix — ✅

`test/data/transport_models_test.dart` contains 2 focused tests:

| Test | What it asserts | Verdict |
|---|---|---|
| Equal routes with distinct list allocations share `hashCode` | `a == b` AND `a.hashCode == b.hashCode` for separately-allocated but content-identical `orderedStopIds` | ✅ Passes |
| Routes differing in `orderedStopIds` are not equal | `a != b` when stop lists differ | ✅ Passes |

Test 1 directly exercises the exact bug scenario (the old code would produce different
hashCodes for separately-allocated identical lists). Test 2 confirms the fix didn't
break negative cases.

### 3. No Unrelated Files Changed — ✅

The fix touches only:
- `lib/data/models/transport_models.dart` — the `Route.hashCode` getter
- `test/data/transport_models_test.dart` — the new test file
- `.superpowers/sdd/2026-08-29-busbuddy-foundation/task-2-fix-report.md` — the fix report

No other source files were modified.

### 4. Existing Tests Unaffected — ✅

All 11 pre-existing tests in `test/data/transport_repository_test.dart` continue to pass.

### 5. Static Analysis — ✅

`flutter analyze lib/data/models/transport_models.dart` reports **no issues found**.

---

## Minor Observations (Non-Blocking)

1. **`Stop` and `JourneySelection` lack dedicated tests** — `Stop` has correct
   `==`/`hashCode` but no tests exercise it directly. `JourneySelection` has no
   equality override at all. These are pre-existing gaps, not regressions from this fix.

2. **`Stop.hashCode` uses `Object.hash` correctly** — all three fields (`id`, `name`,
   `area`) are plain `String`s, so identity vs. contents is not an issue there.

---

## Conclusion

The fix is correct, minimal, and well-tested. The `Route.hashCode` contract violation
has been eliminated. No unrelated changes were introduced. **Approved.**
