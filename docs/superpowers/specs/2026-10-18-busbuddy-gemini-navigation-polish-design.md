# BusBuddy Gemini Navigation and Brand Polish

## Goal

Make Gemini-triggered actions land on the matching BusBuddy screen while the existing live assistant session stays mounted and ready to resume listening after its reply. Refine the Home-only BusBuddy mark to use the app’s theme and accessible brand colors.

## Agreed understanding

- Existing action routes already push destination pages above `GeminiLiveScreen`; the assistant screen must remain mounted underneath so its single audio owner and session survive navigation.
- The `emergency_sos` action must open the Safety page’s explicit confirmation flow. It must not announce that an SOS was sent.
- The one-time location chooser and dialer behavior from the prior slice remain the only external sharing/calling paths.
- Keep the BusBuddy logo only on Home, with a compact transit mark and theme-driven colors.
- Do not create another microphone, TTS, or audio owner. Preserve the current one-speaker and microphone-state contracts.

## Design

Assistant actions continue to push into the current navigator, leaving the full-screen Gemini route alive below the destination. Existing booking, route search, tracking, location sharing, and Home customization mappings remain. Add the missing emergency action mapping to the Safety page so the passenger can review and confirm the SOS share. Update the spoken fallback and action label to describe a confirmation step, not a completed broadcast.

The Home logo becomes a compact transit mark beside the wordmark. Use `AppTheme.colors(context)` and spacing/radius tokens; keep semantics as a single “BusBuddy” label and preserve large-text behavior. No other page receives a logo.

## Constraints

- Do not change Gemini transport, microphone lifecycle, `ModelVoicePlayer`, or TTS ownership.
- Do not auto-send SOS or location messages.
- Do not introduce hardcoded colors, external visual assets, or new dependencies.
- Do not add or run tests unless the user asks; use targeted Dart analysis, formatting, source review, and `git diff --check`.

## Acceptance criteria

1. Saying or selecting the Gemini SOS action opens Safety and asks the passenger to confirm before requesting location.
2. The Gemini screen remains mounted underneath pushed destinations, so its existing live session and microphone lifecycle are not torn down by navigation.
3. Spoken and on-screen action copy does not claim that an SOS was already sent.
4. The BusBuddy logo remains on Home only, uses theme tokens, and has one screen-reader label.
5. Touched Dart files format and analyze cleanly; no new dependency or audio producer is added.
