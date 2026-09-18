# Home redesign verification fixes

Work in `/home/pavan/BusBuddy`. Read the home redesign brief at `.superpowers/sdd/2026-08-29-busbuddy-foundation/home-redesign-brief.md` and the current verification report.

Fix the reported 7 failures without changing the intended home UI:

1. Update `test/features/home_page_test.dart` so tests for `Starting point` and `Where to?` assert the actual semantic labels using a semantics finder, not `find.text()` when the labels are intentionally semantic-only.
2. Fix the three tests for `My tickets and trip history`, `Live location and safety sharing`, and `Talk to BusBuddy` so they assert the semantic action labels or otherwise target the actual visible widgets robustly. The tests must still verify the full-width stacked actions exist.
3. Remove the stale generated `test/widget_test.dart` if it still references the old `MyApp()` constructor and is not the approved placeholder test.
4. Remove any unused import reported by `flutter analyze`, without changing behavior.

Run `dart format lib test`, `flutter analyze`, and `flutter test`. Write a full report to `.superpowers/sdd/2026-08-29-busbuddy-foundation/home-redesign-fix-report.md` with the command outputs and final test count. Do not dispatch subagents or claim a Git commit. Preserve the home UI unless a compile fix requires a minimal source edit.
