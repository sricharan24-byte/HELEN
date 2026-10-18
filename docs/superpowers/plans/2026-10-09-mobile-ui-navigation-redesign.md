# BusBuddy Mobile UI and Navigation Implementation Plan

> [!NOTE]
> **Status (2026-10-18): Task 1 landed; Tasks 2–3 landed earlier; Task 4 open.**
>
> * **Task 1 (four-destination shell) — built 2026-10-18**: `AppNavigationShell` now holds Home / Plan / Tickets / More in an `IndexedStack` of per-destination nested `Navigator`s (lazy first build, state preserved across tab switches). More wires in the previously orphaned `lib/features/navigation/more_page.dart`. System Back pops the active destination's stack, then returns to Home, and exits only from the Home root. `TicketBookingSuitePage` (Plan) and `MyTicketsPage` (Tickets) are rooted with `showBackButton: false`.
> * **Deviations from this plan, deliberately**: destinations build lazily on first visit instead of all at startup (avoids startup work and hidden-page finder collisions); `NavigationBar` labels carry Flutter's built-in `_kMaxLabelTextScaleFactor` cap (framework behaviour for nav labels only — no repo-level clamp); tests *were* added (`test/features/app_navigation_shell_test.dart`, 3 cases) despite the constraint below, because CI runs `flutter test` and the shell's back/state contract needs a pin. No Home profile affordance exists in the current `home_page.dart`, so "route Home profile to Settings" had nothing to route; Settings stays reachable as a Home card and a More entry.
> * **Tasks 2–3** landed in `52b8ff7` (2026-10-10) and the Chunk 50 design-contract pass: home, settings hub, home-screen customization, accessibility/personalization/voice settings (`settings_ask_bus_buddy_bar.dart`), booking suite, My Tickets, live location, safety sharing, Gemini prompt chips. `docs/ui/whole-app-redesign-brief.md` was the brief.
> * **Task 4 remains open**: no rendered-width review was recorded at 360×800 / 390×844, and no browser screenshot pipeline is available in the current environment (no puppeteer). Widget coverage renders the shell at 320 dp / 300 % (`platform_text_scaler_test`) and pins tab/back/state behaviour, but a human visual pass at phone widths is still owed.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make BusBuddy's core mobile tasks easier to navigate and use, with responsive layouts across existing screens.

**Architecture:** Add a persistent four-destination shell (Home, Plan, Tickets, More) and retain feature screens and their existing navigation behavior. Apply localized responsive fixes to the most crowded mobile layouts; keep domain, ticket, emergency, telemetry, and voice-session behavior unchanged.

**Tech Stack:** Flutter/Dart, existing Material widgets and app token system.

**Spec:** `docs/superpowers/specs/2026-10-09-mobile-ui-navigation-redesign.md`

## Global Constraints

- Use existing `AppTheme.colors(context)`, `AppSemanticColors`, and `AppSpacing` tokens.
- Keep red reserved for Emergency SOS.
- Preserve 48×48 dp touch targets and platform text scaling, including 300% reflow.
- Preserve ticket/fare, route, saved-place, SOS, Gemini protocol, microphone/audio ownership, and telemetry behavior.
- Add no dependency and no unrelated refactor.
- Do not add or run tests for this task; perform source review and available static/layout checks only.

## Review Focus

- Narrow or large text widths could squeeze the bottom navigation label; use visible labels and safe reflow.
- Root-level callbacks could accidentally push detail pages above or outside the selected destination stack.
- Top-level tab changes could recreate booking/ticket state.
- Fixed sticky actions could cover the last control or keyboard-focused content.
- Home/More duplication could make SOS hard to find or introduce ordinary red actions.

---

### Task 1: Four-destination app shell

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/features/home/home_page.dart`
- Create: `lib/features/more/more_page.dart` (only if no existing reusable More hub fits)

**Interfaces:**
- Consumes existing `HomePage`, `TicketBookingSuitePage`, `MyTicketsPage`, `SettingsPage`, `SafetySharingPage`, and `AlertsPage`.
- Produces a stateful app root with Home, Plan, Tickets, and More destinations; selected destination is exposed to Material navigation with labels and selected semantics.

- [x] Build the four root destinations using existing feature screens and preserve their state during normal destination changes.
- [x] Route Home profile to Settings and expose Safety/Contacts, Alerts, and Settings from More. *(No Home profile affordance exists in the current Home; the More exposure is what applied.)*
- [x] Keep Emergency SOS visible on Home and inside More, using the existing safety flow.
- [x] Route existing detail pushes through the correct selected destination context; preserve Android Back hierarchy.
- [x] Review the resulting source and run `git diff --check`; expected: no whitespace errors and no user changes modified outside the task.

### Task 2: Home, settings, and sticky mobile layout

**Files:**
- Modify: `lib/features/home/home_page.dart`
- Modify: `lib/features/settings/settings_page.dart`
- Modify: `lib/features/settings/home_screen_customization_page.dart`
- Modify only affected sticky layouts in: `lib/features/settings/accessibility_settings_page.dart`, `lib/features/settings/personalization_settings_page.dart`, and `lib/features/settings/voice_assistant_settings_page.dart`

**Interfaces:**
- Uses the existing shell from Task 1; introduces no new state or data model.

- [ ] Reflow Home shortcut content and make profile/shortcut actions usable at 360 dp.
- [ ] Rework settings hub and customization rows so labels do not split mid-word or disappear behind controls.
- [ ] Add sufficient scroll/safe-area padding where fixed Ask BusBuddy controls currently cover content.
- [ ] Review token usage, text scaling, and 48 dp targets; run `git diff --check`.

### Task 3: Booking, journey, tickets, and voice prompt layout

**Files:**
- Modify only affected responsive/sticky layouts in: `lib/features/tickets/ticket_booking_suite_page.dart`, `lib/features/tickets/my_tickets_page.dart`, `lib/features/tickets/ticket_details_page.dart`, `lib/features/journey/live_location_screen.dart`, `lib/features/safety/safety_sharing_page.dart`, and `lib/features/ai_assistant/gemini_live_screen.dart`

**Interfaces:**
- Uses existing route, ticket, SOS, audio, microphone, and Gemini behavior without altering their contracts.

- [ ] Ensure booking results and checkout controls remain reachable above sticky actions.
- [ ] Make journey details and stop list readable after the map at narrow widths.
- [ ] Reflow ticket and safety content for phones and large text without changing actions.
- [ ] Make Gemini prompt chips wrap or scroll intentionally; do not edit microphone/session/protocol/audio code.
- [ ] Review complete diff, search for hardcoded colors or text-scaler clamps in changed UI, and run `git diff --check`.

### Task 4: Visual review and handoff

**Files:**
- Review: all files changed in Tasks 1–3.

- [ ] Inspect at 360×800 and 390×844 where the local web build can represent the layout; review dark/light/high-contrast tokens by source and available app settings.
- [ ] Check that Home, Plan, Tickets, More, Settings, SOS, booking, and live journey remain reachable and that no tab switch resets retained state.
- [ ] Report Android Back, TalkBack, 300% scaling, and physical microphone checks that could not be exercised in the available environment.
- [ ] Run final `git diff --check`; expected: clean.

