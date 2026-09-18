# Task 4 — Review Fix Report

**Date:** 2026-08-29
**Brief:** `.superpowers/sdd/2026-08-29-busbuddy-foundation/task-4-fix-brief.md`
**Scope:** Home / route-search flow only. No data layer or journey controller changes.

---

## Summary

| Item | Status |
|------|--------|
| Fix 1 — State read inside builder | ✅ Done |
| Fix 2 — Render `errorMessage` in live region | ✅ Done |
| Fix 3 — Dynamic route-result label | ✅ Done |
| Fix 4 — New error-state widget test | ✅ Done |
| `dart format` | ✅ Clean (1 file auto-formatted) |
| `flutter analyze` | ✅ No issues |
| All route-search tests | ✅ 21/21 passing |

---

## TDD Cycle Evidence

### RED — Failing test written first

Added new test in `Error display` group:

```
controller error message is visible in semantic live region
```

**Test logic:**
1. Build `RouteSearchPage` with a fresh controller and repository.
2. Assert initial guidance text `'Choose an origin and destination first.'` is visible.
3. Trigger an error by calling `controller.selectDestination(…)` with no prior origin → controller sets `JourneyPhase.error` with `errorMessage: 'Choose an origin first.'`.
4. Pump and assert:
   - `find.text('Choose an origin first.')` → **findsOneWidget** ← FAILS before fix (error never rendered).
   - `Semantics(liveRegion: true)` widget exists around it.
   - Old guidance text no longer visible.

**RED output:**
```
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "Choose an origin first.": []>
```

The error message was never rendered because:
- **(a)** `state` was captured outside the `ListenableBuilder` builder — stale after controller notification.
- **(b)** The `Semantics(liveRegion: true)` child only ever rendered the static guidance ternary, never `state.errorMessage`.

### GREEN — Production fixes applied

Three changes in `lib/features/route_search/route_search_page.dart`:

#### Fix 1: Move state read inside builder

```dart
// BEFORE (line ~113)
@override
Widget build(BuildContext context) {
  final state = _ctrl.state;          // ← stale after notifyListeners

  return ListenableBuilder(
    listenable: _ctrl,
    builder: (context, _) {
      return Scaffold( …

// AFTER
@override
Widget build(BuildContext context) {
  return ListenableBuilder(
    listenable: _ctrl,
    builder: (context, _) {
      final state = _ctrl.state;      // ← fresh on every rebuild
      return Scaffold( …
```

#### Fix 2: Render `state.errorMessage` in live region

```dart
// BEFORE
Semantics(
  liveRegion: true,
  child: Text(
    _canSearch
        ? 'Ready to search routes.'
        : 'Choose an origin and destination first.',
    …
  ),
),

// AFTER
Semantics(
  liveRegion: true,
  child: Text(
    state.errorMessage ??
        (_canSearch
            ? 'Ready to search routes.'
            : 'Choose an origin and destination first.'),
    …
  ),
),
```

Error message takes precedence; stale errors are automatically cleared by the controller (every mutation creates a fresh `JourneyState` without `errorMessage` unless in error phase).

#### Fix 3: Dynamic route-result semantic label

```dart
// BEFORE
Semantics(
  label: 'View route VIT to Katpadi',   // hardcoded
  …

// AFTER
Semantics(
  label: 'View route ${route.displayName}',  // derived from route
  …
```

Test assertions updated to match the derived label for the fixture route (`'View route VIT → Katpadi Railway Station'`).

**GREEN output:**
```
00:05 +21: All tests passed!
```

---

## Files Modified

| File | Changes |
|------|---------|
| `lib/features/route_search/route_search_page.dart` | Fixes 1–3: state inside builder, error rendering, dynamic label |
| `test/features/route_search_page_test.dart` | Fix 4: new error-state test; added `transport_models` import; updated label assertions; formatted |

**No changes** to data layer, models, repository, or journey controller.

---

## Test Summary

| Group | Tests | Status |
|-------|-------|--------|
| HomePage | 4 | ✅ |
| RouteSearchPage controls | 5 | ✅ |
| Route search guard | 4 | ✅ |
| Route results | 5 | ✅ |
| Error display | 3 | ✅ (1 new) |
| **Total** | **21** | **✅ All passing** |

New test: `'controller error message is visible in semantic live region'` — exercises error state from reversed selection (destination without origin), asserts error text visibility and semantic live-region.

---

## Concerns

1. **No `setState` after `searchRoutes` in `_search()`** — the search method already calls `_results = routes` inside `setState`, so this is fine. However, if `_search()` were called without `setState` after the builder fix, stale results could persist. Currently not an issue.

2. **Error clearing** — the controller already clears `errorMessage` on every non-error mutation (e.g., `selectOrigin`, `selectDestination` with origin set). No additional clearing logic was needed in the UI layer. This is correct per the brief ("do not modify the journey controller").

3. **`_canSearch` getter** — reads `_ctrl.state` directly (not the local `state` variable). After fix 1, both access the same snapshot inside the builder. The getter remains accurate.
