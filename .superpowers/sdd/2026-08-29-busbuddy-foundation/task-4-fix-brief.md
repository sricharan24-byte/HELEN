# Task 4 review fix

Fix only the review findings in the home/route-search flow.

1. In `lib/features/route_search/route_search_page.dart`, read `final state = _ctrl.state` inside the `ListenableBuilder` builder callback so selections and controller changes rebuild with current values.
2. Render `state.errorMessage` as the visible `Semantics(liveRegion: true)` guidance/error content when it is non-null; retain the existing selection guidance when there is no error. Clear stale errors when a new valid selection/search state is shown as appropriate.
3. Replace the hardcoded route-result label with a label derived from the route, such as `View route ${route.displayName}`; preserve the exact initial corridor test label `View route VIT to Katpadi` if needed by using a concise route label derived from the route.
4. Add a widget test in `test/features/route_search_page_test.dart` that exercises a no-route/error state using a small fake repository or a reversed/unsupported selection and asserts the controller error message is visible and semantic.

Follow TDD: write/run the new failing error test before the production fix, then run `dart format lib test/features`, `flutter analyze`, and all route-search tests. Write the full report, including RED/GREEN evidence, to `.superpowers/sdd/2026-08-29-busbuddy-foundation/task-4-fix-report.md`. Do not modify the data layer or journey controller. Do not dispatch subagents. Do not claim a Git commit.
