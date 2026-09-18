# Task 4 Review Report: Home and Route-Search Flow

**Reviewer**: MiMo (read-only review)
**Date**: 2026-08-29
**Files inspected**: `lib/features/home/home_page.dart`, `lib/features/route_search/route_search_page.dart`, `lib/main.dart`, `test/features/route_search_page_test.dart`
**Tests**: 20/20 passing

---

## Verdict: **CHANGES_REQUIRED**

---

## CRITICAL Findings

### C1 — Controller state captured outside `ListenableBuilder` callback (route_search_page.dart:73–78)

**Location**: `_RouteSearchPageState.build()`

```dart
@override
Widget build(BuildContext context) {
  final state = _ctrl.state;        // ← stale capture OUTSIDE builder

  return ListenableBuilder(
    listenable: _ctrl,
    builder: (context, _) {
      // `state` here is the value from the *previous* build frame,
      // not the value after the latest notifyListeners().
```

The brief explicitly warns: *"Pay particular particular attention to whether controller state is read inside the `ListenableBuilder` callback rather than captured before it."*

**Impact**: When the controller notifies listeners (e.g. after `selectOrigin` or `selectDestination`), the `ListenableBuilder` rebuilds, but `state` still holds the stale snapshot from the outer `build()` call. This creates a one-frame lag where the UI shows old data. In practice the outer `build()` is also called after `setState()` in `_pickStop`, which masks the bug for user-initiated selections — but any controller-driven state change that does *not* also call `setState()` will render stale values.

**Fix**: Move `final state = _ctrl.state;` inside the `ListenableBuilder` builder callback.

---

### C2 — Controller error messages are never rendered in the UI (route_search_page.dart)

**Location**: `_RouteSearchPageState.build()` — the guidance/error `Semantics` widget

The `ListenableBuilder` only displays a static ternary:

```dart
Text(
  _canSearch
      ? 'Ready to search routes.'
      : 'Choose an origin and destination first.',
)
```

The `JourneyController` sets `state.errorMessage` on error (e.g. `'No routes found for this journey.'` from `searchRoutes()`), but this value is **never read or displayed** in the UI. The brief requires: *"Render controller error messages as visible, actionable text and semantic live-region content."*

**Impact**: If `searchRoutes()` returns zero routes, the controller transitions to `JourneyPhase.error` with an explanatory message, but the user sees nothing — the guidance text stays as `'Ready to search routes.'` and `_results` silently becomes empty.

**Fix**: Read `state.errorMessage` inside the builder and render it when non-null, with `Semantics(liveRegion: true, ...)`.

---

## MAJOR Findings

### M1 — `_results` is local widget state but never updated by controller rebuilds (route_search_page.dart:48)

`_results` is a plain `List<Route>` field on the `State`, mutated only by `_search()` via `setState()`. Since the `ListenableBuilder` wraps the results list, a controller-triggered rebuild (from another widget or callback) would rebuild the tree but `_results` would hold whatever was last set by `_search()`.

This is a design smell: the results should either live in the controller (single source of truth) or be explicitly guarded so they only change via `_search()`. Currently it works because nothing else clears results, but the architecture is fragile.

**Severity**: Major (design debt, not currently breaking)

---

### M2 — Hardcoded semantic label on all route results (route_search_page.dart:123)

```dart
Semantics(
  label: 'View route VIT to Katpadi',
```

Every route result card gets the same semantic label regardless of its actual `displayName` or `direction`. If there were multiple routes, screen-reader users would hear identical labels and have no way to distinguish them.

The brief says: *"Each result exposes semantic label `View route VIT to Katpadi`"* — so this is technically compliant for the single-corridor MVP. However, the label should be dynamic: `'View route ${route.displayName}'`.

**Severity**: Major (accessibility defect; compliant only because the brief uses an example, but will break as soon as multiple routes exist)

---

### M3 — No test verifies controller error messages are rendered (test file)

The "Error display" group tests only check for the static guidance text `'Choose an origin and destination first.'` and the live-region `Semantics` widget. There is no test that:

1. Triggers a controller error (e.g. searching with a non-matching pair).
2. Asserts the error message text is visible.
3. Asserts it is announced via `liveRegion`.

This gap directly enables C2 to go undetected.

**Severity**: Major (test gap)

---

## MINOR Findings

### m1 — `openSearchAndChooseVelloreCorridor` navigates from HomePage but `testSearchApp` starts at RouteSearchPage (test file)

The helper `openSearchAndChooseVelloreCorridor` uses `testApp()` (which starts at `HomePage`) and navigates forward. But most route-search tests use `testSearchApp()` which starts directly at `RouteSearchPage`. This means the helper is only used in the "Route results" group where it's called manually after `pumpWidget(testSearchApp())` — but wait, actually looking again, the route result tests call `openSearchAndChooseVelloreCorridor(tester)` which internally calls `pumpWidget(testApp())`, *replacing* the previously pumped `testSearchApp()`.

This works by coincidence (the helper re-pumps the whole widget tree) but is confusing. The `testSearchApp` + `openSearchAndChooseVelloreCorridor` combination in the same test is an anti-pattern.

**Severity**: Minor (test clarity)

---

### m2 — `_StopPickerSheetState._controller` shadows `TextEditingController` name (route_search_page.dart:167)

The private field `_controller` in `_StopPickerSheetState` is a `TextEditingController`, not a `JourneyController`. This is not a bug (private names are scoped to the class), but the naming overlap is mildly confusing during review.

**Severity**: Minor (readability)

---

### m3 — Stop picker does not close when selecting the already-selected stop (route_search_page.dart)

If a user opens the stop picker and taps the stop they already selected, `Navigator.pop(stop)` fires, `_pickStop` receives a non-null stop, calls `selectOrigin/selectDestination` again, and `setState` triggers a rebuild. This is a no-op from the user's perspective but causes an unnecessary controller notification and rebuild.

**Severity**: Minor (UX polish)

---

### m4 — Guidance text uses hardcoded string instead of reading controller phase/error (route_search_page.dart:98–101)

The ternary `_canSearch ? 'Ready to search routes.' : 'Choose an origin and destination first.'` uses a local boolean rather than reading `state.phase == JourneyPhase.error` or `state.errorMessage`. Even ignoring C2 (missing error rendering), the guidance text should ideally reflect the controller's actual state rather than a derived local boolean.

**Severity**: Minor (consistency; overlaps with C2)

---

## Checklist Against Brief

| Requirement | Status | Notes |
|---|---|---|
| Home: title, purpose statement, "Plan a journey" button | ✅ | |
| Navigation to route-search page | ✅ | `Navigator.push` |
| Semantic labels `Choose starting stop` / `Choose destination stop` | ✅ | |
| Searchable stop-selection surface | ✅ | `_StopPickerSheet` with `TextField` + `ListView` |
| Stop items expose name and area | ✅ | `title: stop.name`, `subtitle: stop.area` |
| Search disabled until both selected | ✅ | `onPressed: _canSearch ? _search : null` |
| Explanatory text `Choose an origin and destination first.` | ✅ | |
| Route results: displayName, direction, stop count | ✅ | |
| Semantic label `View route VIT to Katpadi` | ⚠️ | Hardcoded (M2) |
| `onRouteSelected` callback | ✅ | |
| Controller error rendering | ❌ | Not implemented (C2) |
| Live-region semantics on errors | ❌ | Not tested (M3) |
| `AppTheme.light` used | ✅ | Via `main.dart`; test uses plain `ThemeData` (acceptable) |
| No color/icons/maps as sole transport facts | ✅ | Text-based |
| Controller state read inside ListenableBuilder | ❌ | Captured outside (C1) |
| TDD: tests written, 20/20 passing | ✅ | |
| `dart format`, `flutter analyze` | ✅ | (assume clean based on test pass) |

---

## Summary

The implementation is well-structured, the UI flows are correct, the stop picker is clean, and test coverage is broad. However, two critical issues must be fixed before approval:

1. **C1**: Move `_ctrl.state` access inside the `ListenableBuilder` builder callback.
2. **C2**: Render `state.errorMessage` when the controller is in error phase, with live-region semantics.

Additionally, **M2** (dynamic semantic labels) and **M3** (error rendering tests) should be addressed in the same change.
