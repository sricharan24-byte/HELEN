# Repository Guidelines

This guide records repository-specific practices and agent workflow.


All BusBuddy source code, tests, documentation, progress files, and generated project artifacts must be stored under `/home/pavan/BusBuddy`. External folders may be read as reference inputs only; temporary extraction directories are not deliverable locations.

## Project Structure
This repository contains a Flutter/Dart-based accessible public transport assistant prototype called BusBuddy, focused on a Vellore, India demonstration. The codebase is organized around journey modeling, route search, accessible UI, and realtime bus tracking. A Python script (`create_research_doc.py`) generates the associated Word document using the `python-docx` library. Source code (.dart files) is present under `lib/` with feature-based organization (`features/`, `core/`, `data/`).

## Build / Test / Development Commands
- `flutter pub get` — resolve dependencies
- `flutter analyze` — static analysis (0 errors)
- `flutter test` — run all widget/unit tests (370 tests, 100% green)
- `flutter run -d chrome` — run on Chrome web (required for Gemini Live voice features)
- `flutter run -d linux` — run on Linux desktop
- `python create_research_doc.py` — generates `BusBuddy_Implementation_Research_and_UI_Design.docx` using `python-docx`

## Coding Style / Naming
- The Python document generator uses UPPERCASE constants for configuration (`OUT`, `BLUE`, `DARK_BLUE`, `MUTED`, `LIGHT_BLUE`, `LIGHT_GRAY`).
- Dart/model naming follows camelCase for entities (e.g., `routeId`, `displayName`, `orderedStopIds`, `direction`, `stopId`, `name`, `latitude`, `longitude`, `busId`, `tripId`, `LiveLocation`, `JourneySession`, `UserPreference`).
- Flutter/Dart conventions: `flutter_lints` package active via `analysis_options.yaml`.

## Testing Guidelines
- Flutter widget tests using `WidgetTester`, `SemanticsHandle`, `pumpAndSettle`, `pump` for timers.
- Guidelines for tap-target, label, contrast, and semantics from research document.
- Manual Android testing with TalkBack and Accessibility Scanner recommended.
- Task testing with at least one relevant blind/low-vision participant advised; relying on blindfolded sighted participants alone is not sufficient.
- Usability measures: completion rate, time, errors, number of recovery actions, confidence, SUS score.
- Test files live under `test/` mirroring `lib/features/` and `lib/data/` structure.
- Native Android voice work is covered headlessly where possible: `test/features/ai_assistant/android_voice_turn_test.dart` drives the spoken-turn state machine through injected streams, and `native_audio_channel_test.dart` asserts the bridge degrades honestly when the platform channels are absent. An emulator is also not enough: a run on an API 34 AVD (2026-09-30) proved the build, install, permission contract and honest-failure paths, but the AVD has no working TTS engine, no hardware AEC and no TalkBack, and without a valid Gemini API key `_awaitLiveReady` never opens the microphone — so the permission dialog and the audio-in round trip are unreachable there too. Those still require a physical device with a valid key (`flutter run -d android`, `adb logcat -s BusBuddyVoiceChannel:V`) — do not claim them verified from a green test run, and do not claim them verified from an emulator run either.

## Commit / PR Guidance
- No commit message conventions, PR template, or branch naming policy documented. Standard Git practices apply.

## Configuration / Document-Generation Notes
- `create_research_doc.py` depends on `python-docx` package (imported as `from docx import Document`).
- Outputs to `BusBuddy_Implementation_Research_and_UI_Design.docx` in the same directory.
- No `.env`, `requirements.txt`, `pubspec.yaml`, `flavor` configurations, or CI files present.

## Key Runtime Notes
- **Microphone state must be earned, never assumed**: `GeminiLiveScreen._isListening` starts `false` and is set only once capture is genuinely open. It previously defaulted to `true`, which both advertised "Continuous Mic Active"/"Listening…" with no microphone open and made `_startMicrophoneListening` early-return on its own `_isListening` guard, so the first open never started capture on *any* platform. The Android path shows "Preparing the microphone…" across the permission dialog and the up-to-4 s Live handshake and flips the flag only after `turn.isActive`. Regressions are pinned in `test/features/ai_assistant/voice_session_lifecycle_test.dart` (*BUS-P1-08 Microphone State Honesty*). Keep failure messages naming the *real* reason — "still connecting" is wrong when no API key is set, which is the common first-run case.
- **Gemini Live voice requires a valid Google AI Studio API key** (set via in-app dialog or `--dart-define=GEMINI_API_KEY`). Audio I/O is platform-native: Chrome web uses the Web Speech APIs; Android uses `BusBuddyVoiceChannel` (`android/app/src/main/kotlin/com/busbuddy/app/BusBuddyVoiceChannel.kt`) — `TextToSpeech` replies, 24 kHz `AudioTrack` playback built on `USAGE_ASSISTANCE_ACCESSIBILITY` (so hardware echo cancellation stays engaged while the mic is open), `ToneGenerator` chimes, plus 16 kHz mono `AudioRecord` capture streamed over the `busbuddy/voice/mic` event channel. `RECORD_AUDIO` is requested just in time (announced first, rationale-aware, "never ask again" detected via SharedPreferences).
- **Android spoken questions now reach Gemini Live (audio-in)**: `GeminiLiveSession.sendRealtimeAudio` packs microphone PCM into `realtimeInput.mediaChunks` (`audio/pcm; rate=16000`) and is gated on `GeminiLiveSession.isReady` (socket open **and** `setupComplete` received). One spoken turn is owned by `AndroidVoiceTurn` (`lib/features/ai_assistant/android_voice_turn.dart`), which forwards chunks, pauses while the assistant speaks, and reports every failure exactly once through `onTurnLost(reason, microphoneUnavailable)`; the screen then shows the reason and hands the passenger the text box. `GeminiLiveScreen` waits up to 4 s for the handshake before opening the microphone (`_awaitLiveReady`), never leaves capture open on a dead socket, and releases the turn on text turns, mic-off taps and `dispose()`. Server-side VAD ends the question, so no `audioEnd` control frame is sent. Platform detection uses `Platform.isAndroid` through `native_platform_io.dart`, never `defaultTargetPlatform` (which `flutter_test` fakes as Android). *Code-complete, unit-tested, and exercised on an API 34 emulator on 2026-09-30 — which is how the Chunk 45 microphone-state lie was found. The audio-in round trip, permission dialog, echo cancellation and TalkBack remain unverified because that run had no valid Gemini API key; see ADR-004 §3.1 for exactly what is and is not proven.*
- **Android has no on-device speech-to-text**, so `AudioSpeechEngine.startListening` on Android is an honest fallback path only (permission flow + "please type your question"). The live audio path bypasses `startListening` entirely; if the transport cannot take the audio, the reason is spoken/shown verbatim rather than a transcript being invented (BUS-P0-06).
- **Display-only passenger transcript**: `inputTranscription` text is shown as `🗣️ "…"` and is never re-submitted as a text turn — the audio it transcribes already reached the model. `AudioSpeechEngine.liveMicrophoneErrors` surfaces `AudioRecord` failures (no usable input, access revoked) so a "Listening…" promise is never left unfulfillable.
- Current Live API model: `models/gemini-3.8-live` (configured in `AppSettingsController` default).
- **Official Google Prebuilt Voices**: Supported voices are `Aoede` (default female), `Kore` (calm female), `Charon` (informative male), `Puck` (upbeat male), and `Fenrir` (deep male). Configurable in Voice Assistant Settings or via `--dart-define=GEMINI_VOICE=Aoede`.
- **Natural Voice Conversational Delivery**: The assistant executes tool calls seamlessly in the background and delivers concise, natural transit answers without verbally reading out raw JSON, function signatures, or execution mechanics.
- **Persistent Continuous Hands-Free Listening Mode**: Once the microphone is enabled, listening stays continuously active across conversational turns, auto-restarting on silence/timeout (web), auto-resuming 350 ms after the AI finishes speaking, and debouncing acoustic feedback. On Android the stream stays open across turns instead: frames are withheld while the assistant speaks (`AndroidVoiceTurn.pause`/`resume`) and flow again as soon as it stops, so the passenger can interrupt, and the pause also keeps the reply from being re-heard as a question.
- **Single-Speaker Audio Architecture (rebuilt Chunk 43)**: The Gemini Live native PCM playback path was removed entirely. `AudioSpeechEngine.speak` (Web SpeechSynthesis on web, device `TextToSpeech` on Android, markdown-sanitized, `onAudioEnded` callback) is the ONLY speech producer in the app — every reply is spoken exactly once through one stop-before-speak utterance. There is no TTS arbiter, no grace window, and no second audio path; do not reintroduce native PCM playback without redesigning the single-voice contract. For the same reason the bridge's `startPlayback`/`writePlayback`/`stopPlayback` calls and `NativeAudioChannel.onAudioPcmChunk` consumers are deliberately unwired: `AudioTrack` is built and tested but nothing feeds it model audio yet.
- **Accessibility & Touch Target Standards**: All interactive controls conform to 48x48dp minimum tap target sizes (WCAG 2.2). Platform `TextScaler` is preserved without artificial clamping per Astra P0 requirements, supporting responsive reflow at large accessibility text sizes.
- **Home & Usability Contract (Chunk 47)**: Home cards are neutral surfaces with a single `#007AFF` accent bar — red (`#E11D48`) is reserved for Emergency SOS, which sits 2nd in the default order. Saved Places opens the full `SavedPage` via `Navigator.push` (no bottom-sheet variant; focus returns on pop). Home/search navigation has a 500 ms double-tap guard. Checkout fare/pay stacks below 360 dp and wraps above so 300% text scale never overflows. Live GPS screens show an `Updated HH:MM:SS` timestamp from telemetry as plain text (never a live region — the stream ticks too often); manual refresh announces politely through `AnnouncementCoordinator`.
- **Resource Lifecycle Disposals**: `LiveLocationScreen`, `TicketController`, and speech sessions cancel active `StreamSubscription` and `Timer` instances in `dispose()` to eliminate memory leaks and background CPU cycles.
- Web speech features use conditional imports (`dart:html`, `dart:js`, `dart:js_util`) — only compile on web target.
- **Single Voice Surface (floating assistant removed)**: The floating BusBuddy AI bubble and multitasking window were removed (Chunk 42, double-voice fix). Full-screen `GeminiLiveScreen` is the app's sole voice/chat assistant surface and its sole audio session owner; all "Ask BusBuddy" entry points (home cards, ticket pages, settings) push it directly via `Navigator.push`. Do not reintroduce a second audio/TTS owner without redesigning the single-speaker contract (the old `TtsFallbackArbiter` was deleted in Chunk 43 and must not be resurrected as a second voice path).
- **Integer Paise Monetary Invariant**: All currency calculations are strictly represented in integer paise (`1 INR = 100 paise`) in `FareEngine` and `FareQuote`. Zero floating-point arithmetic is permitted for financial logic.
- **Composition Root**: `AppServiceLocator` (`lib/core/di/service_locator.dart`) is the sole dependency injection root. Subscriptions and resources implement `AsyncDisposable`.
- **Lexical Scope & Models**: Pure-Dart entities reside in `lib/domain/`. `lib/data/models/transport_models.dart` imports and exports `Stop` (`import '../../domain/transit/entities/stop.dart'`).
- **Architecture Decision Records**: Formal ADRs are recorded under `docs/adr/`: `ADR-001` (Domain & A11y Contracts), `ADR-002` (Accessibility & Safety Architecture), `ADR-003` (Production Readiness & Audit Resolution), `ADR-004` (Android Native Voice I/O & Spoken-Question Audio-In).
- OpenStreetMap tiles + OSRM routing require network; tests log 400s for tile requests.
- `create_research_doc.py` requires `python-docx` (executable with Python 3.12 or via virtual environment such as `/home/pavan/TrustRAG/.venv/bin/python create_research_doc.py`).

