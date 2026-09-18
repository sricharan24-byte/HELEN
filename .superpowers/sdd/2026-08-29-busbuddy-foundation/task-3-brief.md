# Task 3: Theme, journey controller, and application shell

Read this brief first. Work in `/home/pavan/BusBuddy` and implement only the shared theme, journey state/controller, and composition-root wiring for the BusBuddy local vertical slice.

## Files

- Create `lib/core/theme/app_theme.dart`.
- Create `lib/features/journey/journey_controller.dart`.
- Modify `lib/main.dart` to create and inject the repository/controller and display the home page placeholder or home page import if already present.
- Create `test/features/journey_controller_test.dart`.

## Interfaces

- `enum JourneyPhase { idle, originSelected, destinationSelected, routeSelected, active, error }`.
- `JourneyState({required JourneyPhase phase, Stop? origin, Stop? destination, Route? selectedRoute, String? errorMessage})`.
- `JourneyController(TransportRepository repository)` extends `ChangeNotifier`.
- `JourneyController.state -> JourneyState`.
- `selectOrigin(Stop stop) -> void`.
- `selectDestination(Stop stop) -> void`.
- `searchRoutes() -> List<Route>`.
- `selectRoute(Route route) -> void`.
- `startJourney() -> void`.

## Behavior

- `selectOrigin` stores the stop, clears any prior error, and sets phase to `originSelected` unless a destination is already selected, in which case it preserves a valid destination and uses `destinationSelected` only after destination selection.
- `selectDestination` stores the stop and sets phase to `destinationSelected` when an origin exists, otherwise `error` with `Choose an origin first.`.
- `searchRoutes` returns an empty list and sets error `Choose an origin and destination first.` when either selection is missing. Otherwise it delegates to the repository and sets phase to `error` with `No routes found for this journey.` when there are no matches, or `destinationSelected`/results-available behavior without inventing a new enum value when routes exist.
- `selectRoute` stores the route and sets `routeSelected`.
- `startJourney` sets `active` only when origin, destination, and selected route exist; otherwise it sets error `Select a route before starting your journey.`.
- State snapshots must be immutable from callers’ perspective. Use `ChangeNotifier` and notify after transitions.

## Theme

Create `AppTheme.light` with a high-contrast blue primary color, readable Material text styles, clear button styling, and minimum button constraints of `48×48` logical pixels. Keep the theme dependency-free.

## TDD and verification

Write failing controller tests first for missing selections, valid VIT→Katpadi transition to active, and invalid start. Run them before production code. Then run `dart format lib test/features`, `flutter analyze`, and `flutter test test/features/journey_controller_test.dart`. Write the full report to `.superpowers/sdd/2026-08-29-busbuddy-foundation/task-3-report.md`. Preserve the data layer and do not dispatch subagents.
