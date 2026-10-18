# BusBuddy Navigation and Accessibility Design

## Goal

Make the existing Android-first BusBuddy flows clearer and more accessible by keeping the BusBuddy brand mark on Home, giving stop pickers explicit back navigation, improving route speech, preventing duplicate app-generated speech over TalkBack, and leaving one map expand control.

## Agreed understanding

- The app is primarily optimized for Android; the user will reconnect a phone and test after the work is complete.
- Keep the BusBuddy logo on Home and remove it from other pages, where each page should show a concise page title.
- Origin and destination stop selection need a clear way to return to the previous screen.
- Route names such as `VIT -> Katpadi` should be spoken as “from VIT to Katpadi.”
- Native TalkBack remains available for normal focus and navigation. The app must not add a second spoken copy of the same selection or ticket content through its custom voice.
- In the live map window, keep the single `Expand Map` control beside the `LIVE MAP WINDOW` heading and remove duplicate expand controls.
- The custom Gemini voice remains the only app-owned voice for Gemini replies, consistent with the existing single-speaker contract.

## Scope

This first implementation slice covers:

1. BusBuddy branding and page titles across non-Home pages.
2. Back navigation from origin and destination stop pickers.
3. Spoken route labels for route and ticket selection.
4. Selection and ticket announcements that do not duplicate TalkBack speech with app TTS.
5. A single map expand control in the live-location page.

The user’s broader request is staged into follow-on designs after this slice: (a) one-time GPS share/SOS and dialer handoff, then (b) Gemini action-screen behavior and visual polish. This spec does not cover those follow-on implementations.

## Design

### Branding and navigation

Home retains the BusBuddy logo. Other pages use their meaningful page title in the app bar instead of the logo (for example, `My Tickets`, `Live Location`, or `Settings`). Use the existing theme and spacing tokens; do not introduce new image assets or hard-coded colors as part of this change.

Both stop-picker flows expose an accessible back arrow in the picker header. Activating it closes the picker and returns to the current route form without changing the selected stop. Selecting a stop continues to return the selection to its caller and close the picker as today.

### Spoken route labels and announcement ownership

Route text exposed to accessibility services is normalized to the natural-language form “from {origin} to {destination}.” The visible route text may keep its current visual arrow format. Bus identity remains available in the same accessible label where relevant.

TalkBack stays in control of its normal focus-based reading. For app events that already receive an accessibility announcement and custom speech, the event must not be spoken by both TalkBack and app TTS. Use the existing `AnnouncementCoordinator` and single-speaker voice ownership rather than introducing another speech engine or muting Android TalkBack globally. Ticket details remain readable through ordinary TalkBack focus; opening or viewing a ticket must not cause a second unsolicited app-TTS narration.

### Live map controls

Keep `Expand Map` beside `LIVE MAP WINDOW` as the one control that enters expanded map mode. Remove other controls that also enter expanded mode. Expanded mode retains one clear, accessible exit action. Ensure the remaining control meets the repository’s 48 dp target and theme-token requirements.

## Error and lifecycle behavior

- Picker back closes only the picker; it does not discard the route form or mutate origin/destination.
- Route semantics gracefully use the available origin/destination names; missing values are not rendered as the literal string `null`.
- Changing pages or leaving a picker must not start or resume custom TTS unexpectedly.
- Existing Gemini audio behavior remains governed by `ModelVoicePlayer` and the single-speaker contract.
- Map expansion and exit remain usable with touch and TalkBack, including when large text scaling is enabled.

## Acceptance criteria

1. Home still displays the BusBuddy logo; non-Home app bars display page titles without that logo.
2. Origin and destination pickers each have a labeled back control that returns to the prior form and leaves the current selection unchanged.
3. A selected `VIT -> Katpadi` route is announced as “from VIT to Katpadi,” with bus identity included when present.
4. With TalkBack enabled, selection and ticket content can be read on focus, while the app does not also issue duplicate unsolicited TTS for the same event.
5. Gemini replies still use one app-owned voice path per turn.
6. The live map window has exactly one expand control beside its heading and one exit action in expanded mode.
7. Existing behavior for route selection, ticket access, and map data remains intact.

## Verification

Use focused Flutter analysis and relevant existing widget/accessibility checks after implementation. Add or update coverage for picker back behavior, route semantics, announcement ownership, and the map control count. Manual Android verification with TalkBack is needed after the user reconnects their phone; no emulator or web run is a substitute for that check.

## Known constraints

- The current worktree already contains unrelated user changes. Any design-document commit must stage only this spec file.
- The connected Android device is currently disconnected; device verification is deferred until the user reconnects it.
- This spec does not authorize global TalkBack changes or a second custom voice path.
