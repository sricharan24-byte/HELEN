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

**BusBuddy** is an accessible public transport assistant mobile prototype engineered to assist commuters—with a dedicated focus on blind and low-vision passengers—navigating the bus corridors of **Vellore** and **Katpadi** in Tamil Nadu, India.

The application combines real-time interactive mapping, turn-by-turn street routing, digital ticket booking, concession fare handling, emergency safety contact sharing, and natural language Gemini Live voice control into an inclusive, accessible user experience.

---

## 🌟 Key Features

### 🎙️ 1. Gemini Live Conversational Voice Control Layer
- **Real-Time Voice Interface (`GeminiLiveScreen`)**: Animated glowing audio visualizer orb, gradient sparkle branding (`#007AFF`), live speech transcription, and spoken prompt chip shortcuts.
- **Dual Engine Architecture**:
  - **🔒 Grounded Local Engine**: Works 100% offline for demo and testing without network latency or API key requirement.
  - **⚡ Live Cloud API Engine**: Connects to Google Gemini Multimodal Live API (`models/gemini-3.8-live`) over WebSockets (`wss://generativelanguage.googleapis.com/ws/.../BidiGenerateContent`).
- **Official Google Prebuilt Voices**: Built-in support for all 5 official Google Gemini Live voices:
  - `Aoede` (Default — breezy, natural female)
  - `Kore` (Calm, balanced female)
  - `Charon` (Informative, measured male)
  - `Puck` (Upbeat, lively male)
  - `Fenrir` (Deep, resonant male)  
  *Configurable via Voice Assistant Settings or via `--dart-define=GEMINI_VOICE=Aoede`.*
- **Natural Transit Communication**: Clean background function/tool execution where the assistant communicates naturally in concise transit statements rather than reading raw function names or JSON schemas aloud.
- **Persistent Continuous Hands-Free Listening Mode**: Once the microphone is enabled, speech recognition stays continuously active across multi-turn conversations. Automatically restarts on browser silence timeouts, automatically resumes listening 350ms after the AI finishes speaking, and features acoustic echo debouncing to prevent feedback.
- **Hybrid Voice Output Pipeline (24kHz PCM + Web SpeechSynthesis)**: Streams native 24kHz linear PCM audio chunks directly from Gemini Live over WebSocket with automatic drift-snapping. Seamlessly falls back to Web SpeechSynthesis for text-only turns, REST fallback, or offline usage, ensuring spoken audio delivery under all operating conditions. Global autoplay policy unlock listeners across touch/click/pointer events guarantee instant sound playback on web.
- **Full-Duplex Conversational Flow**: Real-time user barge-in / speech interruption detection and automatic microphone re-listening once Gemini completes a turn.
- **Tool Execution**: Spoken queries trigger live tool actions (`"Where is my bus?"` → Live GPS Map; `"Find bus to Katpadi"` → Route search; `"Book ticket"` → Concession checkout; `"Share location"` → SOS broadcast).
- **Conversational Disambiguation**: Intelligently differentiates general inquiries (*"Can you help me find a bus?"*) from emergency SOS distress commands.

### 🫧 2. Floating BusBuddy AI Bubble & Multitasking Window Overlay
- **Draggable Floating Mascot Bubble**: A 64x64 glowing, animated mascot orb that floats persistently across all app screens via `MaterialApp.builder`. Commuters can freely drag it anywhere on the screen with boundary edge clamping.
- **Compact Floating Window**: Tapping the bubble expands an interactive chat and voice card without leaving the current screen or interrupting ongoing tasks (e.g., viewing live maps or booking passes).
- **Real-Time Mic Mute / Unmute**: Allows passengers to toggle voice mute at any moment. Tapping the mic orb while speaking silences AI speech instantly; tapping while listening pauses the microphone.
- **Conversational Chat Feed & Quick Actions**: Shows user queries and AI transit advice with contextual navigation buttons (`📍 Open Live Bus Map`, `🎫 Book Bus Ticket`, `🚌 View Route Options`).
- **Quick Prompt Chips & Keyboard Chat**: Tap-to-ask chips for rapid transit lookups alongside a typed message input field.
- **Expand & Minimize**: Easily collapse back to the unobtrusive floating bubble or tap the full-screen button to transition directly into the immersive `GeminiLiveScreen`.

### 🗺️ 3. Real OpenStreetMap & OSRM Turn-by-Turn Routing
- **Interactive OpenStreetMap Tiles**: Integrated `flutter_map` and `latlong2` vector tiles centered on Vellore & Katpadi (`12.9692° N, 79.1559° E`).
- **OSRM Turn-by-Turn Road Polylines**: Calls the Open Source Routing Machine (OSRM) driving API to snap route geometry to physical roads (Katpadi Road / NH 75) instead of straight lines.
- **Verified Geographic Stop Coordinates**: Real GPS lat/lng coordinates for 18 landmarks, ensuring direct northbound (`VIT` → `Katpadi Station`) and southbound (`VIT` → `Old Bus Stand`) progress without backtracking.

### 🎟️ 4. Digital Ticket Booking & Checkout Suite
- **3-Step Prototype Suite**: Seamless workflow from destination search, to available bus selection, to live trip tracking.
- **Interactive Concession Checkout Modal (`BookingCheckoutDialog`)**:
  - **Passenger Types**: `General`, `Student` (40% concession discount), `Senior` (40% concession discount).
  - **Payment Options**: `UPI` (GPay / PhonePe / Paytm), `Credit / Debit Card`, `BusBuddy Wallet`.
  - **Instant Digital Boarding Pass**: Generates unique QR code pass (`BUSBUDDY-PASS-xxxxxx`), valid time window, and fare receipt.
- **Dynamic Live Bus Progress Timeline**: Visual timeline node tracker updates dynamically based on live bus movement metrics across 4 threshold stages (0%, 20%, 50%, 90% completion).
- **Route-Only Segment Map**: Displays only the passenger's boarding-to-alighting segment on the map, eliminating visual clutter from unrelated stops.

### 🛡️ 5. Emergency SOS & Live Trip Sharing
- **1-Tap Emergency Broadcast**: Triggers SOS notifications to trusted contacts with live GPS coordinates.
- **Direct Safety Navigation**: Navigates directly into the full `SafetySharingPage` with active ticket details pre-populated.
- **Trip Tracking Links**: Generates instant WhatsApp/SMS live tracking links for family and caregivers.

### ♿ 6. Accessibility & Inclusivity Standards Compliance
- **Touch Target Sizing**: All interactive buttons, prompt chips, and action cards strictly enforce the 48x48dp minimum tap target size (WCAG 2.2 / Material Design).
- **Uncapped Platform Text Scaling**: Platform `TextScaler` is fully preserved without artificial ceiling clamping per Astra P0 contracts, with responsive reflow, scrolling, and wrapping preventing layout truncation at large accessibility display settings.
- **High-Contrast & Dark Mode**: Dedicated high-contrast color scheme and dark themes optimized for low-vision visibility and night commutes.
- **Screen Reader First (TalkBack / VoiceOver)**: Explicit semantic descriptions, live region announcements, and focus management across all screens.

### ⚙️ 7. User-Created Customizable Home Screen & Personalization Hub
- **User-Created Interface (`HomeScreenCustomizationPage`)**: Commuters can reorder, show, hide, and reset home screen components (Route Search, Journey Assistant, Tickets, Saved Places, Gemini Live, Live Bus Map, Corridor Alerts, Emergency SOS, Settings).
- **Dual Touch & Non-Touch Accessible Reordering**: Provides touch drag-and-drop (`ReorderableListView`) alongside accessible `Move Up` and `Move Down` buttons with full TalkBack semantics announcements (`SemanticsService.announce`), catering to blind and low-vision commuters.
- **Dynamic Home Screen Rendering**: Reactive card stack that automatically excludes hidden features and renders cards in the commuter's saved custom order, with an accessible empty state and 1-tap restore action.
- **Voice Control Alternative**: Commuters can customize or reset their home layout via Gemini Live voice commands (*"Customize my home screen"*, *"Reset home layout"*).
- **Visual & Assistive Adjustments**: High-contrast mode toggle, dynamic text scaling (`Large`, `Extra Large`), and reduced clutter navigation.

---

## 🏛️ Clean Architecture & Design Invariants

BusBuddy follows strict **Clean Architecture** principles separating pure business logic, application state, and external device/framework infrastructure:

1. **Pure-Dart Domain Layer (`lib/domain/`)**:
   - **Zero Framework Coupling**: Pure Dart entities (`Stop`, `TransitRoute`, `StopOccurrence`, `Ticket`, `Fare`, `FareQuote`, `TelemetryState`, `AssistantCommand`) completely independent of Flutter `BuildContext` or platform APIs.
   - **Monetary Precision (`FareEngine`)**: Strictly calculates currency in integer paise (`1 INR = 100 paise`), eliminating floating-point financial drift. Standardized hop tiers and 40% student/senior concession discounts with half-up rounding.
   - **Result Pattern (`lib/domain/core/result.dart`)**: Functional `Result<T>` monad (`Result.success`, `Result.failure`) encapsulating failures without unhandled exception crashes.
   - **Safety Confirmation Gateway (`AssistantCommandGateway`)**: Destructive actions (Emergency SOS broadcast, location sharing, financial ticket purchase) require explicit confirmation modals before execution.

2. **Core Accessibility & System Foundation (`lib/core/`)**:
   - **Dependency Injection Root (`AppServiceLocator`)**: Composition root managing singletons, lazy initialization, test overrides, and async disposal via `AsyncDisposable`.
   - **Announcement Arbiter (`AnnouncementCoordinator`)**: 4-tier priority queue (`urgent > high > normal > polite`) with time-to-live expiration, audio ducking, and coordination with Gemini Live speech streams.
   - **Semantic Design Tokens (`AppSemanticColors`, `AppSpacing`, `AppTheme`)**: Mathematically verified WCAG 2.2 AA (4.5:1) and AAA (7.0:1) contrast tokens, strict 48×48dp minimum touch target floor, and platform text scaling preserved up to 300%.

3. **Data & Infrastructure Layer (`lib/data/`)**:
   - **Telemetry Reducer (`TelemetryReducer`)**: Enforces monotonic sequence numbers and generation IDs, discarding jittered or stale GPS packets.
   - **Network Resilience**: 5-second timeout and 512KB payload bounds on OSRM routing requests with linear geometric interpolation fallback.
   - **Process Death Restoration**: State serialization via `SharedPreferences` ensures persistent active ticket and journey recovery across Android process termination.

---

## 🛡️ Production Readiness & Audit Resolutions (ADR-001, ADR-002, ADR-003)

The system resolves all **7 P0 Release Blockers** and **10 P1 Critical Tasks** audited by **GPT-6 Astra** and **Claude Opus 5**:

| Task ID | Component | Specification & Production Contract |
|---|---|---|
| `BUS-P0-01` | **Fare Engine Precision** | Integer paise arithmetic, strict hop tiers, zero-hop rejection, and exact 40% concession rounding. |
| `BUS-P0-02` | **Service Locator DI** | Hardened `AppServiceLocator` composition root with single-flight initialization and lifecycle teardown. |
| `BUS-P0-03` | **Continuous Listening** | Automatic speech recognition restart on silence, acoustic echo debouncing, and 350ms resume debounce. |
| `BUS-P0-04` | **Lifecycle Disposals** | `AsyncDisposable` on repositories; zero orphaned streams, listeners, or timers across all controllers. |
| `BUS-P0-05` | **Safety Gateway** | Voice tool confirmation dialogs gating SOS broadcasts, location sharing, and ticket purchases. |
| `BUS-P0-06` | **Voice Simulation Gating** | Disabled by default in production; strictly gated behind debug configuration flags. |
| `BUS-P0-07` | **Uncapped Text Scaling** | Platform `TextScaler` preserved up to 300% with responsive `Wrap` and scrollable reflow containers. |
| `BUS-P1-01` | **Monotonic Telemetry** | Sequence reducer discarding out-of-order GPS updates, ensuring forward progress continuity. |
| `BUS-P1-02` | **StopOccurrence Disambiguation** | Accurate intermediate stop resolution on circular loops, bidirectional routes, and repeated transfer hubs. |
| `BUS-P1-03` | **Announcement Arbiter** | Priority queue arbiter with TTL expiration and Gemini Live speech ducking synchronization. |
| `BUS-P1-04` | **Overlay Accessibility** | Focus restoration to trigger controls, `BlockSemantics` isolation, and >= 48dp touch targets. |
| `BUS-P1-05` | **Responsive Layout Reflow** | Dynamic reflow with `ConstrainedBox` and `Wrap` preventing text clipping at high scaling. |
| `BUS-P1-06` | **Semantics De-duplication** | Elimination of duplicate TalkBack announcements and adherence to Heading Level 2 hierarchy. |
| `BUS-P1-07` | **OSRM Resilience** | 5s timeout, 512KB payload clamp, geometric fallback polyline, and retry banner. |
| `BUS-P1-08` | **Exponential Backoff & DOM** | Full-jitter exponential backoff (1s–16s) for WebSockets, permission recovery, and listener teardown. |
| `BUS-P1-09` | **WCAG 2.2 AAA Contrast** | Mathematically certified semantic color tokens for Standard Light, Dark, and High Contrast themes. |
| `BUS-P1-10` | **Process Death Restoration** | Shared preferences state restoration for active journey sessions and digital tickets. |

---

## 📁 Repository Structure

```
BusBuddy/
├── lib/
│   ├── main.dart                             # App entry point & global multi-layer Overlay architecture
│   ├── core/
│   │   ├── a11y/                             # AnnouncementCoordinator, EnlargingTextScaler, MapTextAlternative
│   │   ├── di/                               # AppServiceLocator composition root & AsyncDisposable
│   │   ├── settings/                         # AppSettingsController & persistent preferences
│   │   ├── theme/                            # AppTheme supporting Light, Dark & WCAG AAA High Contrast
│   │   ├── tokens/                           # AppSemanticColors, AppSpacing (48dp floor), StatusLevel
│   │   └── widgets/                          # AccessibleButton, StatusBanner, high-contrast primitives
│   ├── domain/                               # Pure-Dart Domain Layer (Zero Flutter Dependencies)
│   │   ├── assistant/                        # AssistantCommand, AssistantCommandGateway
│   │   ├── core/                             # Failure hierarchy & Result<T> monad
│   │   ├── ticketing/                        # Fare, FareEngine, FareQuote, Ticket entities
│   │   └── transit/                          # Stop, TransitRoute, StopOccurrence, TelemetryState
│   ├── data/
│   │   ├── datasources/                      # LocalTransportDataSource (GPS fixtures) & LiveBusMovementEngine
│   │   ├── models/                           # Route, BusLocation, JourneySelection, JourneySession
│   │   ├── repositories/                     # LocalTransportRepository, LocalTicketRepository
│   │   └── services/                         # OSRMRoutingService (turn-by-turn routing with fallback)
│   └── features/
│       ├── adaptive_ui/                      # Adaptive shortcuts modal & personalized views
│       ├── ai_assistant/                     # Gemini Live full-screen orb, Floating AI Assistant overlay & mini window
│       ├── alerts/                           # Real-time corridor delay & disruption alerts
│       ├── home/                             # Distraction-free full-screen task landing page
│       ├── journey/                          # Interactive OpenStreetMap canvas, LiveLocationMapWidget & controller
│       ├── route_details/                    # Stop timeline, road polyline & route information
│       ├── route_search/                     # Origin/destination search & available bus routes
│       ├── safety/                           # Emergency SOS broadcast & trusted contact location sharing
│       ├── saved/                            # Saved places & digital passbook tab
│       ├── settings/                         # Accessibility, Personalization & Voice Assistant settings
│       └── tickets/                          # BookingCheckoutDialog (concession modal), 3-step suite & passbook
├── test/                                     # Automated test suite (52 test files, 341 tests, 100% green)
│   ├── a11y/                                 # Announcement arbiter, contrast verification, reflow, semantics
│   ├── core/                                 # Accessible components, theme tokens, service locator tests
│   ├── data/                                 # Live telemetry ordering, OSRM failure states, persistence tests
│   ├── domain/                               # FareEngine integer precision, route segment resolution, Result monad
│   ├── features/                             # Voice assistant, booking checkout dialog, home customization
│   └── integration/                          # Process death restoration, DI lifecycle, ticket replay
├── docs/
│   ├── adr/                                  # ADR-001 (Phase 1), ADR-002 (Phase 2), ADR-003 (Production Readiness)
│   └── audit/                                # GPT-6 Astra & Claude Opus 5 audit specifications and feedback
├── .github/workflows/ci.yml                  # BUS-P2-03 CI: analyze, tests, docs, release builds, evidence
├── tool/
│   ├── ci/verify_docs.sh                     # BUS-P2-03 documentation & claim verification
│   ├── release_smoke.sh                      # BUS-P2-02 minified release + optional device smoke
│   └── startup_memory_benchmark.sh           # BUS-P2-02 cold/warm startup + PSS after nav cycles
├── create_research_doc.py                    # Research paper & specification generator (python-docx)
├── progress.md                               # Comprehensive engineering progress log
└── README.md                                 # Technical documentation & repository guide
```

---

## 🧪 Automated Tests

Run the complete Flutter automated test suite:
```bash
flutter test
```

> **Test Suite Quality**: **CI is the source of truth (BUS-P2-03)** — `.github/workflows/ci.yml` runs `flutter analyze --fatal-infos --fatal-warnings`, the full `flutter test` suite, `tool/ci/verify_docs.sh`, minified release APK + web builds, and uploads an evidence artifact stamped with the audited commit SHA and derived test count. Local `flutter test` remains green for domain contracts, integer paise precision, OSRM failure resilience, monotonic telemetry reducers, Gemini Live WebSocket handshake & exponential backoff, announcement queue preemption, floating overlay `BlockSemantics`, WCAG contrast verification, TTS fallback arbitration, Android permission minimization + runtime permission-flow contract (BUS-P2-01), release shrink config (BUS-P2-02), documentation/ADR claim checks (BUS-P2-03), and process death state restoration.

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.19 or higher)
- [Dart SDK](https://dart.dev/get-dart)
- Python 3.x with `python-docx` (for research document generation)

### Installation & Execution

1. **Clone the repository**:
   ```bash
   git clone https://github.com/pavan/BusBuddy.git
   cd BusBuddy
   ```

2. **Install Flutter dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run the app locally**:
   - In Chrome Debugger Mode (required for Gemini Live voice features):
     ```bash
     flutter run -d chrome --dart-define=GEMINI_API_KEY=your_key --dart-define=GEMINI_VOICE=Aoede
     ```
     *(Note: Gemini API key and voice persona can also be configured interactively within the in-app Voice Assistant settings.)*
   - In Linux Native Desktop Mode:
     ```bash
     flutter run -d linux
     ```

4. **Generate Research Document**:
   ```bash
   python3 create_research_doc.py
   ```
   *Generates `BusBuddy_Implementation_Research_and_UI_Design.docx` in the root directory.*

---

## 📜 License & Citation

Developed as an accessible public transport research prototype for Vellore and Katpadi urban corridors.
