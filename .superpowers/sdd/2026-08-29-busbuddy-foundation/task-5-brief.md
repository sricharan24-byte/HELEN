# Task 5: Route details and active journey state

Read this brief first. Work in `/home/pavan/BusBuddy` and implement only the selected-route details screen and local active-journey screen for the VIT Vellore → Katpadi Railway Station corridor.

## Files

- Create `lib/features/route_details/route_details_page.dart`.
- Create `lib/features/journey/journey_page.dart`.
- Modify `lib/main.dart` so the route callback from `HomePage` pushes `RouteDetailsPage` with the selected `Route` resolved from the repository and the shared controller/repository.
- Create `test/features/route_details_page_test.dart`.

## Existing interfaces

- `JourneyController.state`, `selectRoute(Route)`, and `startJourney()`.
- `TransportRepository.getStop(String) -> Stop?`.
- `HomePage` and `RouteSearchPage` already expose `onRouteSelected(String routeId)`.
- `Route` has `displayName`, `direction`, and ordered stop IDs.

## Required behavior

- Route details displays route name, direction, boarding stop, destination, and an ordered stop list resolved through the repository.
- The page has a clear semantic action `Start this journey`.
- Tapping it calls `controller.startJourney()` and navigates to `JourneyPage`.
- The journey page exposes semantic heading/label `Journey active`, origin, destination, selected route, and a concise current-state message.
- The local first slice must explicitly say that live bus location and ETA are not connected yet; never fabricate live values.
- Missing route/stop data must display a recoverable message instead of throwing.
- Use `AppTheme.light` from the app shell, semantic headings/grouping, text facts, and accessible touch targets. Do not add maps, network calls, or new dependencies.

## TDD and verification

Write failing widget tests first. Define `routeDetailsTestApp()` in `test/features/route_details_page_test.dart` with a real local repository and controller preloaded with VIT Main Gate, Katpadi Railway Station, and the corridor route. Cover route facts, ordered stops, `Start this journey`, active journey semantics, and missing-data recovery. Run focused tests before implementation, then `dart format lib test/features`, `flutter analyze`, and `flutter test test/features/route_details_page_test.dart`. Write the full report to `.superpowers/sdd/2026-08-29-busbuddy-foundation/task-5-report.md`. Do not modify the data layer, controller, or search UI. Do not dispatch subagents and do not claim a Git commit.
