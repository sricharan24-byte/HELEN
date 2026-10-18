# Gemini Multi-Task Booking and Voice Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete a multi-part spoken booking request through app-validated ticket creation, truthful status, and requested map navigation, with one audible response voice.

**Architecture:** Add one structured `prepare_booking` tool for full requests while retaining current step-by-step tools for follow-up. A shared local bus-options source and strict booking readiness feed the existing checkout, whose ticket-created callback gates map navigation. Gemini PCM remains preferred; TTS is a mutually exclusive fallback.

**Tech Stack:** Flutter/Dart, Android Kotlin, existing Gemini Live function calling, local transport fixtures, existing ticket checkout and AudioTrack/TTS channels.

**Spec:** `docs/superpowers/specs/2026-10-18-gemini-multi-task-booking-design.md`

## Global Constraints

- Do not claim live arrival times, a real wallet debit, or a completed ticket before the local checkout callback proves the corresponding state.
- Do not select a bus or route that is not present in the app's available data.
- Preserve explicit passenger consent for payment methods that currently require confirmation. The user's spoken Wallet choice remains explicit authorization for the app's demo Wallet behavior.
- Keep one microphone/audio-session owner and one voice producer per reply.
- Do not add dependencies. Do not add or run tests unless the user asks; use formatting, static analysis, Android build, source review, and `git diff --check` for verification.

## Review Focus

This plan avoids new automated tests per the repository and task instruction; review these cases in the owning code and verify with analysis/build:

1. Exact ASR alias “Bello Fort” resolves to Vellore Fort; an unrelated or unknown stop returns clarification without mutating the draft.
2. A route with no available bus options never picks an invented bus or ETA.
3. Missing passenger name, passenger type, payment method, or route prevents checkout from opening.
4. A cancelled/failed checkout never marks a ticket issued and never opens the map.
5. If model PCM arrives after app TTS begins, TTS stops before model playback starts; if PCM never arrives, only one concise TTS fallback speaks.

---

### Task 1: Share validated demo bus options and stop alias handling

**Files:**

- Modify: `lib/data/models/transport_models.dart`
- Modify: `lib/data/datasources/local_transport_data_source.dart`
- Modify: `lib/data/repositories/transport_repository.dart`
- Modify: `lib/features/tickets/ticket_booking_suite_page.dart`
- Modify: `lib/features/ai_assistant/app_automation_controller.dart`

**Interfaces:**

- Add immutable `BusDepartureOption` with `const BusDepartureOption({required this.busId, required this.etaMinutes, required this.serviceNote})` and typed `String`, `int`, and `String` fields.
- Produce `TransportRepository.availableBusesForRoute(String routeId) -> List<BusDepartureOption>` backed by the same 18B/4, 12A/12, and 20C/18 minute demo estimates shown in the booking screen.
- Preserve `_resolveStop` exact matching and add only the explicit speech alias `bello fort` → `Vellore Fort`.

- [x] Replace the booking page's hardcoded bus cards with `availableBusesForRoute`, labeling each arrival as a demo estimate.
- [x] Validate `_applyBus` against the selected route's returned options; reject an unavailable bus without changing the draft.
- [x] Resolve the exact alias before normal stop lookup; return a clear invalid-stop result when no stop resolves.
- [x] Review that unknown routes return no bus options and no fallback bus/ETA.

### Task 2: Add atomic booking preparation and complete readiness checks

**Files:**

- Modify: `lib/domain/assistant/assistant_command.dart`
- Modify: `lib/features/ai_assistant/app_automation_controller.dart`
- Modify: `lib/features/ai_assistant/gemini_live_screen.dart`
- Modify: `lib/features/ai_assistant/gemini_live_session.dart`

**Interfaces:**

- Add the `prepare_booking` tool with fields `origin`, `destination`, `busPreference`, `busId`, `passengerType`, `passengerName`, `paymentMethod`, and `openMapAfterBooking`.
- Add `AppAutomationController.prepareBooking(Map<String, dynamic>? args) -> AutomationResult`; validate all explicit values before committing them to the draft.
- For `busPreference == 'earliest'`, choose the option with the smallest `etaMinutes` from Task 1. For an explicit bus, require an exact available `busId` match.
- Return `status: needs_clarification | draft_ready`, the missing/invalid fields, and `ticketIssued: false`; no ticket/payment success is returned here. Confirm the origin/destination pair resolves to a route through `TransportRepository.findRoutes(...)` before marking the draft ready.

- [x] Add `prepare_booking` tool metadata and instruct Gemini to use it once for a multi-part booking utterance, retaining existing setters for follow-up turns.
- [x] Implement atomic stop, route, bus, passenger, payment, and post-booking-action resolution. On any invalid/ambiguous/missing value, leave unresolved values unset and return a concise clarification.
- [x] Include `passengerName` in readiness; checkout cannot open until name, type, trip, bus, and payment are satisfied.
- [x] Route `prepare_booking` through one mutation path only; prevent `onAction` plus `onToolCall` from applying the request twice.
- [x] Update the system instruction to remove fixed/live ETA claims and prevent `draftComplete` from being treated as ticket or payment completion.

### Task 3: Gate ticket success and map navigation on checkout outcome

**Files:**

- Modify: `lib/domain/assistant/assistant_command.dart`
- Modify: `lib/features/ai_assistant/gemini_live_session.dart`
- Modify: `lib/features/ai_assistant/gemini_live_screen.dart`
- Modify: `lib/features/tickets/ticket_booking_suite_page.dart`
- Modify: `lib/features/tickets/booking_checkout_dialog.dart`

**Interfaces:**

- The checkout's `onTicketBooked(Ticket)` callback is the only success signal.
- Thread `openMapAfterBooking` through `GeminiLiveScreen` → `TicketBookingSuitePage`; navigate to `LiveLocationScreen` for the exact callback ticket only when checkout created it and the request asked for the map.
- Treat `Ticket.isDemo == true` as a demo booking and never report a real wallet debit.

- [x] Change confirmation tool results to say `checkout_pending`/`draftReady`, with `ticketIssued: false`; remove the prompt's rule that a complete draft means paid/booked.
- [x] Preserve wallet auto-confirm only for the explicit Wallet request and the current demo checkout. Keep existing explicit confirmation for other methods.
- [x] Ensure cancellation or checkout rejection leaves the passenger in the assistant/booking flow without success copy or map navigation.
- [x] Update checkout and completion copy to identify the issued item as a demo ticket and clarify that no real payment provider is connected.
- [x] Review the success sequence: validated draft → checkout → ticket callback → requested map; no earlier step reports completion.

### Task 4: Enforce one voice producer for long and multi-tool turns

**Files:**

- Modify: `lib/features/ai_assistant/gemini_live_screen.dart`
- Modify: `lib/features/ai_assistant/model_voice_player.dart`
- Modify: `lib/features/ai_assistant/audio_speech_engine.dart`

**Interfaces:**

- Keep `ModelVoicePlayer.hasModelAudioThisTurn` as the per-turn preference signal.
- Gemini model audio wins when PCM is received; fallback TTS is used only after a completed response with no PCM.
- Tool-protocol turns remain silent; release the microphone only after the active model playback or TTS fallback ends.

- [x] When PCM arrives, stop any active fallback TTS before queuing Gemini PCM and clear fallback-speaking state.
- [x] Start one concise app TTS fallback only after final turn completion confirms no Gemini audio; do not speak intermediate setter/context results.
- [x] Keep the existing watchdog and playback-drain lifecycle, ensuring the microphone resumes once after the chosen speaker finishes.
- [x] Review long text, late PCM, barge-in, tool-call follow-up, and teardown paths for overlapping audio owners.

### Task 5: Verify the implementation

- [x] Format touched Dart files and confirm formatting makes no further changes.
- [x] Run `flutter analyze --no-pub`; require `No issues found!`.
- [x] Run `flutter build apk --debug`; require successful APK build.
- [x] Run `git diff --check`; require no whitespace errors.
- [x] Review the five cases listed in Review Focus; do not claim physical audio/payment/arrival verification without exercising the connected Android app and observing its actual outcome.
