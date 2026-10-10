# BusBuddy Whole-App UI Redesign Brief

**Date:** 2026-10-09
**Product:** BusBuddy, an accessible public transport assistant for the VIT Vellore → Katpadi corridor
**Scope:** Android-first visual and usability redesign across the existing app. The web build is a review surface, not proof of Android behavior.

## Goal

Make the whole app easier to scan, understand, and operate while preserving BusBuddy’s existing workflows, accessibility contracts, and brand. The redesign should feel like one product across Home, booking, tickets, live tracking, safety, settings, and voice assistance—not a collection of unrelated screen refreshes.

## What the current app shows

The inspected build was in High Contrast mode. Its existing visual language uses near-black surfaces, gold primary controls, cyan supporting accents, clear SOS red, outlined surfaces, and a persistent Ask BusBuddy action. The app has useful task coverage and large primary controls. The most visible usability issues at phone width are:

- Home shortcut cards and voice prompt chips clip at the screen edge without a strong scrolling cue.
- Settings hub and Home customization rows wrap or truncate titles and descriptions to make room for trailing values and reorder controls.
- The persistent Ask BusBuddy bar can cover lower content on long settings pages and bus results.
- Gemini connection state and microphone capture state compete for attention and can appear contradictory.
- Live tracking puts dense map, trip, and stop information into a long phone page.

These findings come from a visual review of the existing web build at desktop and phone-sized viewports. The Android app, other theme modes, TalkBack, and live telemetry were not verified in that review.

## Design rules

1. **Keep the existing design system.** Build from `AppTheme.colors(context)`, `AppSemanticColors`, and `AppSpacing`. Keep the existing dark, light, and high-contrast themes coherent; do not introduce a new palette or hardcode colors in widgets.
2. **Keep BusBuddy’s color meanings.** Red is reserved for Emergency SOS. Use the active theme’s primary action color for ordinary actions. Status must be conveyed with text or an icon as well as color.
3. **Design for Android touch and scaling.** Interactive targets stay at least 48×48dp. Preserve platform text scaling without clamps; use reflow and scrolling instead of fixed-height content that clips.
4. **Give every screen one clear main action.** Group supporting details beneath it. Use whitespace and alignment before adding more panels, borders, or decoration.
5. **Make sticky actions safe.** Keep Ask BusBuddy available where the current product contract requires it, but add enough bottom inset and scroll padding that it never hides content or focus.
6. **Keep state truthful.** In Gemini Live, show API-key/connection state separately from microphone state. Only label the mic active after capture opens. Keep typing available when voice or connection setup fails.
7. **Use accurate semantics.** Actions should be exposed as buttons, toggles as switches, and selected tabs as selected tabs. Voice status announcements should be concise and must not repeat the assistant’s spoken answer through TalkBack.
8. **Do not change product behavior as part of visual polish.** Preserve ticket math, SOS behavior, navigation, saved-place behavior, native audio ownership, and existing screen state transitions unless a separate behavior change is explicitly agreed.

## Screen-by-screen priorities

### 1. Home — high priority

- Keep the greeting and core actions easy to find.
- Make the suggested-shortcut row’s horizontal behavior obvious, or reflow it so essential labels are never cut off.
- Preserve the distinct Emergency SOS treatment and the existing neutral task-card pattern.
- Keep Home readable at 360dp and 390dp widths, including with larger text.

### 2. Find a Place, bus results, and checkout — high priority

- Preserve the origin → destination → date → bus-search sequence.
- Keep saved places close to the relevant place fields and make the selected place unmistakable.
- Let bus-result cards scan quickly: bus, direction, arrival, fare, and selection action should have a stable hierarchy.
- Ensure the sticky Ask BusBuddy bar never covers a result or its action.
- Keep checkout’s passenger, concession, payment, and exact fare summary readable without making the dialog feel cramped. Keep its demo-payment status explicit.

### 3. My Tickets and ticket details — medium priority

- Make Current Ticket and Previous Tickets selection unmistakable.
- Keep the no-active-ticket state useful and balanced rather than leaving the page feeling empty.
- Prioritize bus, route, date, fare, passenger, and ticket identifier in the boarding pass.
- Preserve the existing QR/demo contract; do not imply that a decorative code is a production validation credential.

### 4. Live location and journey — high priority

- On phones, lead with the map and a compact trip summary, then show next stop and ETA, then the full stop list and secondary actions.
- Keep map controls large and visually separated from map markers.
- Keep data freshness and error/retry states clear. Never invent GPS values when telemetry is missing.
- Make the stop list readable without heavy separators dominating the route.

### 5. Safety and emergency contacts — medium priority

- Keep the SOS action prominent and visually distinct from ordinary actions.
- Keep trusted contacts and call actions easy to identify.
- Make contact add/edit dialogs readable at phone width and with large text.
- Preserve existing confirmation, contact, and sharing behavior; do not trigger alerts during visual redesign.

### 6. Settings hub, accessibility, personalization, and voice settings — high priority

- Rework narrow rows so titles never break mid-word. Put descriptions below titles when the trailing value or switch needs space.
- Keep category grouping, current values, and navigation affordances consistent.
- In Home customization, give each item enough width for its name and description while keeping visibility, reorder, and accessible move controls discoverable.
- Keep long-page content and focused controls clear of the persistent Ask BusBuddy bar.

### 7. Gemini Live assistant — high priority

- Establish a clear order: connection/key status, conversation or response, microphone control and state, then text input and example prompts.
- Distinguish “Gemini connected” from “microphone listening”; one must never imply the other.
- Make the microphone’s current state and its action label clear for off, preparing, listening, speaking/paused, permission denied, and device failure.
- Keep the typing fallback visible and usable in every failure state.
- Make example prompts wrap or scroll intentionally; never leave half a prompt clipped with no cue.
- Preserve the single-speaker contract and existing mic/session logic.

## Suggested implementation order

1. Fix shared phone-width layout patterns: app-bar compression, long-row wrapping, safe-area and sticky-action overlap.
2. Apply those patterns to Home, settings, and Home customization.
3. Refine the booking/results/checkout flow and live tracking information hierarchy.
4. Refine tickets, safety, and Gemini Live using the same shared rules.
5. Review the same screens in dark, light, and high-contrast themes before calling the redesign cohesive.

## Review checklist

- Review at 360×800dp and 390×844dp; check long content by scrolling.
- Review at normal and large platform text scales, including the repo’s 300% contract.
- Confirm no title or action is clipped, no sticky control obscures content, and each main task has one obvious next step.
- Check accessibility semantics for buttons, switches, selected tabs, text fields, and mic state.
- Verify microphone and connection states on actual Android hardware before claiming Android voice behavior is correct.
- Do not claim full accessibility compliance from screenshots alone; use TalkBack and device testing for that.

## Copy/paste prompt for the implementation AI

```text
Redesign the existing BusBuddy Flutter app UI across the whole product using docs/ui/whole-app-redesign-brief.md as the approved design brief.

Before editing, inspect the current app at phone width and review its existing theme, semantic color, spacing, and accessibility contracts. Use the attached screenshots of the current app as the visual baseline. Improve the existing product; do not replace it with a generic transit or voice-assistant template.

Work screen by screen across Home, Find a Place, bus results, checkout, My Tickets, ticket details, live tracking, safety/emergency contacts, settings and their subpages, Home customization, and Gemini Live. Use shared layout patterns so the redesigned screens feel like one app. Fix clipped carousels/chips, mid-word setting titles, truncated customization rows, and sticky Ask BusBuddy overlap. Make the map and stop information responsive on Android phone widths.

Follow the repo’s AppTheme/AppSemanticColors/AppSpacing tokens, preserve all existing workflows and state transitions, keep SOS red exclusive to SOS, retain 48dp touch targets and uncapped platform text scaling, and ensure accessibility semantics describe each control accurately. In Gemini Live, represent API connection and microphone capture as separate states; never show an active-mic state before capture opens, and keep typing available as a fallback.

Do not change ticket calculations, SOS sharing, route behavior, Gemini protocol, Android audio capture/playback, or the single-speaker contract as part of this UI pass. Do not add dependencies or unrelated refactors. Implement in small, reviewable steps, capture the redesigned screens at 360dp and 390dp widths, and report any device-only or TalkBack checks that could not be performed. Do not claim hardware microphone behavior is verified unless it was tested on a physical Android device.
```
