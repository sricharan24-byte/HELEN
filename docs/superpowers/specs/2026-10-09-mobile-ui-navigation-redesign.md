# BusBuddy Mobile UI and Navigation Redesign

**Status:** Partially implemented — responsive-layout work landed (`52b8ff7`, Chunk 50); the four-destination bottom navigation did not. See the plan's status note in `2026-10-09-mobile-ui-navigation-redesign.md`.

**Date:** 2026-10-09  
**Scope:** Android-first navigation and responsive usability across the existing Flutter app

## Intent

Make BusBuddy's main tasks easy to reach and comfortable to use on a phone, while retaining its accessible transit workflows and existing product behavior. Navigation should be predictable across the app; content should remain legible at narrow widths and large text sizes; no new feature should be added without a demonstrated need.

The inspected app currently uses Home as its main destination. Home cards push separate pages, there is no persistent mobile navigation, and the top-right profile avatar does not respond to taps. The existing screens, ticket and route flows, and settings remain the product baseline.

## Approved direction

Use four persistent top-level destinations:

1. **Home** — existing task-oriented Home, active-trip summary, and prominent Emergency SOS entry.
2. **Plan** — existing booking flow (origin/destination, bus results, checkout, and active-trip step where applicable).
3. **Tickets** — existing current and previous ticket experience.
4. **More** — a compact hub for Safety and trusted contacts, corridor Alerts, and Settings.

The Home profile affordance becomes a functional Settings shortcut. Safety remains quickly reachable both from Home and More. Emergency SOS retains its distinct red treatment and existing confirmation/sharing behavior.

## Navigation behavior

- The four destinations use a Material bottom navigation component with visible labels, selected-state semantics, and touch targets of at least 48 dp.
- Switching destinations preserves each destination's in-progress UI state where practical; it must not recreate a booking form or reset a ticket tab just because the user visited another tab.
- Detail pages such as ticket details, live location, route details, contact editing, and settings subpages continue to open within the selected destination's navigation stack. Android Back returns to the previous page, then to the selected root destination, and exits only from Home.
- Plan opens the existing booking flow at its first step. Navigation must not bypass route selection, checkout, fare calculations, or ticket issuance rules.
- More presents three clearly labeled entries: Safety & Contacts, Corridor Alerts, and Settings. It does not add a new feature area.
- Existing Home shortcut cards remain user-configurable. A shortcut that duplicates a bottom destination may remain as a contextual shortcut on Home, but the design should avoid creating a second competing navigation system or redundant tabs.
- Keep one Ask BusBuddy action on screens that already have it. When integrating existing screens into the shell, remove only duplicate instances caused by composition; do not remove the app's established voice entry points or alter audio/session behavior.

## Mobile layout requirements

- Support 360×800 dp and 390×844 dp widths without clipped titles, mid-word wrapping, hidden actions, or content under fixed controls.
- Long pages scroll through their final content and focused controls; sticky actions receive matching bottom inset/scroll padding.
- Cards and rows reflow instead of imposing fixed heights. Preserve platform text scaling without artificial clamps, including the repository's 300% scaling requirement.
- Home shortcuts and Gemini example prompts wrap or scroll with an obvious affordance; no essential label is cut off.
- Settings and Home customization place titles and descriptions in a flexible vertical column. Trailing switches, values, and reorder actions keep 48 dp hit areas and may wrap below the text when width is constrained.
- Booking results show the bus/route, time, fare, and primary selection action in a stable hierarchy. The sticky Ask BusBuddy action must not obscure a result or checkout control.
- Live tracking prioritizes map, concise journey summary, next stop/ETA, then the full stop list. Data freshness, no-data, and retry states remain honest.
- Ticket and safety screens retain their existing actions and state transitions while reflowing for phones and large text.

## Visual and accessibility constraints

- Use `AppTheme.colors(context)`, `AppSemanticColors`, and `AppSpacing`; preserve dark, light, and high-contrast themes.
- Keep red reserved for Emergency SOS surfaces. Use text/icons as well as color for state.
- Preserve 48×48 dp minimum interactive targets and accurate button, switch, tab, heading, and status semantics.
- Do not add fixed-height content that clips with larger text. Respect Android system Back, safe areas, keyboard insets, and focus visibility.
- Do not change fare arithmetic, route logic, saved-place persistence, ticket/payment behavior, SOS behavior, Gemini protocol, microphone permissions/capture, audio playback, single-speaker ownership, or telemetry semantics.

## Scope boundaries and removal policy

- No new product feature is planned. Improve discoverability using existing screens and actions.
- Do not delete configurable shortcuts or settings based only on visual preference. Consolidate navigation paths and remove only genuinely inert/duplicated UI (the nonfunctional profile avatar becomes a real Settings shortcut; duplicated controls created by the new shell may be removed).
- Keep all current app features reachable, including Safety, Alerts, Personalization, Accessibility, Voice Assistant settings, and Gemini Live.

## Implementation areas

- `lib/main.dart` and `lib/features/home/home_page.dart`: establish the top-level destination shell while retaining Home behavior and existing dependencies.
- Reuse the existing booking and ticket pages for Plan and Tickets rather than duplicating their business logic.
- Add or adapt a More hub using existing Safety, Alerts, and Settings destinations.
- Apply narrow-width and sticky-action fixes to the affected existing screens, including settings, customization, booking/results, ticket, journey, safety, and Gemini Live surfaces.
- Keep changes localized to UI composition/layout; avoid dependency additions and broad domain/controller refactors.

## Acceptance criteria

1. Home, Plan, Tickets, and More are visible and reachable from the app's primary phone navigation.
2. Home, booking, tickets, and settings state survive normal top-level tab switching.
3. Android Back follows the nested-page/root behavior defined above.
4. Safety and SOS are reachable from Home and More; SOS retains its existing red semantics and confirmation behavior.
5. All previously existing product features remain reachable, and duplicate shell composition does not produce two Ask BusBuddy controls on one screen.
6. At 360×800 and 390×844, representative screens have no clipped essential content or obscured actions at normal and large text scales; 300% text scale still reflows and scrolls.
7. Dark, light, and high-contrast modes use existing tokens consistently; no ordinary action uses SOS red.
8. The changes do not alter route, fare, ticket, emergency, Gemini, microphone, or audio ownership behavior.
9. Browser/desktop screenshots may validate layout, but Android Back, TalkBack, and microphone behavior are only claimed after checking on a physical Android device.

## Verification plan

- Inspect representative screens at 360×800 and 390×844 in dark, light, and high-contrast themes.
- Review narrow layouts with large and 300% text scaling, keyboard open, and long content scrolled to its end.
- Check keyboard focus, selected navigation semantics, and Android Back with a physical device or emulator; use TalkBack for a semantics pass.
- Run repository static analysis and the focused widget tests for navigation/layout only if requested by the user, per current task instructions.
- Report any checks that need a physical device separately; do not infer microphone correctness from visual review.
