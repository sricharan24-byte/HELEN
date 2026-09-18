# BusBuddy home-screen redesign

Read this brief and the supplied visual reference before editing:

- Visual reference: `/tmp/busbuddy_stitch/screen.png` (extracted from the supplied ZIP).
- Design tokens/reference guidance: `/tmp/busbuddy_stitch/DESIGN.md` (extracted from the supplied ZIP).
- Existing app: `/home/pavan/BusBuddy`.

Implement the approved BusBuddy home-screen redesign in the existing Flutter app. Use Xiaomi `mimo-v2.5` for implementation. Do not add web code, network calls, new dependencies, maps, Firebase, Gemini, login, or backend behavior.

## Scope

Modify only the home-screen presentation and its tests, plus small composition wiring changes if required. Preserve the existing route-search navigation and controller/repository interfaces.

## Visual direction

- Product name is `BusBuddy`, never `TransitSafe`.
- Calm high-contrast blue and white visual system based on the supplied DESIGN.md.
- Use the existing `AppTheme.light` and Material icons with visible text labels.
- Large spacing, readable hierarchy, cards with clear borders, full-width primary actions, and minimum 48×48 logical-pixel targets.
- Support large text without clipping the primary journey action.

## Home screen content and behavior

1. Header
   - Show `BusBuddy` as the title.
   - Replace separate hamburger/profile actions with one full-width or clearly large action labeled `Settings and accessibility`.
   - The settings action may be visual-only in this slice, but must have a truthful label and not imply a working settings page if none exists.

2. Journey card
   - Heading `Plan your journey`.
   - Origin control labeled `Starting point`; show `Choose starting stop` until selected. Do not silently require GPS.
   - Include a secondary action labeled `Use my current location` only as a clearly marked unavailable/demo affordance or omit it; do not request location permission or claim live location.
   - Destination control labeled `Where to?`; tapping the journey card/primary action must still open the existing `RouteSearchPage`.
   - Show `Depart now` as informational text, not a date input.
   - Primary button label and semantic label: `Search buses` or `Plan a journey`, but keep the existing working `Plan a journey` semantic target so current navigation tests remain valid. Prefer one primary CTA to avoid duplicate competing actions.

3. Active trip card
   - Full-width stacked card labeled `Active trip`.
   - Empty state must say `No active trip` and must not invent bus, ETA, or location data.
   - Include a truthful text explanation that live tracking will appear here when connected.

4. Tickets card
   - Full-width stacked action labeled `My tickets and trip history`.
   - It may be a clearly marked placeholder for this slice, but must not imply ticket data exists.

5. Safety/live location card
   - Full-width stacked action labeled `Live location and safety sharing`.
   - It may be a clearly marked future/demo placeholder and must not request permissions or claim an active share.

6. Voice action
   - Replace the small AI FAB with a prominent full-width action labeled `Talk to BusBuddy`.
   - It may be disabled/demo text in this slice; do not implement speech or Gemini here.

7. Do not add a bottom navigation bar in this MVP home redesign.

## Accessibility behavior

- Keep the top-to-bottom focus order: title → settings → plan heading → starting point → destination → depart-now text → primary journey action → active trip → tickets → safety → voice.
- Use semantic labels that describe the action and current state, not icon names.
- Use `Semantics(header: true)` only for real section headings.
- Use `liveRegion: true` for active-trip/demo availability messaging where appropriate.
- Never rely on icon, color, or status dot alone.

## Tests and report

Use TDD: update/add `test/features/home_page_test.dart` with failing widget tests before implementation. Cover BusBuddy title, settings label, plan journey navigation, no date input, no active-trip message, stacked full-width action labels, and Talk to BusBuddy label. Keep the existing route-search tests passing. Run `dart format lib test`, `flutter analyze`, and `flutter test`. Write the full report to `.superpowers/sdd/2026-08-29-busbuddy-foundation/home-redesign-report.md`. Do not dispatch subagents and do not claim a Git commit.
