# Task 3 Report: Theme, Journey Controller & Composition Root

**Date:** 2026-08-29
**Status:** ✅ Complete — all acceptance criteria met

## Deliverables

### Files Created

| File | Purpose |
|------|---------|
| `lib/core/theme/app_theme.dart` | High-contrast blue Material 3 light theme; 48×48 min button size; dependency-free |
| `lib/features/journey/journey_controller.dart` | `JourneyController` (ChangeNotifier) + `JourneyState` immutable snapshot + `JourneyPhase` enum |
| `test/features/journey_controller_test.dart` | 15 TDD tests covering every brief requirement |

### Files Modified

| File | Change |
|------|--------|
| `lib/main.dart` | Replaced Flutter Demo boilerplate with composition root: creates `LocalTransportDataSource` → `LocalTransportRepository` → `JourneyController`; wires `AppTheme.light`; placeholder `HomePage` |

### Data Layer

**No data-layer files were touched.** The following remain unchanged:
- `lib/data/models/transport_models.dart`
- `lib/data/repositories/transport_repository.dart`
- `lib/data/datasources/local_transport_data_source.dart`

All 11 repository tests and 2 model tests from Tasks 1–2 continue to pass.

## Test Summary

**29 tests pass, 0 failures, 0 skipped.**

### Task 3 controller tests (15)

| Group | Test | Result |
|-------|------|--------|
| initial state | starts in idle phase with all fields null | ✅ |
| selectOrigin | stores origin and transitions to originSelected | ✅ |
| selectOrigin | clears a prior error message | ✅ |
| selectOrigin | transitions to destinationSelected when destination already set | ✅ |
| selectDestination | sets error when no origin has been chosen | ✅ |
| selectDestination | stores destination and transitions to destinationSelected | ✅ |
| searchRoutes | returns error when origin is missing | ✅ |
| searchRoutes | returns error when destination is missing | ✅ |
| searchRoutes | delegates to repository and returns routes when both selected | ✅ |
| searchRoutes | sets error when repository returns no routes | ✅ |
| selectRoute | stores route and transitions to routeSelected | ✅ |
| startJourney | sets error when route has not been selected | ✅ |
| startJourney | sets error when origin is missing | ✅ |
| full happy path | idle → originSelected → destinationSelected → search → routeSelected → active | ✅ |
| ChangeNotifier | notifies listeners on state change | ✅ |

### Prior tests (14)
- 11 transport repository tests (Task 2) — all pass
- 2 transport model tests (Task 1) — all pass
- 1 placeholder test (Task 1) — passes

## Verification

| Command | Result |
|---------|--------|
| `dart format lib test/features` | ✅ All files formatted (0 changes on final pass) |
| `flutter analyze` | ✅ No issues found |
| `flutter test` | ✅ 29/29 pass |

## Interface Decisions

### Constructor signature
The brief specified `JourneyController(TransportRepository repository)`. Implemented as a **positional** parameter (`JourneyController(this._repository)`) rather than a named parameter, matching the brief exactly and satisfying the `prefer_initializing_formals` lint.

### searchRoutes return behavior
When routes are found, `searchRoutes()` returns the `List<Route>` and keeps `phase = destinationSelected` — no new enum value is invented, per the brief's directive. The routes are available via the return value, and the controller state retains origin/destination for downstream use.

### State immutability
`JourneyState` uses all `final` fields and a value-equality `==`/`hashCode` override. Callers receive a snapshot that cannot be mutated through the object reference. The controller only mutates its private `_state` field and calls `notifyListeners()`.

## Concerns & Notes

1. **Linux build tools missing.** The CI/dev environment lacks `clang`, `ninja`, `pkg-config`, and GTK 3 dev headers for Linux desktop builds. Flutter test still works (headless), but `flutter run -d linux` would fail. This is an environment issue, not a code issue.

2. **`JourneyController` is not yet wired into any widget tree.** `main.dart` creates it and passes it to `MyApp`, but the placeholder `HomePage` does not consume it. This is intentional — a later task will build the UI.

3. **Theme is light-only.** The brief asked for `AppTheme.light`. A dark theme variant can be added in a later task if desired.

4. **No third-party mocking libraries.** Tests use a hand-written `FakeTransportRepository`, keeping `dev_dependencies` minimal and avoiding mockito/mocktail code generation.
