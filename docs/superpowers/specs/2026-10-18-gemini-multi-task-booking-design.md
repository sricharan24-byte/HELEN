# Gemini Multi-Task Booking and Voice Reliability

## Goal

Let a passenger give one spoken request containing a route, bus preference,
passenger details, payment choice, and a post-booking destination. BusBuddy
should validate and execute the request as one coherent app flow, speak only
what the app has actually completed, and open the live map only after the app
has created the ticket.

## Agreed understanding

- The example request is VIT Main Gate to Vellore Fort, choose the earliest
  listed bus, student passenger Pavan, use Wallet, then open the map. “Bello
  Fort” is a likely recognition of the stop “Vellore Fort”; resolve that exact
  known alias and retain a clarification path for other ambiguous locations.
- A complete booking draft is not a booked ticket. Completion must come from
  the checkout callback after ticket creation, not Gemini's interpretation of
  `draftComplete`.
- The current arrival labels (18B: 4 min, 12A: 12 min, 20C: 18 min) are local
  demo estimates. The app has no live departure feed or real payment provider.
  Wallet auto-confirm may issue an in-app demo ticket after the passenger
  explicitly requests Wallet, but must never be described as a real charge.
- Keep the existing Gemini session and the single-speaker audio contract.

## Design

Add a single structured booking-preparation tool for multi-part booking
requests. Gemini extracts the passenger's explicit values into one call; the
app resolves stops, checks the route, selects the earliest bus from the same
available-options source used by the booking screen, and validates every
required field including passenger name. The existing step-by-step tools
remain available for conversational follow-up. Invalid, missing, or ambiguous
values return a bounded clarification result and do not open checkout.

The app returns separate states for draft readiness, checkout pending, and
ticket issued. Gemini instructions and tool metadata must never equate a ready
draft with a completed ticket or payment. The checkout remains the source of
truth: after its ticket-created callback, a request marked “open map” continues
to the map for that exact ticket. For the current Wallet demo path, the app may
auto-issue the demo ticket after the explicit Wallet choice; other methods
retain their existing confirmation flow. User-facing copy identifies the
ticket and arrival data as demo behavior where relevant.

For speech, tool-protocol rounds stay silent. Each final turn chooses one
speaker: use Gemini PCM when it arrives; use app TTS only when the completed
turn contains no model audio. If model playback begins while fallback TTS is
active, stop TTS before queuing PCM. Resume microphone capture only after the
chosen speaker drains. Long text remains visible, while spoken fallback stays
concise and does not announce draft or payment completion prematurely.

## Constraints

- Do not claim live arrival times, a real wallet debit, or a completed ticket
  before the local checkout callback proves the corresponding state.
- Do not select a bus or route that is not present in the app's available data.
- Preserve explicit passenger consent for payment methods that currently
  require confirmation. The user's spoken Wallet choice remains explicit
  authorization for the app's demo Wallet behavior.
- Keep one microphone/audio-session owner and one voice producer per reply.
- Do not add dependencies. Do not add or run tests unless the user asks; use
  formatting, static analysis, Android build, source review, and
  `git diff --check` for verification.

## Acceptance criteria

1. One utterance can fill route, earliest-bus preference, passenger type/name,
   payment method, and the requested post-booking map action in one validated
   booking-preparation call.
2. “Bello Fort” resolves to the known “Vellore Fort” stop; unknown or
   ambiguous stop names receive a clear clarification instead of a guessed
   route.
3. Earliest-bus selection comes from the booking screen's shared available
   options. Demo ETAs are described as estimates, never live data.
4. Passenger name is required before checkout opens. A complete draft is
   described only as ready for checkout, never as booked or paid.
5. The map opens for the exact ticket only after checkout reports ticket
   creation. A failed or cancelled checkout leaves the user in the assistant
   flow and is not reported as success.
6. Tool-protocol turns do not speak. Model PCM and fallback TTS never overlap;
   the microphone resumes after the active reply audio drains.
7. Touched Dart/Kotlin sources format and analyze/build cleanly, with no new
   dependency and no test suite run.
