# BusBuddy Navigation and Accessibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve page identity, stop-picker navigation, route speech, announcement ownership, and live-map controls for Android passengers.

**Architecture:** Keep existing Flutter navigation, `AnnouncementCoordinator`, and `ModelVoicePlayer` ownership. Make local UI and semantics changes in existing feature screens; do not create another speech/audio owner or change TalkBack settings.

**Tech Stack:** Flutter/Dart, existing Material widgets, existing theme tokens, and the current native Android voice bridge.

**Spec:** `docs/superpowers/specs/2026-10-18-busbuddy-navigation-accessibility-design.md`

## Global Constraints

- Use `AppTheme.colors(context)`, `AppSemanticColors`, and `AppSpacing` tokens for UI styling.
- Preserve the 48×48 dp touch-target floor and platform text scaling.
- Keep the BusBuddy logo on Home; use page titles on every non-Home page.
- Preserve normal TalkBack focus navigation; do not disable or globally mute Android TalkBack.
- Preserve the single app-owned Gemini voice path and current microphone/session lifecycle.
- Keep picker back actions non-mutating and selection actions unchanged.
- Keep `Expand Map` beside `LIVE MAP WINDOW` as the only expand control and provide one accessible exit action in expanded mode.
- Do not add dependencies or refactor unrelated features.
- Do not add or run automated tests for this task; perform source review and Flutter analysis only. Physical Android/TalkBack verification is deferred until the user reconnects their phone.
- Preserve all pre-existing user changes in the worktree; touch only files required by these tasks.

## Review Focus

- Picker back may accidentally return a null result that the caller interprets as a cleared stop; verify the existing route form retains its selection.
- A route with a missing stop name must not expose `null`, an empty “from to” label, or a raw arrow expression as its spoken text.
- A semantics announcement plus custom TTS can still duplicate a selection; inspect every target call site and leave TalkBack focus reading intact.
- Ticket detail focus labels must remain available even when unsolicited app narration is removed.
- The map widget has its own fullscreen callback; remove entry affordances without leaving multiple exit controls or making expanded mode inescapable.
- Non-Home pages may contain more than one logo use or a title embedded in a logo subtitle; update every live page occurrence while retaining Home branding.

---

### Task 1: Replace non-Home brand marks with page titles

**Files:**
- Keep the Home logo in `lib/features/home/home_page.dart`.
- Replace non-Home `BusBuddyLogo` uses with concise page titles in:
  `lib/features/alerts/alerts_page.dart`,
  `lib/features/journey/journey_page.dart`,
  `lib/features/journey/live_location_screen.dart`,
  `lib/features/navigation/more_page.dart`,
  `lib/features/route_details/route_details_page.dart`,
  `lib/features/route_search/route_search_page.dart`,
  `lib/features/safety/safety_sharing_page.dart`,
  `lib/features/settings/accessibility_settings_page.dart`,
  `lib/features/settings/home_screen_customization_page.dart`,
  `lib/features/settings/personalization_settings_page.dart`,
  `lib/features/settings/settings_page.dart`,
  `lib/features/settings/voice_assistant_settings_page.dart`,
  `lib/features/tickets/my_tickets_page.dart`,
  `lib/features/tickets/ticket_booking_suite_page.dart`, and
  `lib/features/tickets/ticket_details_page.dart`.

**Interfaces:**
- Consumes the existing screen titles and app-bar theme colors.
- Produces page-specific app-bar titles with no non-Home `BusBuddyLogo` instance.

- [x] Inspect each listed app bar and preserve its existing back/action controls.
- [x] Replace the logo widget with the screen’s existing page name, using current theme text styles and keeping responsive title behavior.
- [x] Search `lib/` for remaining `BusBuddyLogo` uses and confirm the only rendered use is on Home; leave the reusable logo widget itself intact.
- [x] Review the diff for title clipping at large text scales and run `git diff --check`.

### Task 2: Add explicit back controls to stop pickers

**Files:**
- Modify: `lib/features/route_search/route_search_page.dart` (`_StopPickerSheet` header).
- Modify: `lib/features/tickets/ticket_booking_suite_page.dart` (`_openOriginPicker` and `_openDestinationPicker` sheets).

**Interfaces:**
- Consumes existing modal routes and stop-selection return values.
- Produces a labeled back control that dismisses the active picker without changing the caller’s current origin or destination.

- [x] Add a 48 dp minimum back button with an accessible label to the route-search picker header; pressing it closes the sheet with no stop result.
- [x] Add the same explicit back action to both booking origin and destination picker headers; pressing it dismisses only that sheet.
- [x] Preserve stop selection, saved-place toggles, search, and existing system-back behavior.
- [x] Review modal constraints for small screens and large text, then run `git diff --check`.

### Task 3: Normalize route speech and remove duplicate unsolicited narration

**Files:**
- Modify route/ticket labels and announcement call sites in `lib/features/route_search/route_search_page.dart`, `lib/features/tickets/ticket_booking_suite_page.dart`, `lib/features/tickets/my_tickets_page.dart`, `lib/features/tickets/ticket_details_page.dart`, and `lib/core/a11y/announcement_coordinator.dart` only as needed.
- Reuse current selection announcement changes already present in the worktree; do not revert or duplicate them.

**Interfaces:**
- Consumes origin/destination `Stop` names, optional bus identity, and the existing `AnnouncementCoordinator` API.
- Produces natural-language route semantics (“from VIT to Katpadi”) while preserving current visible route formatting and normal TalkBack focus reading.

- [x] Trace the actual accessibility label and spoken announcement paths for selected buses, route results, and ticket viewing.
- [x] Provide one route-label formatter or equivalent localized helper, using only available non-empty stop names and optional bus identity.
- [x] Suppress app TTS for events already announced through accessibility semantics where the custom voice is not the intended Gemini reply; do not silence TalkBack or remove focusable ticket labels.
- [x] Confirm Gemini reply audio remains governed by `ModelVoicePlayer` and no second TTS path is added.
- [x] Review all changed call sites and run `git diff --check`.

### Task 4: Leave one live-map expand control

**Files:**
- Modify: `lib/features/journey/live_location_screen.dart`.
- Modify: `lib/features/journey/live_location_map_widget.dart` only if its header currently exposes an additional fullscreen entry/exit control.

**Interfaces:**
- Consumes the existing `_toggleMapExpanded` state transition.
- Produces one `Expand Map` button beside `LIVE MAP WINDOW` and one labeled exit action in expanded mode.

- [x] Remove the AppBar expand toggle and any map-widget control that also enters expanded mode; keep refresh and voice-mute actions.
- [x] Keep `Expand Map` beside the `LIVE MAP WINDOW` heading as the sole entry action.
- [x] Keep a single accessible expanded-mode exit action and verify it remains at least 48 dp.
- [x] Review layout for narrow screens and large text, then run `git diff --check`.

### Task 5: Source review and Android handoff

**Files:**
- Review all files changed in Tasks 1–4.

- [x] Search for non-Home `BusBuddyLogo` usages, duplicate map expand controls, and selection/ticket custom-TTS calls.
- [x] Run `flutter analyze`; expected: no new analyzer errors attributable to this slice.
- [x] Review `git diff --check`; expected: no whitespace errors and no unrelated user changes modified by this work.
- [x] Report that picker/back, TalkBack, large-text, map controls, and route speech need physical Android verification when the user reconnects the device.
