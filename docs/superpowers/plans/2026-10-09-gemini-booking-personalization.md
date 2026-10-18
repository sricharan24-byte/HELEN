# Gemini Live Booking Personalization Implementation Plan

> [!NOTE]
> **Status**: Completed 2026-10-11. Executed task-by-task; commits `32e7d8e` (Task 1), `d8ff0aa` (Task 2), `f503ef0` (Task 3), `f19ab49` (Task 4), `1b43714` (Task 5), plus the same-day follow-ups `22bf4bb` (draft preview) and `44de6d6` (name prefill, wallet auto-pay, arrival stack fix).
> **Verified**: `flutter analyze` clean, `flutter test` 463/463 green at Task 5 (471/471 after the follow-ups), `tool/ci/verify_docs.sh` passed per commit. Session log in `progress.md` (2026-10-11).
> **Not verified**: live end-to-end voice booking against Google's servers — the `get_booking_context` flow has only run against recording-transport fakes. First live run should watch for the model calling the tool after booking intent.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let Gemini Live use opted-in profile preferences, accessibility presentation settings, saved stops, recent non-demo trips, and booking draft context to make voice ticket booking more personal and require fewer repeated questions.

**Architecture:** Persist a small validated booking profile in `AppSettingsController`; construct a minimal immutable context only when the assistant requests it for a booking; keep slot values and their sources in `AppAutomationController`; return validated application results from Live tool calls. The checkout UI remains the only place where the passenger confirms ticket issuance and payment.

**Tech Stack:** Flutter/Dart, `AppSettingsController` + `LocalJsonStore`, `TicketController`, `TransportRepository`, Gemini Live WebSocket function calling, Flutter widget/unit tests.

**Spec:** `docs/superpowers/specs/2026-10-09-gemini-booking-personalization-design.md`

## Global Constraints

- Personalization is off by default and can be disabled at any time.
- Do not put profile or history details in the general Live system instruction; request booking context only after booking intent is clear.
- Include only allowlisted context: optional preferred name and passenger default; relevant accessibility presentation settings; saved stop names; up to three recent non-demo summaries with origin, destination, bus, and passenger type; current draft and slot provenance.
- Never serialize API keys, emergency contacts, precise location, ticket IDs, QR payloads, fares, historical payment/transaction details, timestamps, full ticket objects, or unrelated conversation data into booking context. The active draft may include the explicitly selected payment method, never payment credentials or transaction data.
- Never surface seeded demo tickets as personal history or infer demographic, health, disability, income, or payment preferences from behavior.
- Track booking slot provenance; an app fallback must not masquerade as a passenger choice.
- Checkout requires trip, bus, passenger type, and payment method, and explicit passenger confirmation before ticket issuance or payment.
- Use existing AppTheme/AppSpacing tokens, semantics, 48dp touch targets, and preserve platform text scaling.
- Do not alter Android audio capture or add another speech/audio owner.

## Review Focus

- Old, malformed, or unknown persisted profile values must hydrate safely to defaults — Task 1 pins this.
- Opt-out, demo history, stale stop IDs, and sensitive ticket fields must not leak through serialization — Task 2 pins these.
- App defaults and recent-trip suggestions must not count as passenger choices; payment must be explicit — Task 3 pins these.
- Tool calls must receive the correct result exactly once, including context opt-out and invalid args — Task 4 pins these.
- The booking-profile editor must remain usable with screen-reader semantics and large text — Task 1 pins this in a widget test.

---

### Task 1: Persist and edit the booking profile

**Files:**
- Modify: `lib/core/settings/app_settings_controller.dart`
- Modify: `lib/features/settings/voice_assistant_settings_page.dart`
- Test: `test/data/persistence_test.dart`
- Test: `test/features/settings_ui_test.dart`

**Interfaces:**
- Add settings fields `String preferredPassengerName = ''`, `PassengerType? defaultPassengerType`, and `bool useBookingPersonalization = false`.
- Add update methods `updatePreferredPassengerName(String value)`, `updateDefaultPassengerType(PassengerType? value)`, and `updateBookingPersonalization(bool enabled)`.
- Hydration must validate strings/enums and booleans; absent or invalid values retain defaults. Snapshot stores these fields but never stores `geminiApiKey`.
- Add a “Booking profile” section to the existing Voice Assistant Settings page with editable preferred name, optional passenger type, and an opt-in switch whose supporting text explains context is sent to Gemini after a booking request. Provide a way to clear the name/default.

- [x] **Step 1: Add persistence tests** with cases `bookingProfileRoundTripsLocally` (name, default passenger type, and opt-in survive hydrate/reload), `legacySettingsDefaultBookingPersonalizationOff` (missing fields use safe defaults), and `invalidBookingProfileValuesAreIgnored` (bad name/enum/boolean types do not throw or override defaults).
- [x] **Step 2: Run the focused persistence tests** with `flutter test test/data/persistence_test.dart`; verify the new cases fail before implementation.
- [x] **Step 3: Implement validated profile fields and update methods** in `AppSettingsController`, extending `_snapshot()` and `hydrate()` without adding API-key persistence.
- [x] **Step 4: Add settings UI widget coverage** verifying the opt-in default is off, profile values can be edited/cleared, and controls have labels usable by semantics at large text scale.
- [x] **Step 5: Add the profile section** to `VoiceAssistantSettingsPage`, using existing tokens and minimum 48dp control targets.
- [x] **Step 6: Run focused persistence and settings UI tests**; verify old/corrupt payloads fall back safely and opt-out starts off.
- [x] **Step 7: Commit** the settings model, UI, and tests.

### Task 2: Build the minimal booking context

**Files:**
- Create: `lib/features/ai_assistant/booking_context.dart`
- Test: `test/features/ai_assistant/booking_context_test.dart`
- Reference: `lib/data/repositories/transport_repository.dart`
- Reference: `lib/features/tickets/ticket_controller.dart`
- Reference: `lib/features/ai_assistant/app_automation_controller.dart`

**Interfaces:**
- Define immutable `BookingContext` with `Map<String, Object?> toJson()`.
- Define `BookingContextBuilder.build({required AppSettingsController settings, required TransportRepository repository, required TicketController ticketController, required Map<String, Object?> bookingDraft}) -> BookingContext`.
- `bookingDraft` has `slots`, an object keyed by `origin`, `destination`, `bus`, `passengerName`, `passengerType`, and `paymentMethod`; each value contains `value` and `source` strings. Task 3 supplies this exact map through `AppAutomationController.bookingDraftSnapshot()`.
- `BookingContext.toJson()` uses exactly these keys: `profile` (`preferredName`, optional `defaultPassengerType`), `communication` (`preferredLanguage`, `voiceSpeed`, `voiceConfirmations`, `textSize`, `highContrast`), `savedPlaces` (list of `{name}`), `recentTrips` (list of `{origin, destination, bus, passengerType}`), and `draft` (`slots`). Omit empty optional sections and omit every key outside this shape.
- When `settings.useBookingPersonalization` is false, output only current booking draft facts/provenance; omit name, passenger default, accessibility settings, saved stops, and recent history.
- When enabled, resolve saved stop IDs against repository stops, skip unknown IDs, and include at most three non-demo tickets with only origin, destination, bus, and passenger type. Do not sort/rewrite ticket history beyond taking newest-first repository order.
- Never return tickets, settings objects, or raw IDs for private ticket identifiers; output only JSON-safe primitive/map/list values.

- [x] **Step 1: Write context tests** with these cases and assertions: `includesOnlyAllowlistedPersonalContextWhenEnabled` (expected profile, accessibility, saved-stop names, and up-to-three route summaries only); `omitsPersonalContextWhenOptedOut` (no name, passenger default, accessibility, saved places, or history); `filtersDemoTicketsAndCapsRecentHistoryAtThree` (demo fixture absent, only the first three non-demo routes present); `skipsUnknownSavedStopIds` (no stale ID/name emitted); `serializesDraftValuesWithTheirSource` (all six draft slots retain the supplied source); `redactsTicketAndSensitiveFields` (history summaries contain no ticket ID, QR payload, fare/payment transaction data, timestamp, contact, API key, or location field; the current draft may include only the selected payment method, never credentials or transaction data).
- [x] **Step 2: Run** `flutter test test/features/ai_assistant/booking_context_test.dart`; confirm it fails because the context type/builder does not exist.
- [x] **Step 3: Implement** `BookingContext` and `BookingContextBuilder.build` with immutable output and strict allowlist serialization.
- [x] **Step 4: Run the context tests** and confirm all redaction and opt-out cases pass.
- [x] **Step 5: Commit** the context builder and its tests.

### Task 3: Make booking drafts explicit and provenance-aware

**Files:**
- Modify: `lib/features/ai_assistant/app_automation_controller.dart`
- Test: `test/features/ai_assistant/app_automation_controller_test.dart`

**Interfaces:**
- Add `enum BookingValueSource { unset, passenger, profileDefault, recentActivity, appDefault }`.
- Track a source for origin, destination, bus, passenger type, and payment method; setters called from passenger tool data mark values as `passenger`.
- Add `applyProfileDefaults({required String preferredName, required PassengerType? passengerType})`; use the preferred name for assistant address only, and fill the passenger-type booking slot only when unset, marking it `profileDefault`. Never assume the ticket passenger is the profile owner.
- Add `stageRecentTripSuggestion({required Stop origin, required Stop destination, required String busId})`; mark staged values `recentActivity`, keep them pending, and do not let them satisfy readiness until the passenger accepts or restates them. Passenger acceptance promotes the chosen values to `passenger` source.
- Extend `AutomationResult` with JSON-safe result fields needed by Gemini: success, user-facing summary, missing slots, and whether a confirmation gateway is needed.
- `bookingReadiness()` requires resolved origin/destination, selected bus, passenger type, and payment method. Initial app fallbacks (`general`, `UPI`, or `18B`) do not satisfy readiness.

- [x] **Step 1: Write controller tests** with these cases and assertions: `passengerToolCallsMarkSlotSourcesAsPassenger` (all six setters mark their values); `correctionReplacesValueAndSource` (latest passenger value wins); `profileDefaultsFillOnlyUnsetPassengerType` (preferred name is not copied into ticket passenger name and existing passenger type is unchanged); `recentTripSuggestionWaitsForPassengerAcceptance` (recentActivity values remain pending and do not pass readiness, acceptance promotes them to passenger); `appFallbacksDoNotSatisfyReadiness` (general/UPI/18B defaults leave readiness incomplete); `bookingReadinessRequiresTripBusPassengerAndPayment` (each missing required slot is reported); `bookingDraftSnapshotIncludesOnlySlotValueAndSource` (six slots serialize in the exact Task 2 shape).
- [x] **Step 2: Run** `flutter test test/features/ai_assistant/app_automation_controller_test.dart`; confirm missing readiness/provenance behavior fails.
- [x] **Step 3: Implement** provenance tracking and explicit readiness in `AppAutomationController`; keep edits focused on booking draft behavior.
- [x] **Step 4: Run controller tests** and verify selecting each required slot transitions readiness only when all four are valid.
- [x] **Step 5: Commit** the controller changes and tests.

### Task 4: Retrieve context and return actual Live tool results

**Files:**
- Modify: `lib/domain/assistant/assistant_command.dart`
- Modify: `lib/features/ai_assistant/gemini_live_session.dart`
- Modify: `lib/features/ai_assistant/gemini_live_screen.dart`
- Test: `test/features/ai_assistant/tool_command_safety_test.dart`
- Test: `test/features/ai_assistant/gemini_live_transport_frames_test.dart`
- Test: `test/features/gemini_live_test.dart`

**Interfaces:**
- Register `get_booking_context` as a read-only tool with no arguments; system instruction says to request it only after a clear booking intent.
- Replace the void-only tool handoff with a result-bearing callback: `Map<String, Object?> Function(String name, Map<String, dynamic>? args)? onToolCall`.
- `GeminiLiveScreen` callback handles `get_booking_context` with the Task 2 builder, applies the Task 3 passenger-type default when enabled, stages at most one recent route suggestion without making it readiness-satisfying, handles booking setters, and returns a validated JSON-safe result map.
- `GeminiLiveSession` uses the callback result in `toolResponse.functionResponses[*].response.output`; unknown/invalid tool calls return a bounded error result and never claim success.
- Update the Live instruction to use returned context, identify profile/recent suggestions, ask for uncertain values, honor corrections, and never claim unsupported schedule/GPS results.

- [x] **Step 1: Add protocol tests** with these cases and assertions: `getBookingContextIsDeclaredReadOnlyWithoutArguments` (registry metadata and declaration); `toolResponseUsesApplicationCallbackResultForMatchingCall` (result, ID, and name match the received call); `toolCallbackFailureIsReturnedAsFailure` (no success envelope on failure); `unknownToolCallDoesNotClaimSuccess` (bounded failure result); retain assertions in `tool_command_safety_test.dart` that confirmable SOS/share/booking commands still return `requiresConfirmation: true`.
- [x] **Step 2: Run** the focused tool/frame tests and verify current generic output fails expected result assertions.
- [x] **Step 3: Refactor tool dispatch** to return and serialize the app callback's result while preserving tool-call IDs and current safety gateway metadata for confirmable actions.
- [x] **Step 4: Wire the Live screen callback** to context building and booking automation; preserve one action execution per turn and existing explicit checkout confirmation.
- [x] **Step 5: Update the system instruction** to use context only within booking, identify suggestion sources, ask for missing/ambiguous slots, and avoid claiming booking/payment completion.
- [x] **Step 6: Add integration coverage** in `test/features/gemini_live_test.dart` with cases `bookingUsesOptedInContextAndNamesSuggestionSource`, `optedOutBookingSendsNoProfileOrHistoryContext`, `bookingCorrectionUpdatesVisibleDraft`, and `checkoutWaitsForExplicitPaymentMethod`; assert checkout does not open before all required slots are resolved and still waits for the passenger's explicit confirm action.
- [x] **Step 7: Run** `flutter test test/features/ai_assistant/tool_command_safety_test.dart test/features/ai_assistant/gemini_live_transport_frames_test.dart test/features/gemini_live_test.dart` and relevant controller/context tests; verify no sensitive fields appear in captured tool response frames.
- [x] **Step 8: Commit** Live tool/result integration and its tests.

### Task 5: End-to-end validation and final review

**Files:**
- Review: all files listed above
- Tests: focused tests from Tasks 1–4

- [x] **Step 1: Run** `flutter analyze lib test` and resolve new diagnostics in changed code.
- [x] **Step 2: Run** the focused tests from Tasks 1–4; verify persistence, semantics, privacy redaction, tool-result matching, slot readiness, and confirmation gates.
- [x] **Step 3: Review the diff** against every acceptance criterion in the spec, including stale stop IDs, demo history filtering, opt-out behavior, explicit payment, and accessibility settings.
- [x] **Step 4: Commit** any final integration fixes separately.
