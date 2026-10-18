# BusBuddy 🚌
> **Accessible Public Transport & Digital Ticket Booking Assistant**
> *Vellore Institute of Technology (VIT) → Katpadi Railway Station → Vellore Central Corridor*

[![Flutter](https://img.shields.io/badge/Framework-Flutter%203.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Language-Dart-0175C2?logo=dart)](https://dart.dev)
[![OpenStreetMap](https://img.shields.io/badge/Map-OpenStreetMap%20%2B%20OSRM-7EBC6F?logo=openstreetmap)](https://www.openstreetmap.org)
[![CI](https://github.com/sricharan24-byte/HELEN/actions/workflows/ci.yml/badge.svg)](https://github.com/sricharan24-byte/HELEN/actions/workflows/ci.yml)
[![Tests](https://img.shields.io/badge/Tests-see%20CI%20evidence-16A34A)](https://github.com/sricharan24-byte/HELEN/actions/workflows/ci.yml)
[![Accessibility](https://img.shields.io/badge/Accessibility-WCAG%202.2%20AAA-brightgreen)](https://www.w3.org/WAI/standards-guidelines/wcag/)

---

## 📌 Project Overview

BusBuddy is an accessible public transport assistant mobile prototype for commuters — with a
dedicated focus on blind and low-vision passengers — on the **Vellore / Katpadi** bus corridors of
Tamil Nadu, India. It combines realtime mapping, OSRM turn-by-turn routing, digital ticket booking
with concession fares, emergency safety sharing, and Gemini Live natural-language voice control.

---

## 🌟 Key Features

### 🎙️ 1. Gemini Live voice assistant (`GeminiLiveScreen`)
- Full-screen assistant: glowing audio orb, live transcription, prompt chips — the app's **only**
  voice/chat surface and audio-session owner (the old floating bubble/multitasking window was
  removed in Chunk 42 and must not be reintroduced).
- **Live engine**: Google Gemini Multimodal Live API (`models/gemini-3.8-live`) over WebSocket
  (`wss://generativelanguage.googleapis.com/ws/.../BidiGenerateContent`), gated on key validation;
  simulated voice input is debug/demo-only (BUS-P0-06).
- **5 official Google voices** — `Aoede` (default), `Kore`, `Charon`, `Puck`, `Fenrir` — via Voice
  Assistant Settings or `--dart-define=GEMINI_VOICE`.
- **Continuous hands-free listening**: auto-restart on silence (web), stream kept open across turns
  (Android) with barge-in/interruption support. Microphone failures never end silently: the screen
  shows the browser's own reason and the input devices it can actually see.
- **Natural transit answers**: tool calls execute in the background; the assistant never reads raw
  function names or JSON aloud.
- **Single-speaker output**: model audio when Gemini streams it; device TTS only for audio-less
  turns — exactly one voice per turn (see AGENTS.md).
- Spoken queries trigger real actions: live bus map, route search, concession checkout, SOS
  broadcast/sharing — with emergency SOS disambiguated from general help.

### 🗺️ 2. OpenStreetMap & OSRM turn-by-turn routing
- `flutter_map` + `latlong2` OSM tiles centered on Vellore / Katpadi (`12.9692° N, 79.1559° E`);
  OSRM driving polylines snap route geometry to physical roads (Katpadi Road / NH 75) instead of
  straight lines.
- 18 landmarks with verified GPS coordinates; a monotonic telemetry reducer discards stale or
  jittered GPS packets.
- Route-only segment map: only the passenger's boarding→alighting segment is drawn.

### 🎟️ 3. Ticket booking & checkout suite
- 3-step flow (destination → bus → live trip) — the Plan tab's root. Concession checkout:
  `General`, `Student` (40 % off), `Senior` (40 % off).
- Payment via UPI (GPay / PhonePe / Paytm), card, or BusBuddy Wallet — wallet settles
  automatically once the agent confirms; UPI/card always keep the on-screen confirmation step.
- QR boarding pass (`BUSBUDDY-PASS-xxxxxx`) with validity window and fare receipt; live progress
  timeline (0/20/50/90 %); all fare math is integer paise (`FareEngine`).

### 🛡️ 4. Emergency SOS & trip sharing
- 1-tap SOS broadcast with live GPS coordinates to trusted contacts; `SafetySharingPage`
  pre-populated from the active ticket; instant WhatsApp/SMS live-tracking links.

### ♿ 5. Accessibility
- 48×48 dp minimum tap targets; platform `TextScaler` preserved up to 300 % with responsive
  `Wrap`/scroll reflow (Astra P0, BUS-P0-07); WCAG 2.2 AA/AAA-contrast semantic tokens;
  high-contrast and dark themes; TalkBack/VoiceOver semantics, focus restoration, and live-region
  announcements.

### ⚙️ 6. Customizable home
- Reorder / show / hide / reset home cards (`HomeScreenCustomizationPage`) with touch
  drag-and-drop **and** accessible Move Up / Move Down buttons (announced), reactive in saved
  order with an accessible empty state and 1-tap restore; voice commands ("Customize my home
  screen", "Reset home layout"). Saved places are one-tap star chips inside the booking and
  Find-a-Place pickers — no separate page.

---

## 🏛️ Clean Architecture & Design Invariants

Strict separation of pure business logic, application state, and device/framework infrastructure:

1. **Domain (`lib/domain/`, zero Flutter coupling)** — pure-Dart entities (`Stop`, `TransitRoute`,
   `StopOccurrence`, `Ticket`, `Fare`, `FareQuote`, `TelemetryState`, `AssistantCommand`);
   `FareEngine` integer-paise arithmetic with half-up 40 % concessions (`Result<T>` monad for
   failures); `AssistantCommandGateway` confirmation gate for SOS broadcasts, location sharing,
   and ticket purchases.
2. **Core (`lib/core/`)** — `AppServiceLocator` DI composition root (lazy init, test overrides,
   `AsyncDisposable` teardown); `AnnouncementCoordinator` 4-tier priority queue (`urgent > high >
   normal > polite`) with TTL, ducking, and speech coordination; semantic design tokens
   (`AppSemanticColors`, `AppSpacing`, `AppTheme`) verified for WCAG 2.2 AA (4.5:1) / AAA (7:1),
   48 dp touch floor, uncapped text scaling.
3. **Data (`lib/data/`)** — `TelemetryReducer` monotonic sequencing (drops jittered/stale GPS);
   OSRM resilience (5 s timeout, 512 KB clamp, geometric fallback polyline); process-death
   restoration of active ticket/journey via `SharedPreferences`.

---

## 🛡️ Production Readiness & Audit Resolutions (ADR-001 · ADR-002 · ADR-003 · ADR-004)

All **7 P0 release blockers** and **10 P1 critical tasks** audited by **GPT-6 Astra** and
**Claude Opus 5** are resolved — integer-paise fares, DI composition root, continuous-listening
debounce, lifecycle disposals, safety gateway, production gating of simulated voice, uncapped
text scaling (P0-01…07); monotonic telemetry, stop-occurrence disambiguation, announcement
arbiter, overlay semantics/focus/48 dp, 200–300 % reflow, semantic de-duplication, OSRM
resilience, voice permission recovery/backoff, machine-verified contrast, process-death
restoration (P1-01…10). Item-by-item contracts live in
[`ADR-003`](docs/adr/ADR-003-production-readiness-and-audit-resolution.md), along with the
BUS-P2-01…04 follow-ups (Android permission minimization, release shrinking, CI as source of
truth, strict static analysis). Android voice I/O specifics are in
[`ADR-004`](docs/adr/ADR-004-android-native-voice-io.md).

---

## 📁 Repository Structure

```
BusBuddy/
├── lib/
│   ├── main.dart          # entry point; MaterialApp.builder hosts the AI glow frame
│   ├── core/              # a11y, di, settings, theme, tokens, shared widgets
│   ├── domain/            # pure-Dart: assistant, core (Result), ticketing, transit
│   ├── data/              # datasources, models, repositories, OSRM routing service
│   └── features/          # home, journey, route_search, tickets, ai_assistant, safety,
│                          # alerts, settings, saved, adaptive_ui, navigation (shell)
├── test/                  # mirrors lib/ (a11y, core, data, domain, features, platform, integration)
├── android/               # BusBuddyVoiceChannel (native voice I/O) + release config
├── docs/
│   ├── adr/               # ADR-001 … ADR-004
│   ├── audit/             # GPT-6 Astra & Claude Opus 5 audit sources
│   ├── superpowers/       # plans & specs
│   └── archive/           # full progress-log archive
├── tool/                  # verify_docs.sh, release_smoke.sh, startup_memory_benchmark.sh
├── create_research_doc.py # research document generator (python-docx)
├── progress.md            # compact progress log (full archive under docs/archive/)
├── AGENTS.md              # repository contracts for agents
└── README.md
```

---

## 🧪 Automated Tests

```bash
flutter test
```

> **CI is the source of truth (BUS-P2-03)** — `.github/workflows/ci.yml` runs
> `flutter analyze --fatal-infos --fatal-warnings`, the full test suite, `tool/ci/verify_docs.sh`,
> minified release APK/AAB and web builds, and uploads an evidence artifact stamped with the
> audited commit SHA. Local `flutter test` stays green for domain contracts (integer paise, OSRM
> failure states, monotonic telemetry), Gemini Live handshake/backoff, announcement preemption,
> single-speaker enforcement, WCAG contrast, the Android spoken-turn state machine and native
> audio-channel degradation (ADR-004), permission minimization + runtime permission flow
> (BUS-P2-01), release shrink config (BUS-P2-02), docs/ADR claim checks (BUS-P2-03), and
> process-death restoration.

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.19 or higher)
- [Dart SDK](https://dart.dev/get-dart)
- Python 3.x with `python-docx` (for research document generation)

### Installation & Execution

1. **Clone the repository**:
   ```bash
   git clone https://github.com/sricharan24-byte/HELEN.git
   cd HELEN
   ```

2. **Install Flutter dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run the app locally**:
   - In Chrome (required for Gemini Live voice features):
     ```bash
     flutter run -d chrome --dart-define=GEMINI_API_KEY=your_key --dart-define=GEMINI_VOICE=Aoede
     ```
     *(The key and voice persona can also be set interactively in Voice Assistant Settings; the
     key is never written to disk.)*
   - If Chrome fails to attach (`Failed to launch browser after 3 tries`, typical on a loaded
     machine), the reliable fallback is `flutter run -d web-server --web-port=8080`, then open
     `http://localhost:8080` — hard-refresh (Ctrl+Shift+R) after a rebuild.
   - On an Android phone (sideload — debug-signed unless a release keystore is configured):
     ```bash
     flutter build apk --release --dart-define=GEMINI_API_KEY=your_key
     ```
     *APK at `build/app/outputs/flutter-apk/app-release.apk`; without the `--dart-define` the key
     is entered in the app instead.*
   - On Linux desktop:
     ```bash
     flutter run -d linux
     ```

4. **Generate the research document**:
   ```bash
   python3 create_research_doc.py
   ```
   *Writes `BusBuddy_Implementation_Research_and_UI_Design.docx` to the repo root.*

---

## 📜 License & Citation

Developed as an accessible public transport research prototype for the Vellore and Katpadi urban corridors.
