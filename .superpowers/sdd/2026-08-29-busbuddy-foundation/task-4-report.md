# Task 4 Report: Home and Route-Search Flow

**Date:** 2026-08-29
**Status:** ✅ Complete
**Test summary:** 49/49 passing (20 new + 29 existing)

---

## What was implemented

### Files created
- `lib/features/home/home_page.dart` — Landing screen with BusBuddy title, corridor purpose statement, and prominent "Plan a journey" button that navigates to the route-search page.
- `lib/features/route_search/route_search_page.dart` — Route-search screen with origin/destination controls, searchable stop-selection bottom sheet, search guard, and route-result list with semantic labels and tap callbacks.
- `test/features/route_search_page_test.dart` — 20 widget tests covering HomePage rendering, navigation, RouteSearchPage controls, stop selection/filtering, search guard logic, route result rendering, semantic labels, and error display.

### Files modified
- `lib/main.dart` — Removed inline placeholder `HomePage`; now wires `HomePage` with `JourneyController`, `TransportRepository`, and a no-op route callback.

### Files preserved (untouched)
- `lib/core/theme/app_theme.dart`
- `lib/data/datasources/local_transport_data_source.dart`
- `lib/data/models/transport_models.dart`
- `lib/data/repositories/transport_repository.dart`
- `lib/features/journey/journey_controller.dart`
- All existing test files under `test/data/` and `test/features/journey_controller_test.dart`

---

## Architecture decisions

| Decision | Rationale |
|---|---|
| `Route` imported as `models` prefix in `route_search_page.dart` | Avoids name clash with Flutter's `Navigator.Route` which is imported transitively through `material.dart`. |
| Stop-selection surface uses `showModalBottomSheet` + `DraggableScrollableSheet` | Gives a native feel, supports search filtering, and is testable with `enterText` + tap. |
| Search button is `ElevatedButton` with `onPressed: null` when disabled | Null-safe disabled state provides clear semantic a11y signal (button is disabled) without inventing a custom state. |
| `ListenableBuilder` wraps Scaffold in `RouteSearchPage` | Efficiently rebuilds only on controller changes; avoids unnecessary full-state rebuilds. |
| Route results render via `ListView.builder` | Efficient for large result sets; each item exposes `Semantics(label: 'View route VIT to Katpadi', button: true)`. |
| `onRouteSelected` callback passed as constructor parameter | Keeps the page navigation-agnostic — the next task can wire real navigation without modifying `RouteSearchPage`. |

---

## Test summary

| Group | Tests | Status |
|---|---|---|
| HomePage — title and purpose | 2 | ✅ |
| HomePage — navigation | 2 | ✅ |
| RouteSearchPage controls | 5 | ✅ |
| Route search guard | 4 | ✅ |
| Route results | 5 | ✅ |
| Error display | 2 | ✅ |
| **Total new** | **20** | **✅** |
| Existing (data + controller + placeholder) | 29 | ✅ |
| **Total suite** | **49** | **✅** |

### Verification commands
```
dart format lib test/features    → 3 files reformatted, 0 issues
flutter analyze                  → No issues found!
flutter test                     → 49/49 All tests passed!
```

---

## Semantic / accessibility coverage

- `HomePage` body text is a header with descriptive corridor text.
- "Plan a journey" button has `Semantics(label: 'Plan a journey', button: true)`.
- Origin control: `Semantics(label: 'Choose starting stop', button: true)`.
- Destination control: `Semantics(label: 'Choose destination stop', button: true)`.
- Guidance text wrapped in `Semantics(liveRegion: true)` so screen readers announce state changes.
- Search button: `Semantics(label: 'Search routes', button: true)`.
- Route result cards: `Semantics(label: 'View route VIT to Katpadi', button: true)`.
- All text conveys information independently of color or icons.

---

## Concerns and future work

1. **DraggableScrollableSheet test ergonomics**: The `ListView.builder` inside the bottom sheet virtualises items, so off-screen stops (e.g., Katpadi Railway Station at index 11) cannot be tapped directly. Tests work around this by typing a search query to narrow the list. A future task could add a `scrollUntilVisible`-friendly scrollable key for better test control.

2. **No real navigation yet**: Tapping a route result invokes the `onRouteSelected` callback. The brief accepts a placeholder for this; the next task should wire it to a route-detail screen.

3. **No ETA or live data**: Route results show display name, direction, and stop count only. The brief explicitly forbids inventing ETA/live data.

4. **Single-route corridor**: The fixture data has one route (`VIT → Katpadi Railway Station`). The UI handles zero and multiple results gracefully, but only one is exercised in tests.

5. **Theme usage**: `AppTheme.light` is used in `main.dart` but test helpers use a simple `ThemeData(useMaterial3: true)` for test isolation. This is intentional — widget tests should not depend on production theme internals.

6. **No dependency injection framework**: Composition is manual in `main.dart`. This is fine for the current scale but may need refactoring as the app grows.
