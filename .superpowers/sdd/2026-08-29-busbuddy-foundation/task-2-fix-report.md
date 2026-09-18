# Task 2 Fix Report — Route Equality / Hash Contract

**Date:** 2026-08-29
**File:** `lib/data/models/transport_models.dart`
**Scope:** `Route.hashCode` only — no public API changes

---

## Problem

`Route.operator ==` compares `orderedStopIds` element-by-element via `_listEquals`,
but `Route.hashCode` passed the `List<String>` object itself to `Object.hash`.
`Object.hash` hashes list *identity*, not contents, so two `Route` instances with
separately allocated but identical `orderedStopIds` lists were considered equal
by `==` yet produced **different** hash codes — violating the Dart `hashCode` contract.

## One-Line Fix

```dart
// BEFORE (broken — hashes list identity)
int get hashCode => Object.hash(id, displayName, direction, orderedStopIds);

// AFTER (correct — hashes list contents via spread)
int get hashCode => Object.hashAll([id, displayName, direction, ...orderedStopIds]);
```

Using `Object.hashAll` with a spread of the list elements ensures that each
string inside `orderedStopIds` contributes to the hash independently of which
`List` instance holds it.

## TDD Evidence

### RED — test written and run *before* the fix

```
$ flutter test test/data/transport_models_test.dart
  Expected: <514561211>
    Actual: <347049154>
  hashCode must be equal for objects that operator == considers equal

  00:00 +0 -1: Route equality and hashCode …
```

### GREEN — same test passes *after* the fix

```
$ flutter test test/data/transport_models_test.dart
  00:00 +2: All tests passed!
```

### Pre-existing tests

All 11 tests in `test/data/transport_repository_test.dart` continue to pass.

## Quality Gates

| Check | Result |
|---|---|
| `dart format lib/data test/data` | ✅ Clean (no changes needed after initial format) |
| `flutter analyze lib/data` | ✅ No issues found |
| New focused tests | ✅ 2/2 pass |
| Existing repository tests | ✅ 11/11 pass |

## Tests Added

| # | Test | Purpose |
|---|---|---|
| 1 | `equal Routes with distinct orderedStopIds lists share hashCode` | Constructs two `Route` instances with the same field values but **separate list allocations**; asserts `==` and `hashCode` equality. |
| 2 | `Routes that differ in orderedStopIds are not equal` | Confirms the fix didn't break negative cases — routes with different stop lists remain unequal. |

## Concerns

1. **List spread cost:** `...orderedStopIds` creates a temporary `Iterable` on every `hashCode` call. For typical route sizes (< 50 stops) this is negligible. If profiling later shows pressure, a manual hash loop could replace the spread with zero allocation.

2. **Future field additions:** If a `List` or `Set` field is ever added to `Route`, the same pattern (`Object.hashAll` + spread) must be used — `Object.hash` with a collection argument silently hashes identity.

3. **No Git commit per brief instructions.**
