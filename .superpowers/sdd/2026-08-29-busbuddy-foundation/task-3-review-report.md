# Task 3 Review: Theme, Journey Controller & Composition Root

**Reviewer:** MiMo (automated review)
**Date:** 2026-08-29
**Scope:** Read-only inspection of `app_theme.dart`, `journey_controller.dart`, `main.dart`, `journey_controller_test.dart`, and `task-3-report.md`
**Verdict:** ✅ **APPROVED**

---

## Summary

Task 3 delivers a clean, well-structured `JourneyController` with immutable state snapshots, a high-contrast Material 3 light theme with accessible button sizing, a proper composition-root in `main.dart`, and 15 focused controller tests — all passing alongside the 14 prior tests (29 total). No data-layer files were modified. The implementation faithfully follows the brief's interfaces, behavior spec, and verification requirements.

---

## Findings by Severity

### ✅ No Critical or High Findings

---

### 🟡 Medium (non-blocking, worth noting)

#### M1 — No test for `searchRoutes` clearing a previously selected route

**Brief directive:** *"Existing selectedRoute is cleared since we have a fresh search"* (implementation comment in controller).

The controller correctly clears `selectedRoute` when `searchRoutes` returns results:
```dart
_updateState(
  JourneyState(
    phase: JourneyPhase.destinationSelected,
    origin: origin,
    destination: destination,
    // selectedRoute intentionally omitted → null
  ),
);
```
However, no test exercises the path where `selectRoute` → `searchRoutes` verifies the previously selected route is cleared. The happy-path test calls `searchRoutes` before `selectRoute`, so this edge is unexercised.

**Impact:** Low. The behavior is correct; only test coverage for this specific re-search scenario is missing.

#### M2 — `MyApp` receives `journeyController` but does not propagate it

`main.dart` correctly creates `JourneyController` and passes it to `MyApp`, but `MyApp` stores it as a field without placing it in the widget tree (e.g., via `Provider`, `InheritedWidget`, or passing to `HomePage`). The brief says *"display the home page placeholder or home page import if already present"* and does not require widget-tree consumption, so this is intentional. The field is unused today but correctly staged for later tasks.

**Impact:** None — intentional by design. Flagging only so a future task remembers to wire it.

#### M3 — Theme is light-only

`AppTheme.light` is provided as specified. No `AppTheme.dark` exists. The brief only asked for `light`, so this is expected.

**Impact:** None for this task.

---

### 🟢 Low (informational / positive observations)

#### L1 — Immutability is correctly enforced

`JourneyState` uses all `final` fields with `const` constructor and value-equality `==`/`hashCode`. Callers receive a snapshot; the controller mutates only its private `_state`. This matches the brief's *"State snapshots must be immutable from callers' perspective"*.

#### L2 — `ChangeNotifier` behavior is correct and tested

Every public mutation calls `_updateState` which sets `_state` then calls `notifyListeners()`. The `ChangeNotifier` test asserts 4 notifications across 4 mutations — correct.

#### L3 — All brief error messages are exact matches

| Method | Expected | Actual |
|--------|----------|--------|
| `selectDestination` (no origin) | `Choose an origin first.` | ✅ Exact |
| `searchRoutes` (missing sel.) | `Choose an origin and destination first.` | ✅ Exact |
| `searchRoutes` (no routes) | `No routes found for this journey.` | ✅ Exact |
| `startJourney` (no route) | `Select a route before starting your journey.` | ✅ Exact |

#### L4 — Every `JourneyPhase` enum value is exercised by tests

| Phase | Tested via |
|-------|-----------|
| `idle` | Initial state test |
| `originSelected` | selectOrigin tests |
| `destinationSelected` | selectDestination, searchRoutes tests |
| `routeSelected` | selectRoute test |
| `active` | Full happy-path test |
| `error` | Multiple error-path tests |

#### L5 — Theme meets all accessibility constraints

- Minimum button size: `Size(48, 48)` on `filledButtonTheme`, `elevatedButtonTheme`, `outlinedButtonTheme` — matches brief's "minimum button constraints of 48×48 logical pixels".
- Primary color `#0D47A1` (blue 900) against white on-primary — high contrast.
- `useMaterial3: true` — correct.
- No external dependencies — matches brief's "dependency-free" requirement.

#### L6 — Composition root follows correct dependency chain

```
LocalTransportDataSource → LocalTransportRepository → JourneyController → MyApp
```

Matches the brief's requirement to *"create and inject the repository/controller"*.

#### L7 — Fake repository is clean and minimal

Tests use a hand-written `FakeTransportRepository` with `findRoutesCalls` counter for verification. No external mocking library. Keeps `dev_dependencies` minimal.

#### L8 — Formatting and analysis pass cleanly

- `dart format` — 0 changes on all 4 files
- `flutter analyze` — No issues found
- `flutter test` — 29/29 pass (15 new + 14 prior)

---

## Interface Conformance Matrix

| Brief Requirement | Status |
|---|---|
| `enum JourneyPhase { idle, originSelected, destinationSelected, routeSelected, active, error }` | ✅ Exact |
| `JourneyState({phase, origin?, destination?, selectedRoute?, errorMessage?})` | ✅ Exact |
| `JourneyController(TransportRepository repository) extends ChangeNotifier` | ✅ Positional param |
| `state -> JourneyState` getter | ✅ Present |
| `selectOrigin(Stop) -> void` | ✅ Present |
| `selectDestination(Stop) -> void` | ✅ Present |
| `searchRoutes() -> List<Route>` | ✅ Present |
| `selectRoute(Route) -> void` | ✅ Present |
| `startJourney() -> void` | ✅ Present |
| Immutable state snapshots | ✅ All final, value equality |
| `ChangeNotifier` + `notifyListeners()` | ✅ Every mutation |
| `AppTheme.light` with blue primary, 48×48 buttons | ✅ Verified |
| Composition-root wiring in `main.dart` | ✅ Verified |
| Data layer untouched | ✅ Verified |

---

## Verdict

**✅ APPROVED**

The implementation is faithful to the brief across all interfaces, behavior specifications, theme requirements, and verification steps. The two medium findings (missing re-search test, unused widget-tree field) are non-blocking and appropriately deferred. No changes required.
