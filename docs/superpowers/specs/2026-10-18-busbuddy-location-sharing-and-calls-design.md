# BusBuddy One-Time Location Sharing and Calls Design

## Goal

Make Share Location, SOS, and emergency contact calls perform their promised Android actions using the passenger’s current phone location and Android’s native share/dialer surfaces.

## Agreed understanding

- Location sharing uses a one-time GPS snapshot and a standard Google Maps URL; there is no tracking backend and no live-updating link.
- Share Location and confirmed SOS open Android’s share chooser so the passenger chooses an app and recipient.
- The recipient can open the shared map URL and see the sender’s coordinate at the time of sharing.
- Call opens the dialer with the selected number prefilled; the passenger places the call themselves.
- Android is the primary target; the user will reconnect a physical phone for final verification.

## Scope

This slice covers GPS permission and one-time coordinate acquisition, share text generation, the Android share chooser, the confirmed SOS share path, and opening the Android dialer with a contact number. It replaces simulated “Opening WhatsApp…” and logging-only SOS behavior.

It does not add live tracking, background location, automatic SMS/calls, an emergency dispatch service, a recipient web page, a database, or a backend.

## Design

### Android integration

Use a focused native Android capability on the existing MainActivity method-channel pattern. Do not add a Flutter package for capabilities already provided by Android. A single request obtains a current location for sharing; do not reuse demo bus telemetry, store coordinates, or continue sampling after the share text is composed.

Request `ACCESS_COARSE_LOCATION` and `ACCESS_FINE_LOCATION` only when the passenger selects Share Location or confirms SOS. Show a short in-app explanation before the Android permission prompt. Handle granted, approximate-only, denied, permanently denied, location disabled, timeout, and unavailable-provider cases with clear retry/settings guidance. Do not state that a share was sent when Android only opened the chooser.

Use `ACTION_SEND` with `text/plain` content and `Intent.createChooser` for both normal sharing and SOS. The map link uses the current phone coordinate in a URL such as `https://maps.google.com/?q=<latitude>,<longitude>`. Normal sharing may include the active bus and stop names as plain context, but must call this a location snapshot. SOS text identifies it as an emergency and includes the same one-time map URL. The user selects the sharing app and recipient and confirms sending there.

### Calls

Use `ACTION_DIAL` with an encoded `tel:` URI containing the chosen contact’s normalized phone number. Do not request `CALL_PHONE`, place the call automatically, copy to the clipboard, or tell the user a call was placed. If the number is absent or malformed, keep the passenger on the safety page and show an actionable message.

### UI behavior

Share Location reads a fresh GPS snapshot and opens the Android chooser. Confirmed SOS uses the same flow with emergency wording; cancelling the SOS confirmation does not request location. Call opens the system dialer. All buttons preserve accessible names, theme tokens, and 48 dp targets.

The current `https://busbuddy.app/track/<ticketId>` demo link must be removed because it is not a live tracking service. Copy and status text must describe a one-time snapshot honestly.

## Error and privacy behavior

- No permission request occurs until a sharing action is chosen.
- Denial or disabled location does not silently fall back to simulated coordinates or stale demo bus telemetry.
- No coordinates are persisted in settings, tickets, analytics, or logs.
- Location acquisition is one-shot and bounded by a timeout; leaving the screen cancels pending work where possible.
- Share chooser cancellation is a normal outcome and is not reported as successful sending.
- SOS keeps its explicit confirmation step; no message or call is sent automatically.

## Acceptance criteria

1. Share Location requests permission at the time of use, obtains the phone’s current coordinate, and opens the Android share chooser with a valid map URL.
2. A recipient opening that URL can view the coordinate on a map; it is clearly a one-time snapshot, not live tracking.
3. Confirmed SOS opens the same chooser with an emergency message and one-time map URL; cancelling confirmation requests no permission and shares nothing.
4. Location denial, approximate-only access, disabled location, timeout, and missing providers produce honest, actionable UI without substituting demo bus coordinates.
5. Each emergency contact Call action opens Android’s dialer with that contact’s number prefilled and requires the passenger to place the call.
6. No `CALL_PHONE` permission, automatic SMS, background tracking, or backend is introduced.
7. Web/non-Android platforms show a clear unsupported action state instead of an inert success message.

## Verification

Run Flutter analysis and source checks. Physical Android verification must cover permission grant/denial, approximate location, share chooser open/cancel, recipient link resolution, dialer prefill, and SOS confirmation cancel/continue. Do not claim the GPS or chooser flow is physically verified until the user reconnects their phone.

## Known constraints

- The app currently declares no location permission and has no location, sharing, or URL-launch dependency. Permission and native intent support must be introduced together.
- `BusLocation` is fixture/demo bus telemetry and is not the passenger’s phone location.
- The repository already contains user edits; preserve them and stage no unrelated changes.
