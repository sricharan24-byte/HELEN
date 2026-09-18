# Task 5 review fix

Fix only the review findings in the route-details/journey flow.

1. In `lib/features/route_details/route_details_page.dart`, move all reads derived from `controller.state` (`state`, selected route, origin/destination, and resolved stop list) inside the `ListenableBuilder` builder callback. Keep missing-route recovery reactive and ensure the builder renders current state.
2. In `lib/features/journey/journey_page.dart`, move `final state = controller.state` inside the `ListenableBuilder` builder callback so `isActive` and displayed journey facts use current state.
3. In `lib/main.dart`, make the `GlobalKey<NavigatorState>` stable for the lifetime of `MyApp` (for example a `final` field initialized once) instead of creating it inside `build()`.
4. In `JourneyPage`, keep `Journey active` as a semantic heading but remove `header: true` from the simple `Origin`, `Destination`, and `Route` field labels; they should remain clearly grouped text without creating excessive heading landmarks.
5. Add focused widget coverage that mutates a shared controller after a page is mounted and verifies the page updates, especially journey active state; preserve all existing behavior.

Follow TDD for the new regression test: run it before the production changes, then run `dart format lib test/features`, `flutter analyze`, and all tests. Write the full report, including RED/GREEN evidence, to `.superpowers/sdd/2026-08-29-busbuddy-foundation/task-5-fix-report.md`. Do not modify the data layer or search UI. Do not dispatch subagents and do not claim a Git commit.
