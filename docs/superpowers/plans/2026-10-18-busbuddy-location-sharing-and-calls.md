# BusBuddy One-Time Location Sharing and Calls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable one-time phone GPS sharing for Share Location and confirmed SOS, and open the dialer with an emergency contact number prefilled.

**Architecture:** Add a small Android method-channel capability that requests location permission just in time, obtains a bounded one-shot coordinate, opens `ACTION_SEND` choosers, and launches `ACTION_DIAL`. A Dart service validates native responses and builds map links; existing safety and live-location screens own explanatory UI and user confirmation.

**Tech Stack:** Flutter/Dart, Android Kotlin, Android `LocationManager`, Android intents, existing Material UI and theme tokens.

**Spec:** `docs/superpowers/specs/2026-10-18-busbuddy-location-sharing-and-calls-design.md`

## Global Constraints

- Target Android first; do not add a location, sharing, or URL-launch package.
- Request coarse/fine location only after the user starts a share or confirms SOS; provide an in-app explanation before the system permission prompt.
- Use a bounded one-shot phone location and `https://maps.google.com/?q=<latitude>,<longitude>`; never use simulated bus telemetry as the passenger coordinate.
- Never persist coordinates or start background location updates.
- Keep SOS confirmation; no automatic message, call, or dispatch.
- Use `ACTION_SEND` chooser for share and SOS; describe chooser launch separately from message delivery.
- Use `ACTION_DIAL` with a `tel:` URI; do not request `CALL_PHONE` or place a call automatically.
- Preserve existing user changes and use app theme tokens and 48 dp minimum touch targets.
- Do not add or run automated tests for this task; use source review, `flutter analyze`, and `git diff --check`. Defer physical Android permission, share, and dialer checks until the user reconnects their phone.

## Review Focus

- Permission results must reach the location channel and retain the existing voice-channel routing; each channel must ignore request codes it does not own.
- Approximate-only access must produce a usable one-shot map link, and denied/permanently denied access must not fall back to fixture bus coordinates.
- A location timeout/provider-disabled response must clear pending callbacks and timers and return an honest UI state.
- The share chooser can be canceled; the app must not say the message was sent.
- SOS cancel must request no permission; SOS continue must include emergency wording and the one-time coordinate link.
- Invalid or absent contact numbers must not launch a malformed `tel:` URI or crash the safety page.
- Non-Android calls must return an explicit unsupported result instead of a fake success.

---

### Task 1: Add the native Android location and intent channel

**Files:**
- Create: `android/app/src/main/kotlin/com/busbuddy/app/BusBuddyLocationShareChannel.kt`.
- Modify: `android/app/src/main/kotlin/com/busbuddy/app/MainActivity.kt`.
- Modify: `android/app/src/main/AndroidManifest.xml`.

**Interfaces:**
- Consumes method-channel requests `getCurrentLocation`, `shareText`, and `openDialer`.
- Produces structured location results (`success` with latitude/longitude, or bounded error status), opens an Android text-share chooser, and opens the dialer with a validated number.

- [x] Declare coarse and fine location permissions with manifest comments explaining just-in-time foreground use; do not add call or background permissions.
- [x] Implement one-shot location acquisition with a 15-second timeout, permission checks, approximate-location support, provider-disabled detection, and listener/timer cleanup.
- [x] Implement `ACTION_SEND` plus `Intent.createChooser` for plain text and `ACTION_DIAL` using `Uri.fromParts("tel", normalizedNumber, null)` after number validation.
- [x] Attach and dispose the channel from `MainActivity`; forward permission results to both channels, with each channel filtering its own unique request code and preserving voice permission routing.
- [x] Ensure pending method results complete exactly once on grant, denial, timeout, unsupported location, chooser/dialer launch, and activity teardown; run `git diff --check`.

### Task 2: Add a Dart service for location, link, share, and dialer results

**Files:**
- Create: `lib/core/location/location_share_service.dart`.
- Modify: `lib/core/di/service_locator.dart` only if the existing locator pattern requires registration; avoid registration if a direct stateless service is sufficient.

**Interfaces:**
- Produces `Future<LocationShareResult> shareCurrentLocation({required String message, required String chooserTitle})` and `Future<DialerResult> openDialer(String phoneNumber)`.
- Encodes native status strings into typed results, constructs the Maps URL from the returned coordinate, and never stores location data.

- [x] Implement typed success/denial/disabled/timeout/unavailable/unsupported results and method-channel parsing with safe unknown-status handling.
- [x] Build the map URL with invariant decimal coordinate formatting and append it to the supplied message only after successful location acquisition.
- [x] Expose the Android share chooser and dialer operations through the same service; return unsupported on platforms without the native channel.
- [x] Run `git diff --check` and review that no location value is written to settings, tickets, logs, or analytics.

### Task 3: Wire Share Location, SOS, and emergency contact calls

**Files:**
- Modify: `lib/features/safety/safety_sharing_page.dart`.
- Modify: `lib/features/journey/live_location_screen.dart`.

**Interfaces:**
- Consumes the Dart service from Task 2 and existing contact/ticket models.
- Produces current-location share chooser actions, confirmed SOS sharing, dialer handoff, and honest user feedback for every result.

- [x] Add a brief accessible location-use rationale before requesting permission from Share Location or confirmed SOS.
- [x] Replace the logging-only SOS success action with the location share chooser after confirmation; cancellation performs no permission or share work.
- [x] Replace placeholder WhatsApp/SMS snackbars with the Android chooser and a one-time map URL; preserve any active ticket bus/origin/destination as plain message context.
- [x] Replace contact call snackbars with `openDialer`, using the selected contact’s number; show a clear message for invalid numbers or unsupported platforms.
- [x] Replace the fake `busbuddy.app/track/<ticketId>` live-tracking URL and “live” copy with a one-time phone GPS link and explicit snapshot wording.
- [x] Show distinct outcomes for chooser opened, permission denied, location unavailable/disabled, timeout, and unsupported platform without claiming a message was sent; run `git diff --check`.

### Task 4: Static verification and Android handoff

**Files:**
- Review all files changed in Tasks 1–3.

- [x] Review permission routing, one-shot cleanup, URI validation, chooser cancellation copy, and absence of location persistence/background behavior.
- [ ] Run `flutter analyze`; blocked because the configured Flutter SDK is read-only in this environment. Targeted `dart analyze` passed with no issues.
- [x] Run `git diff --check`; no whitespace errors.
- [ ] Report physical Android checks still needed: approximate/granted/denied permission, location disabled/timeout, share chooser open/cancel and recipient link, SOS cancel/continue, and dialer prefill.
