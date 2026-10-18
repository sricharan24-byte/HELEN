# BusBuddy Implementation Progress Log

> **Compact log — newest first.** Full prose for everything below (2026-09-20 → 2026-10-18,
> plus the old Executive Summary / Key Accomplishments / Roadmap sections) is preserved
> verbatim in [`docs/archive/progress-sessions-full.md`](docs/archive/progress-sessions-full.md);
> git history has every revision. Keep new entries short:
> date · what landed · commits · verification · what is still **not verified**.

**Last verified state — 2026-10-18**: `flutter analyze` clean · `flutter test` **476/476 green**
(from the earlier web microphone fix; not rerun after the audio ordering change) · Android debug
APK built, installed and launched on the connected phone. Gemini audio quality still needs the
passenger's on-device confirmation.

## ⚠️ Open / unverified items — do not claim otherwise

- **Live end-to-end voice booking** against Google's servers — `get_booking_context` has only
  ever run against fakes (2026-10-11). On the first live run, watch the model actually calling
  the tool after booking intent and honoring the returned context.
- **Model-audio playback** ("natural voice") with a live Gemini session — the wire path and both
  bridges are unit-tested; audibility unverified (ADR-004 §3.1, §3.4, §3.5).
- **Android voice round trip** — debug build installed and launched on a physical Samsung phone;
  live Gemini audio quality, spoken-question round trip, hardware echo cancellation and TalkBack
  have not yet been confirmed with a valid key and passenger listening (ADR-004 §§3.1, 3.7).
- **Android mic capture round trip** (2026-10-09 startup-handoff fix) — the app now runs on a
  physical device, but a live mic + valid-key session still needs confirmation.
- **Release APK never installed** — built 2026-10-18 (universal, debug-signed); no phone was
  connected, so install, launch and on-device voice are unverified.
- **Web** — Chrome *granted-permission* → spoken question → reply round trip still pending a
  real-profile retest (2026-10-11; the 2026-10-18 churn fix reproduced the failure signature and
  fixed it headlessly, but the fixed path has not yet run with a real mic + key).
- **Mobile-UI plan Task 4** — rendered visual pass at 360×800 / 390×844; no screenshot pipeline
  here.

## 🛠️ Sessions — newest first

### 2026-10-18 — Gemini Live PCM stutter repair

- Fixed a Dart ordering race: later PCM chunks could reach Android before the first chunk, which
  waited for `startPlayback`. Native drain events also treated temporary gaps between chunks as
  the end of Gemini's reply, risking an early microphone resume. PCM writes now serialize; the
  screen sends `finishPlayback` at `turnComplete`; Android drains only after that marker, an empty
  queue and a caught-up `AudioTrack` playback head. The prior Android worker/partial-write fixes
  remain in place.
- **Verification**: `flutter analyze` clean · debug APK built, installed and app relaunched on the
  connected phone. Automated tests were not rerun. **Still needs the passenger's ears**: live
  Gemini audio smoothness on-device.

### 2026-10-18 — Gemini voice overlap and map request repair

- Kept offline TTS muted throughout `GeminiLiveScreen`; text-only replies remain visible and
  continuous listening resumes without waiting for a TTS callback. Gemini PCM remains the only
  spoken reply source.
- Capture explicit map requests from typed input and Gemini's spoken-input transcription, carry
  them across missing booking details, and pass them through checkout; live map navigation still
  waits for ticket creation. A direct tracking request without an active ticket now says why it
  opens booking.
- **Verification**: `dart format` · `flutter analyze --no-pub` clean · debug APK built. Automated
  tests and physical-device audio/map behavior were not run/verified.

### 2026-10-18 — Web microphone churn fixed (reported: mic "turns on for a sec and stops")

- **Reproduced** headlessly in Chrome against this repo's own bridge JS: `onstart` → Chrome
  `audio-capture` ~10 ms later → the screen threw the reason away and restarted silently every
  ~150 ms → stopped with the generic "I couldn't hear anything". The reported signature exactly.
- **Bug 1 (the dead microphone):** `onEnd`'s silent branch never cleared `_isListening`, so
  `_scheduleRestartListening`'s `!_isListening` guard swallowed every restart — on the web the
  mic closed after the first silent cycle while the screen still claimed "Listening…", and the
  3-silent-cycles stop was unreachable. The flag now drops with capture.
- **Bug 2 (the swallowed reason):** a named failure (`audio-capture`, `network`,
  `service-not-allowed`) now stops the loop and shows Chrome's own message plus
  `Chrome's input devices: …`; `onEnd` can no longer overwrite it. Bridge **v12** adds
  `__bb_input_devices` (refreshed at install/start/error).
- **Verification**: `flutter analyze` clean · `flutter test` **476/476 green** · extracted bridge
  JS `node --check` clean and exercised in headless Chrome (real earphone mic → healthy 8 s
  `no-speech` cycles; monitor source → honest `audio-capture` + device list).
  **Not verified**: the real-profile Chrome voice round trip (needs the user's mic + key).
- Written up in **ADR-004 §3.6**; the invariants are pinned in `AGENTS.md` (*Microphone
  honesty*) and in `voice_session_lifecycle_test.dart`.

### 2026-10-18 — Installable release APK built

- Android SDK licenses accepted (`yes | flutter doctor --android-licenses`) — the Android toolchain
  then reported ✓, which was the build blocker.
- `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk` (universal;
  sha256 `fc671f71…`, 54 MB, 2026-10-18 15:40). Debug-signed — no release keystore is configured,
  fine for sideloading, not for Play. No Gemini key is baked in (the key is never persisted), so a
  permanent key needs `--dart-define=GEMINI_API_KEY=…` at build time. `build/` is gitignored, so
  the artifact is not in the repo.
- Older APKs in `build/` (2026-10-09) are stale — do not install those.
- **Not verified**: no phone was connected, so the APK has never been installed or launched on a
  device. Smaller per-device builds (`--split-per-abi`, arm64 ≈ 20 MB) are one command away.

### 2026-10-18 — Docs compacted for token cost

- `progress.md` 207 KB → 11 KB: compact live log (current state · open items · recent sessions ·
  one-line index); the full prose moved verbatim to `docs/archive/progress-sessions-full.md`
  (verified byte-for-byte against the old file).
- `AGENTS.md` 23.5 → 17.8 KB — same contracts, narration removed. `README.md` 21.8 → 10.4 KB,
  and stale claims corrected on the way: the removed floating-bubble feature was still advertised,
  the clone URL pointed at a non-existent repo, and count-based claims replaced with the
  CI-as-source-of-truth statement.
- ADRs, plans and specs untouched (read-on-demand decision records).
- **Verification**: `tool/ci/verify_docs.sh` passed · `flutter test` **475/475 green** at this state.

### 2026-10-18 — Four-Destination Shell built (`d0e866a`)

- `AppNavigationShell` (`lib/features/navigation/app_navigation_shell.dart`): **Home / Plan /
  Tickets / More** in an `IndexedStack` of per-destination nested `Navigator`s. Destinations
  build lazily on first visit and stay alive — tab switches never recreate a booking form or
  reset a ticket tab. One `NavigatorObserver` **per navigator** (the framework asserts one
  owner).
- Back: pops the active destination's stack → returns to Home → exits only from the Home root
  (`PopScope.canPop` derived from the active nested navigator). Detail pushes use
  `Navigator.of(context)` inside the destination; wake-word pushes stay on the root navigator
  and cover the shell.
- `MorePage` (dead code until now) is the More hub: Safety & Contacts / Corridor Alerts /
  Settings. Plan = `TicketBookingSuitePage(showBackButton: false)`, Tickets =
  `MyTicketsPage(showBackButton: false)`. Tokens only; nav labels keep Flutter's built-in
  label-scale cap.
- Pre-existing 300 % defects fixed on the walk: booking-suite header content-sized in the body;
  sticky bar → shared `SettingsAskBusBuddyBar` (a Material button in the `bottomNavigationBar`
  slot expands and zeroes the body height); bar hint capped at 2 lines.
- Pinned in `test/features/app_navigation_shell_test.dart` (4 cases, incl. a 360 dp / 300 % walk).
  **Verification**: analyze clean · **475/475** (471 + 4) · docs gate. Deliberate deviation from
  the plan's "no tests" note — CI runs `flutter test`.

### 2026-10-18 — Housekeeping & Plan Audit (`e8ef971`)

- Committed the three untracked planning docs with honest status notes; re-verified **471/471**
  at `44de6d6`.
- Audit: the mobile UI/navigation redesign was only half built — the responsive work landed
  (`52b8ff7` + Chunk 50) but the four-destination shell never existed and `more_page.dart` was
  orphaned → owner chose to build the shell (done above, same day).
- `plugins/dsh-cost-meter/` (a dsh web-client plugin) moved out of the repo to
  `~/.dsh/plugins/dsh-cost-meter`; the repo has no `plugins/` directory.

### 2026-10-11 — Voice booking fixes: name prefill, wallet auto-pay, arrival no longer kills the assistant

- Passenger **name** now prefills from the saved profile (source `profileDefault`, shown as
  "Student • Pavan"); an explicit `set_passenger` correction always wins.
- **Wallet** bookings auto-pay (`BookingCheckoutDialog.autoConfirm`); UPI/card always keep the
  payment widget + on-screen confirmation (owner decision narrowing BUS-P0-05 for wallet only —
  the model must never claim UPI/card paid before confirmation).
- Arrival no longer closes the assistant: voice-flow routes are named `voice-booking-flow`;
  `LiveLocationScreen.popToFirstOnArrival` (default **true** — non-voice flows keep the
  pop-to-home contract) pops only until the top route is not part of the voice flow.
- **Verification**: analyze clean · **471/471** · docs gate · integration test in
  `trip_completion_test`.

### 2026-10-11 — Booking Draft Preview

- New `BookingDraftPreview` card on the Live screen: four slot rows (Trip / Bus / Passenger /
  Payment) with provenance chips — You chose / Your default / Suggestion (warning, never red) /
  App default / Not set yet; constructor fallbacks render "Not set yet", never as choices.
- Staged-suggestion banner (Use this trip / Not now) finally gives `acceptStagedSuggestion()` a
  UI caller; `dismissStagedSuggestion()` reverts to unset. Estimated fare from `FareEngine` only
  for real passenger choices on known routes.
- Deliberately **no live region** (the assistant already narrates every slot change).
  **470/470** · 6 widget tests + 1 controller test.

### 2026-10-11 — Gemini Booking Personalization (plan executed, Tasks 1–5; `32e7d8e` … `1b43714`)

- Opt-in booking profile in settings (name / default passenger type / switch, all
  hydrate-validated); allowlisted `BookingContextBuilder` — profile, communication settings,
  saved-place names, ≤3 non-demo trips, draft as `{value, source}`; never ships demo tickets,
  ticket IDs, QR payloads, fares, timestamps, contacts, locations, keys.
- Provenance on all six slots; readiness satisfied **only** by `passenger` / `profileDefault` —
  the `18B` / `UPI` / `general` constructor fallbacks and staged suggestions can never masquerade
  as choices; `confirm_booking` reports missing slots honestly.
- Read-only `get_booking_context` tool (silent protocol, no args, at most once per attempt);
  result-bearing `GeminiLiveSession.onToolCall` preserves id/name.
- **463/463** · redaction/privacy + recording-transport integration tests.
  ⚠️ **Never run against Google's servers** — see Open items above.

### 2026-10-11 — Web Microphone Honesty (BUS-P1-08)

- Every mic start (auto-start, orb tap, Try Again, restart timer) goes through
  `_gatedMicrophoneStart` → `_awaitLiveReady` on **all platforms**; no key → the screen names the
  key, the microphone stays off. `Live Ready` auto-opens the continuous mic.
- Web bridge **v10**: `onStarted` (fired from recognition `onstart`, *after* Chrome's permission
  prompt) is the only thing that flips `_isListening` and plays the chime; before it the UI says
  "Preparing the microphone…". `audio-capture` / `service-not-allowed` name their real causes.
- Three consecutive silent cycles end continuous mode with "I couldn't hear anything…" (wrong
  input device / muted mic) instead of an endless "Listening…". Invalid-key orb message names the
  fix; 8 s guard for Chrome's unanswered permission prompt.
- Bridge **v11**: 0.2 s jitter cushion on a dry Web Audio queue (stutter fix). Judge web latency
  only from `--release` builds, never debug.
- **435/435** · Node bridge checks 6/6 (v10) and 5/5 (v11). ⚠️ Granted-permission live round trip
  pending user retest.

### 2026-10-09 — Android Microphone Startup Handoff

- Native race fixed: `AudioRecord` capture starts from `EventChannel.onListen` (sink available),
  not from the permission callback before Dart subscribed.
- ⚠️ Device round trip unverified — no usable Android build in this environment.

### 2026-10-06 — Live-Map Destination Arrival

- One-shot post-frame `_onArrival`: expire the ticket via `completeActiveTrip` (only if still
  active), polite announcement, non-dismissible `Destination Reached` dialog with a 10 s
  "Live map closing…" countdown → `popUntil(isFirst)`; timer is dialog-local and cancelled in
  dispose. All four push sites pass their `TicketController`.
- **410/410** · new `live_arrival_test.dart` (fixed pumps — a periodic countdown never
  `pumpAndSettle`s).

### 2026-10-06 — Saved Places Rebuild

- Saved places are chips (`SavedPlaceChips`, 48 dp star) inside the booking origin/destination
  and Find-a-Place pickers — tap selects, star toggles, persisted as stop IDs, names resolved at
  render. `SavedPage`, the `saved_places` home card (7→6) and the `open_saved` tool were removed;
  voice "saved places" routes to `search_route`.
- **407/407** · new `saved_places_test.dart` (8).

### 2026-10-06 — Key-Connect Repair

- The single choke point `_connectValidated`: empty → `Key Needed`; validating →
  `GET v1beta/models?pageSize=1`; rejected → `Key Invalid` + reason; accepted → connect;
  `Live Ready` only on `setupComplete` (socket-open is `Completing handshake…`). Debounced
  (400 ms) settings listener reconnects on any key/model/voice change.
- Key is **never persisted** (pinned in `persistence_test`) — an app restart needs re-entry
  unless `--dart-define=GEMINI_API_KEY`.
- **399/399** · `key_connect_gate_test.dart` (5). ⚠️ A real key against the real endpoint still
  needs the owner's key + ears.

## 📚 Earlier sessions (2026-09-20 → 2026-10-06) — one line each; full prose in the archive

- **2026-09-20** — Zero-failing-test baseline + Astra Phase 2 P2 kickoff (permission
  minimization, release shrinking, strict analysis).
- **2026-09-22** — P2 resumed: TTS arbiter, release shrink verify, strict analysis green, CI as
  source of truth.
- **2026-09-25** — Chunk 41: single-voice fix for simultaneous double-audio replies.
- **2026-09-25** — Chunk 42: floating AI assistant removed (single voice surface).
- **2026-09-25** — Chunk 43: voice reply removed & rebuilt (single speaker).
- **2026-09-26** — Chunk 44: Android spoken questions reach Gemini Live (audio-in).
- **2026-09-30** — Chunk 45: Android runtime run found a lie in the voice UI (mic-state honesty).
- **2026-10-02** — Chunk 46: native transport dropped every server frame (P0).
- **2026-10-02** — Chunk 47: usability audit items 1–6.
- **2026-10-03** — Chunk 48: AI control edge glow.
- **2026-10-04** — Chunk 49: single-speaker audio architecture — model voice restored.
- **2026-10-06** — Chunk 50: cross-screen design-contract polish.
- **2026-10-06** — Chunk 51: home options trim, Chrome voice silence, glow-over-Home.

> History before 2026-09-20 exists only as the archive's Executive Summary / Key
> Accomplishments / Roadmap sections — stale in places; verify against code and git before
> relying on it.
