# Home redesign regression fix

Work in `/home/pavan/BusBuddy` using Xiaomi `mimo-v2.5`.

The full suite has one regression because the existing home-page test expects the home screen to contain visible `VIT Vellore` corridor context. Update the home screen copy, in an appropriate non-interactive purpose/context text near `Plan your journey`, to say that BusBuddy helps plan journeys from VIT Vellore to Katpadi Railway Station. Preserve the redesigned layout and accessibility semantics; do not reintroduce a date input, bottom navigation, separate icon-only controls, or a floating AI button.

Add or update a focused home test if needed. Run `dart format lib test`, `flutter analyze`, and `flutter test`. Write the full report to `.superpowers/sdd/2026-08-29-busbuddy-foundation/home-redesign-regression-report.md`. Do not dispatch subagents or claim a Git commit.
