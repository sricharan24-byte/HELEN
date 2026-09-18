# Task 2 review fix

Fix only the `Route` value-object equality/hash contract in `lib/data/models/transport_models.dart`.

Current behavior compares `orderedStopIds` by list contents in `operator ==` but passes the List object directly to `Object.hash`, which hashes list identity. Change `hashCode` so two equal Routes with separately allocated but equal `orderedStopIds` have the same hash. Keep the public API and all other behavior unchanged.

Follow TDD: add a focused test under `test/data/transport_repository_test.dart` or a new `test/data/transport_models_test.dart` that constructs two equal Routes with distinct list instances and asserts equality plus equal hash codes; run it before and after the fix. Run `dart format lib/data test/data`, `flutter analyze`, and the focused tests. Write the full report, including RED/GREEN evidence, to `.superpowers/sdd/2026-08-29-busbuddy-foundation/task-2-fix-report.md`. Do not modify UI files or dispatch subagents. Do not claim a Git commit.
