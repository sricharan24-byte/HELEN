# Task 4: Home and route-search flow

Read this brief first. Work in `/home/pavan/BusBuddy` and implement only the home screen plus origin/destination selection and deterministic route results for the BusBuddy VIT Vellore → Katpadi Railway Station corridor.

## Files

- Create `lib/features/home/home_page.dart`.
- Create `lib/features/route_search/route_search_page.dart`.
- Modify `lib/main.dart` to inject the existing controller/repository into the pages and navigate between them.
- Create `test/features/route_search_page_test.dart`.

## Existing interfaces

- `JourneyController` exposes `state`, `selectOrigin(Stop)`, `selectDestination(Stop)`, and `searchRoutes() -> List<Route>`.
- `TransportRepository.findStops(String) -> List<Stop>` and `getStop(String) -> Stop?`.
- `HomePage({required JourneyController controller, required TransportRepository repository})`.
- `RouteSearchPage({required JourneyController controller, required TransportRepository repository})`.

## Required UI behavior

- Home screen shows the BusBuddy title, a concise accessibility-first purpose statement, and one prominent button with semantic label `Plan a journey`.
- Tapping `Plan a journey` opens the route-search page.
- Route search exposes controls with semantic labels `Choose starting stop` and `Choose destination stop`.
- Each control opens a searchable local stop-selection surface. Stop items expose name and area, and selecting one updates the control’s visible and semantic value.
- Route search action is disabled until both places are selected; expose an explanatory text/semantic state `Choose an origin and destination first.` when attempted without both.
- After both selections, tapping search calls the controller and renders route results with route display name, direction, and stop count.
- Each result exposes semantic label `View route VIT to Katpadi` and invokes a callback/navigation to route details in the next task. For this task, a temporary route-selection callback or a clearly labeled placeholder detail page is acceptable, but do not invent ETA/live data.
- Render controller error messages as visible, actionable text and semantic live-region content.
- Use `AppTheme.light`; do not use color, icons, or maps as the only way to convey transport facts.

## TDD and verification

Write failing widget tests before production UI code. Define test helpers in `test/features/route_search_page_test.dart`: `testApp()` builds `MaterialApp` with `LocalTransportRepository`, `JourneyController`, and `HomePage`; `openSearchAndChooseVelloreCorridor(tester)` taps Plan a journey, chooses VIT Main Gate, chooses Katpadi Railway Station, and submits search. Cover semantic controls and deterministic route result rendering. Run focused tests before implementation, then `dart format lib test/features`, `flutter analyze`, and `flutter test test/features/route_search_page_test.dart`. Write the full report to `.superpowers/sdd/2026-08-29-busbuddy-foundation/task-4-report.md`. Preserve the data layer, controller, and theme. Do not dispatch subagents.
