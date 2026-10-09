# Gemini Live Booking Personalization Design

## Goal

Make voice booking feel more natural and reduce repetitive questions by letting Gemini Live use passenger-approved profile preferences, recent app activity, and the current booking draft. The passenger remains in control of every booking decision and must review and confirm checkout.

## Current state

- `AppSettingsController` persists preferred language, voice speed, voice confirmations, accessibility presentation settings, and saved place stop IDs in `busbuddy.settings.v1`.
- `TicketController` exposes current and historical tickets. The local repository seeds demo history, so demo records must not be treated as the passenger's actual history.
- `AppAutomationController` keeps an in-memory booking draft and currently defaults passenger type to general and payment to UPI. Its readiness check requires a trip and an explicitly selected passenger type, but not an explicitly selected payment method.
- `GeminiLiveSession` sends a static system instruction and tool declarations during setup. Tool responses currently contain generic metadata rather than verified operation results.
- There is no passenger profile model or profile editor.

## Proposed user experience

Add a Booking Profile section under Settings with:

- Optional preferred name.
- Optional default passenger type (general, student, or senior).
- An opt-in “Use profile and recent trips for voice booking” control, off by default, that explains relevant details are sent to Gemini after a booking request.
- Accessibility-aware communication derived from existing language, voice speed, voice confirmation, text size, and contrast settings. Do not add medical or diagnostic fields. Do not infer a disability from settings.

During a booking, the assistant may greet the passenger by their preferred name, suggest a saved or recent route, and prefill an explicitly saved passenger default. It should identify suggestions as coming from saved preferences or recent trips, and ask when context is missing, ambiguous, or conflicting. The passenger can correct any value naturally. Accessibility preferences shape the pace, language, verbosity, and spoken confirmation style; they never silently change the route, passenger type, payment, or other booking choice.

The existing checkout remains the review boundary. The assistant must summarize the selected trip, bus, passenger type, fare, and payment method, open checkout, and never claim a ticket was issued or payment completed before the passenger confirms in the app.

## Context sent to Gemini

Do not put profile or history details in the general Live system instruction. After Gemini identifies a clear booking intent, it may call a new read-only `get_booking_context` tool. The app builds a compact, typed response from local state and returns it through that tool's response. This keeps generic assistant sessions free of profile/history context and avoids reconnecting the microphone session merely to pass personal data. The context is a one-time snapshot for the current booking attempt; if settings change before checkout, the app updates its local draft and visible review, and new context can be requested if the user asks to restart or change the booking. Include only:

- Preferred name, only when personalization is enabled and a name is present.
- Explicit default passenger type, only when enabled and set.
- Language and communication settings needed for an accessible conversation.
- Saved stop names resolved from known stop IDs.
- At most three most recent non-demo ticket summaries, limited to origin, destination, bus, and passenger type. Do not include ticket IDs, QR payloads, fare/payment details, timestamps, or contact details.
- Current booking draft values and which values were explicitly supplied by the passenger versus suggested/defaulted.

Do not send the entire settings snapshot, full ticket objects, API keys, emergency contacts, precise location, or unrelated conversation data. Do not create server-side memory. Context is scoped to a single booking attempt and is requested only after booking intent is established. If personalization is disabled, return no profile, accessibility-setting, saved-place, or recent-history fields; the tool may still return current draft facts needed to continue that booking. If data is unavailable, the existing non-personalized flow continues.

## Booking dialogue and decision rules

1. Use explicit profile defaults to reduce questions, but describe a default when applying it (for example, “I have your usual student ticket selected; you can change it”).
2. Treat recent route history and saved places as suggestions, not authorization. Ask a short confirmation before using a suggested route when the current utterance does not clearly request it.
3. Track provenance for each draft slot: passenger-provided, profile default, recent-activity suggestion, or app default. Only passenger-provided values and explicit profile defaults may satisfy required booking slots; an app fallback must not masquerade as a passenger choice. A saved passenger default can prefill the draft, but the assistant must disclose it and the checkout must visibly show it for review.
4. Require explicit passenger type and payment choice before opening checkout. Remove implicit UPI as a readiness-satisfying choice; if payment is unset, ask which supported method to use.
5. Corrections replace the relevant draft slot and the assistant restates the updated value. Ambiguous place names or unsupported stops trigger a clarification rather than selecting the closest guess.
6. Before checkout, present a concise spoken summary and an equivalent visible summary. Checkout remains the authoritative confirmation surface.

## Data and component boundaries

- Extend `AppSettingsController` with validated optional profile fields and the personalization preference, preserving its existing local persistence contract and excluding Gemini API keys as today.
- Add a focused context builder that accepts settings, saved stops, ticket history, and the current draft, and returns a minimal immutable context. It must filter demo tickets and redact excluded ticket fields before any serialization.
- Update `AppAutomationController` to represent slot provenance and explicit required-field readiness, including payment.
- Add a read-only `get_booking_context` tool that is available in the Live session but is called only after clear booking intent. Refactor tool dispatch to return the actual validated application result to Gemini rather than the current generic success envelope. Keep booking mutations and checkout confirmation in the existing screen/controller boundaries.
- Update the Live system instruction to describe when to request booking context, how to cite whether a suggestion came from a saved preference or recent trip, ask before uncertain defaults, honor corrections, and avoid claiming unsupported live data.
- Keep profile editing in Settings and use existing design tokens, accessibility semantics, and 48dp touch targets.

## Failure handling

- Invalid or missing profile values are ignored and the generic conversation continues.
- Stale saved stop IDs are skipped; if there is no valid suggestion, ask the passenger for origin and destination.
- Empty/non-demo history produces no history suggestion; seeded demo tickets are never surfaced as personal history.
- Context retrieval is unavailable outside a booking flow; a generic voice conversation never sends profile or ticket-history details.
- If the model ignores context or returns an invalid tool argument, the app validates the value, does not advance the draft, and asks the passenger to clarify.
- The UI remains usable when Live is unavailable; this design does not change Android microphone behavior or introduce a second speech owner.

## Acceptance criteria

- A passenger can edit or clear their preferred name and default passenger type in Settings.
- Personalization is off by default, can be disabled at any time, and disabled mode omits profile, accessibility-setting, saved-place, and recent-history fields from the booking-context tool response.
- Context serialization contains only the allowlisted fields; tests prove API keys, demo tickets, ticket identifiers, payment data, QR data, precise location, and emergency contacts are excluded.
- The assistant can suggest a saved/recent route, accept corrections, and ask only for genuinely missing required booking details.
- No defaulted or merely suggested payment/passenger slot can silently pass readiness; checkout requires trip, bus, passenger type, and payment method.
- Checkout still requires the passenger's explicit confirmation before ticket issuance or payment.
- Existing accessibility settings influence language and communication style without being interpreted as diagnoses or changing booking choices.
- Missing preferences, stale history, model errors, and disabled personalization fall back to a clear generic booking conversation.

## Out of scope

- Cloud accounts, cross-device profile sync, server-side memory, model training, or retaining prompts.
- Inferring demographic, health, disability, income, or payment preferences from past behavior.
- Automatic ticket purchase, payment submission, SOS activation, or location sharing.
- Claims about wheelchair access, stop accessibility, or real-time schedules unless the app has verified source data for them.
- Redesigning Android audio capture or the assistant's single-speaker architecture.

## Open implementation detail

The Settings layout location and the most accessible profile editor pattern should follow the existing settings hub. The implementation plan should identify the current settings navigation structure before selecting the exact page/widget placement.
