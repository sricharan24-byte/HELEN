# Repository Guidelines

This guide records repository-specific practices and agent workflow.


All BusBuddy source code, tests, documentation, progress files, and generated project artifacts must be stored under `/home/pavan/BusBuddy`. External folders may be read as reference inputs only; temporary extraction directories are not deliverable locations.

## Project Structure
This repository contains a Flutter/Dart-based accessible public transport assistant prototype called BusBuddy, focused on a Vellore, India demonstration. The codebase is organized around journey modeling, route search, accessible UI, and realtime bus tracking. A Python script (`create_research_doc.py`) generates the associated Word document using the `python-docx` library. Source code (.dart files) is present under `lib/` with feature-based organization (`features/`, `core/`, `data/`).

## Build / Test / Development Commands
- `flutter pub get` — resolve dependencies
- `flutter analyze` — static analysis (0 errors)
- `flutter test` — run all widget/unit tests (354 tests, 100% green)
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

## Commit / PR Guidance
- No commit message conventions, PR template, or branch naming policy documented. Standard Git practices apply.

## Configuration / Document-Generation Notes
- `create_research_doc.py` depends on `python-docx` package (imported as `from docx import Document`).
- Outputs to `BusBuddy_Implementation_Research_and_UI_Design.docx` in the same directory.
- No `.env`, `requirements.txt`, `pubspec.yaml`, `flavor` configurations, or CI files present.

## Key Runtime Notes
- **Gemini Live voice requires Chrome web** (`flutter run -d chrome`) and a valid Google AI Studio API key (set via in-app dialog or `--dart-define=GEMINI_API_KEY`).
- Current Live API model: `models/gemini-3.8-live` (configured in `AppSettingsController` default).
- **Official Google Prebuilt Voices**: Supported voices are `Aoede` (default female), `Kore` (calm female), `Charon` (informative male), `Puck` (upbeat male), and `Fenrir` (deep male). Configurable in Voice Assistant Settings or via `--dart-define=GEMINI_VOICE=Aoede`.
- **Natural Voice Conversational Delivery**: The assistant executes tool calls seamlessly in the background and delivers concise, natural transit answers without verbally reading out raw JSON, function signatures, or execution mechanics.
- **Persistent Continuous Hands-Free Listening Mode**: Once the microphone is enabled, speech recognition stays continuously active across conversational turns, auto-restarting on silence/timeout, auto-resuming listening 350ms after the AI finishes speaking, and debouncing acoustic feedback.
- **Single-Speaker Audio Architecture (rebuilt Chunk 43)**: The Gemini Live native PCM playback path was removed entirely. `AudioSpeechEngine.speak` (Web SpeechSynthesis, markdown-sanitized, `onAudioEnded` callback) is the ONLY speech producer in the app — every reply is spoken exactly once through one stop-before-speak utterance. There is no TTS arbiter, no grace window, and no second audio path; do not reintroduce native PCM playback without redesigning the single-voice contract.
- **Accessibility & Touch Target Standards**: All interactive controls conform to 48x48dp minimum tap target sizes (WCAG 2.2). Platform `TextScaler` is preserved without artificial clamping per Astra P0 requirements, supporting responsive reflow at large accessibility text sizes.
- **Resource Lifecycle Disposals**: `LiveLocationScreen`, `TicketController`, and speech sessions cancel active `StreamSubscription` and `Timer` instances in `dispose()` to eliminate memory leaks and background CPU cycles.
- Web speech features use conditional imports (`dart:html`, `dart:js`, `dart:js_util`) — only compile on web target.
- **Single Voice Surface (floating assistant removed)**: The floating BusBuddy AI bubble and multitasking window were removed (Chunk 42, double-voice fix). Full-screen `GeminiLiveScreen` is the app's sole voice/chat assistant surface and its sole audio session owner; all "Ask BusBuddy" entry points (home cards, ticket pages, settings) push it directly via `Navigator.push`. Do not reintroduce a second audio/TTS owner without re-wiring `TtsFallbackArbiter.shared`.
- **Integer Paise Monetary Invariant**: All currency calculations are strictly represented in integer paise (`1 INR = 100 paise`) in `FareEngine` and `FareQuote`. Zero floating-point arithmetic is permitted for financial logic.
- **Composition Root**: `AppServiceLocator` (`lib/core/di/service_locator.dart`) is the sole dependency injection root. Subscriptions and resources implement `AsyncDisposable`.
- **Lexical Scope & Models**: Pure-Dart entities reside in `lib/domain/`. `lib/data/models/transport_models.dart` imports and exports `Stop` (`import '../../domain/transit/entities/stop.dart'`).
- **Architecture Decision Records**: Formal ADRs are recorded under `docs/adr/`: `ADR-001` (Domain & A11y Contracts), `ADR-002` (Accessibility & Safety Architecture), `ADR-003` (Production Readiness & Audit Resolution).
- OpenStreetMap tiles + OSRM routing require network; tests log 400s for tile requests.
- `create_research_doc.py` requires `python-docx` (executable with Python 3.12 or via virtual environment such as `/home/pavan/TrustRAG/.venv/bin/python create_research_doc.py`).

