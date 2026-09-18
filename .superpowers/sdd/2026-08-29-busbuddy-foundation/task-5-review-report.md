# Task 5 Review Report: Route Details and Active Journey State

**Reviewer**: MiMo (read-only review)
**Date**: 2026-08-29
**Files inspected**: `lib/features/route_details/route_details_page.dart`, `lib/features/journey/journey_page.dart`, `lib/main.dart`, `test/features/route_details_page_test.dart`, `lib/features/journey/journey_controller.dart`
**Tests**: 18/18 passing (Task 5), 68/68 total

---

## Verdict: **CHANGES_REQUIRED**

---

## CRITICAL Findings

### C1 — Controller state captured outside `ListenableBuilder` in `RouteDetailsPage`

**Location**: `route_details_page.dart` — `RouteDetailsPage.build()`

```dart
final state = controller.state;   // ← stale snapshot
final route = state.selectedRoute;

// ... null guard for route ...

return ListenableBuilder(
  listenable: controller,
  builder: (context, _) {
    // `state` and `route` here are from the OUTER build(), not from the
    // latest notifyListeners() call.
```

`state`, `route`, `boardingStop`, `destinationStop`, and the resolved `stops` list are all captured **before** the `ListenableBuilder` callback. When the controller fires `notifyListeners()`, the builder rebuilds but renders stale values.

The brief explicitly warns: *"Check … stale controller-state capture inside `ListenableBuilder`."*

**Impact**: The `ListenableBuilder` is decorative — it rebuilds but never reads fresh controller state. If the controller's state changes while this page is mounted (e.g., a future "cancel" action), the UI will display stale data.

**Fix**: Move `state`, `route`, and all derived values inside the `ListenableBuilder` builder callback. Keep the null-route guard inside the builder as well (return a different widget when `route == null`).

---

### C2 — Controller state captured outside `ListenableBuilder` in `JourneyPage`

**Location**: `journey_page.dart` — `JourneyPage.build()`

```dart
final state = controller.state;   // ← stale snapshot

return ListenableBuilder(
  listenable: controller,
  builder: (context, _) {
    final isActive = state.phase == JourneyPhase.active;  // uses stale state
```

`state` is captured once at build time. The `isActive` check inside the builder references the stale snapshot, not the latest controller state. After `startJourney()` triggers `notifyListeners()`, the builder fires but `isActive` still reflects the previous phase.

**Impact**: Same as C1 — the `ListenableBuilder` cannot react to controller state changes. The active/idle branching uses frozen state. This currently works only because `JourneyPage` is freshly mounted via `Navigator.push` (so the initial build reads the correct phase), but the reactive listener is broken.

**Fix**: Move `final state = controller.state;` inside the `ListenableBuilder` builder callback.

---

### C3 — Test gap: "Journey active" semantic label check passes despite stale-state bug

**Location**: `route_details_page_test.dart` — `'tapping Start this journey navigates to JourneyPage'`

```dart
expect(find.bySemanticsLabel('Journey active'), findsOneWidget);
```

This test passes **by coincidence**: JourneyPage is freshly mounted after `Navigator.push`, so the initial build reads the correct `active` phase. However, `find.bySemanticsLabel('Journey active')` does not verify the widget is a **semantic header**. If the stale-state bug causes `isActive` to be `false`, the idle view is shown — but the test would still pass because the `'Journey active'` text is embedded in the widget tree via a `Semantics(header: true, ...)` wrapper even though the builder might evaluate `isActive` incorrectly in future scenarios.

The test does not verify:
- That `isActive == true` was evaluated (header semantics vs. label-only semantics)
- That the origin/destination/route sub-headings are visible

**Fix**: Add assertions that verify the active view's specific header children (origin name, destination name, route name, live-region disclaimer) are present — not just the "Journey active" label.

---

## MAJOR Findings

### M1 — `navigatorKey` created inside `build()` in `main.dart`

**Location**: `main.dart` — `MyApp.build()`

```dart
final navigatorKey = GlobalKey<NavigatorState>();
```

A new `GlobalKey` is allocated on every rebuild. `GlobalKey` instances must be stable across rebuilds; creating one inside `build()` means if `MyApp` ever rebuilds (e.g., due to an inherited widget change), the navigator key changes, destroying navigator state. Currently `MyApp` is the root widget and does not rebuild, so this is dormant.

**Fix**: Move `navigatorKey` to a `StatefulWidget`'s state, or make it a `static final` / top-level constant.

---

### M2 — Excessive `Semantics(header: true)` labels in `JourneyPage`

**Location**: `journey_page.dart` — `_buildActiveView()`

"Origin", "Destination", and "Route" are each wrapped in `Semantics(header: true, ...)`. These are **field labels**, not section headers. Screen readers will announce three consecutive "heading" landmarks for what are essentially key-value pairs. The `heading` semantic should be reserved for section-level headings like "Journey active".

**Fix**: Remove `header: true` from the sub-labels, or restructure as a single heading + list of labeled values.

---

## MINOR Findings

### m1 — Fallback route resolution in `main.dart` could mask bugs

**Location**: `main.dart` — `onRouteSelected` callback

```dart
resolved ??= routes.isNotEmpty ? routes.first : null;
```

If `routeId` is not found in the results, the code silently falls back to the first route. This could mask an ID mismatch bug. The fallback is defensive but should at least log a warning or be removed in favor of returning early with an error.

**Severity**: Minor (defensive code that hides potential bugs)

---

### m2 — No test for `JourneyPage` idle state as a direct mount (not via navigation)

**Location**: `route_details_page_test.dart`

The idle-state test creates a `JourneyController` without starting a journey and directly mounts `JourneyPage`. This is correct. However, there is no test that verifies navigating **back** from an active journey returns to the idle view correctly. This is a minor coverage gap.

**Severity**: Minor (test coverage gap)

---

### m3 — Domain `Route` name conflicts with Flutter's `Route`

Both the domain model `Route` and Flutter's `Navigator.Route` share the same name. All files use `models.Route` prefix, which works but creates import friction. Not a bug, but a naming concern flagged in the Task 5 report itself.

**Severity**: Minor (readability / maintainability)

---

## Checklist Against Brief

| Requirement | Status | Notes |
|---|---|---|
| Route name, direction displayed | ✅ | `route.displayName`, `route.direction` |
| Boarding stop and destination displayed | ✅ | From `state.origin` / `state.destination` |
| Ordered stop list resolved via repository | ✅ | `repository.getStop()` per `route.orderedStopIds` |
| Missing stop fallback (`Unknown stop`) | ✅ | Null-coalescing on `stop?.name` |
| Missing route recovery message | ✅ | "No route selected" message, no throw |
| Semantic action "Start this journey" | ✅ | `Semantics(button: true)` + `FilledButton` |
| `startJourney()` called on tap | ✅ | Verified by test |
| Navigation to `JourneyPage` | ✅ | `Navigator.push` on tap |
| Journey page heading "Journey active" | ✅ | `Semantics(header: true)` |
| Origin, destination, route shown | ✅ | Text widgets with values |
| Live tracking disclaimer | ✅ | "not connected yet" + local-first note |
| `Semantics(liveRegion: true)` on state message | ✅ | On the disclaimer text |
| No fabricated ETA/live values | ✅ | Verified by test |
| Idle journey state recovery | ✅ | "No active journey" message |
| `AppTheme.light` used | ✅ | Via `MaterialApp` theme in `main.dart` |
| Text-based facts, no maps/network | ✅ | |
| Data/controller/search layers untouched | ✅ | No modifications found |
| Controller state inside `ListenableBuilder` | ❌ | Captured outside in both pages (C1, C2) |
| TDD tests written first | ✅ | 18 tests, all passing |
| `dart format` clean | ✅ | |
| `flutter analyze` clean | ✅ | No issues found |

---

## Summary

The implementation correctly fulfills the feature requirements: route facts are displayed, ordered stops are resolved, the start-journey action works, navigation flows correctly, missing data is gracefully handled, and the live-tracking disclaimer is present with appropriate semantics. Test coverage is thorough for the current behavior.

However, the same `ListenableBuilder` stale-state anti-pattern flagged in the Task 4 review has been repeated in both new pages. The `ListenableBuilder` widgets are effectively no-ops — they rebuild but read frozen state from outside their callbacks. Tests pass only because pages are freshly mounted on navigation, not because the reactive pattern works correctly. These must be fixed before approval.
