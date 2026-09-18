# Task 5 Report: Route Details and Active Journey State

**Date:** 2026-08-29  
**Status:** ✅ Complete  
**Tests:** 68/68 passing  
**Analysis:** No issues found  

## Summary

Implemented the route details screen and local active-journey screen for the VIT Vellore → Katpadi Railway Station corridor. All work followed TDD with failing tests written first, then implementation to make them pass.

## Files Created

| File | Purpose |
|------|---------|
| `lib/features/route_details/route_details_page.dart` | Route details page showing route facts and ordered stop list |
| `lib/features/journey/journey_page.dart` | Active journey page showing trip state and explicit tracking disclaimer |
| `test/features/route_details_page_test.dart` | 18 widget tests covering both pages |

## Files Modified

| File | Change |
|------|--------|
| `lib/main.dart` | Wired `onRouteSelected` callback to resolve route from repository, select it on the controller, and push `RouteDetailsPage` via a global navigator key |

## Data/Controller/Search Layers: Untouched

No modifications were made to:
- `lib/data/` (models, datasources, repositories)
- `lib/features/journey/journey_controller.dart`
- `lib/features/route_search/route_search_page.dart`
- `lib/features/home/home_page.dart`
- `lib/core/theme/app_theme.dart`

## Implementation Details

### RouteDetailsPage

- **Route facts:** Displays route display name, direction, boarding stop, and destination stop
- **Ordered stops:** Shows all 12 corridor stops resolved through `TransportRepository.getStop()`, displayed in a numbered list with name and area
- **Start journey:** A semantic `FilledButton` with label "Start this journey" that calls `controller.startJourney()` and navigates to `JourneyPage`
- **Missing data:** When no route is selected, shows "No route selected. Go back and choose a route." — never throws
- **Layout:** Uses `SingleChildScrollView` + `Column` to ensure all content is always in the widget tree (important for accessibility and testing)

### JourneyPage

- **Active journey:** Shows semantic heading "Journey active", origin, destination, and selected route
- **Tracking disclaimer:** Explicitly states "Live bus location and estimated arrival time are not connected yet" and "This is a local-first slice" — never fabricates live values
- **Idle state:** When no journey is active, shows "No active journey. Start a journey from the route details screen."
- **Layout:** Uses `SingleChildScrollView` + `Column` for consistent behavior

### Navigation Wiring (main.dart)

- Added `GlobalKey<NavigatorState>` to `MaterialApp` for context-free navigation
- `onRouteSelected` callback resolves the route from the repository using the corridor origin/destination, selects it on the controller, and pushes `RouteDetailsPage`

## Test Summary

| Test Group | Tests | Status |
|------------|-------|--------|
| RouteDetailsPage — route facts | 4 | ✅ |
| RouteDetailsPage — ordered stops | 2 | ✅ |
| RouteDetailsPage — start journey | 3 | ✅ |
| RouteDetailsPage — missing data recovery | 2 | ✅ |
| JourneyPage — active journey | 6 | ✅ |
| JourneyPage — idle state | 1 | ✅ |
| **Total Task 5** | **18** | **✅** |
| Pre-existing tests (Tasks 1-4) | 50 | ✅ |
| **Grand total** | **68** | **✅** |

### Key Test Scenarios Covered

1. Route display name, direction, boarding/destination stops render correctly
2. All 12 ordered corridor stops are displayed
3. Semantic heading exists for the stop list
4. "Start this journey" button has correct semantic label
5. Tapping the button advances controller to `JourneyPhase.active`
6. Tapping the button navigates to `JourneyPage`
7. Missing route data shows recoverable message without throwing
8. "Journey active" semantic heading on the journey page
9. Origin, destination, and route are displayed on the journey page
10. Explicit disclaimer that live tracking is not connected yet
11. No fabricated ETA or live position values appear
12. Idle state shows "No active journey" message

## Verification

```
dart format lib test/features → 13 files formatted (3 changed)
flutter analyze → No issues found!
flutter test → 68/68 passed
```

## Concerns

1. **Global navigator key:** Using `GlobalKey<NavigatorState>` in `main.dart` to enable context-free navigation from the `onRouteSelected` callback is a pragmatic choice. A more scalable approach (e.g., a navigation service or `GoRouter`) would be appropriate as the app grows.

2. **Route name collision with Flutter:** Both `busbuddy/data/models/transport_models.dart` and `flutter/src/widgets/navigator.dart` export `Route`. All files that use the domain `Route` must prefix the import as `models`. This is a known friction point that could be addressed by renaming the domain model (e.g., `BusRoute`).

3. **No Git commit claimed:** Per the brief instructions, no Git commit was made.

## Report Location

`.superpowers/sdd/2026-08-29-busbuddy-foundation/task-5-report.md`
