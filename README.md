# BusBuddy 🚌
> **Accessible Public Transport & Digital Ticket Booking Assistant**  
> *Vellore Institute of Technology (VIT) → Katpadi Railway Station → Vellore Central Corridor*

[![Flutter](https://img.shields.io/badge/Framework-Flutter%203.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Language-Dart-0175C2?logo=dart)](https://dart.dev)
[![OpenStreetMap](https://img.shields.io/badge/Map-OpenStreetMap%20%2B%20OSRM-7EBC6F?logo=openstreetmap)](https://www.openstreetmap.org)
[![Tests](https://img.shields.io/badge/Tests-111%2F111%20Passed%20(100%25)-16A34A)](#-automated-tests)

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
- **Adaptive Text Scaling Clamping**: Text scaling factors are clamped between 0.85x and 2.0x, ensuring large text accessibility options never induce layout overflow.
- **High-Contrast & Dark Mode**: Dedicated high-contrast color scheme and dark themes optimized for low-vision visibility and night commutes.
- **Screen Reader First (TalkBack / VoiceOver)**: Explicit semantic descriptions, live region announcements, and focus management across all screens.

### ⚙️ 7. User-Created Customizable Home Screen & Personalization Hub
- **User-Created Interface (`HomeScreenCustomizationPage`)**: Commuters can reorder, show, hide, and reset home screen components (Route Search, Journey Assistant, Tickets, Saved Places, Gemini Live, Live Bus Map, Corridor Alerts, Emergency SOS, Settings).
- **Dual Touch & Non-Touch Accessible Reordering**: Provides touch drag-and-drop (`ReorderableListView`) alongside accessible `Move Up` and `Move Down` buttons with full TalkBack semantics announcements (`SemanticsService.announce`), catering to blind and low-vision commuters.
- **Dynamic Home Screen Rendering**: Reactive card stack that automatically excludes hidden features and renders cards in the commuter's saved custom order, with an accessible empty state and 1-tap restore action.
- **Voice Control Alternative**: Commuters can customize or reset their home layout via Gemini Live voice commands (*"Customize my home screen"*, *"Reset home layout"*).
- **Visual & Assistive Adjustments**: High-contrast mode toggle, dynamic text scaling (`Large`, `Extra Large`), and reduced clutter navigation.

---

## 📁 Repository Structure

```
BusBuddy/
├── lib/
│   ├── main.dart                       # App entry point, Overlay tree architecture & theme initialization
│   ├── data/
│   │   ├── datasources/
│   │   │   ├── local_transport_data_source.dart   # Real GPS stop fixtures & route sequences
│   │   │   └── live_bus_movement_engine.dart     # Simulated live bus GPS movement stream
│   │   ├── models/
│   │   │   ├── transport_models.dart             # Stop, Route, BusLocation models
│   │   │   └── ticket_model.dart                 # Ticket, PassengerType, PaymentMethod domain
│   │   ├── repositories/
│   │   │   ├── transport_repository.dart         # Transport search repository interface
│   │   │   └── ticket_repository.dart            # Ticket storage and active pass management
│   │   └── services/
│   │       └── osrm_routing_service.dart         # OSRM road polyline API service & fallbacks
│   └── features/
│       ├── home/                         # Distraction-free full screen task landing page
│       ├── tickets/                      # Booking checkout dialog, 3-step suite, my tickets & passbook
│       ├── journey/                      # Interactive OpenStreetMap widget & live bus tracker
│       ├── ai_assistant/                 # Gemini Live screen, floating assistant bubble & mini window
│       │   ├── floating_assistant_controller.dart # Central state for bubble, mic, mute & chat
│       │   ├── floating_ai_assistant_overlay.dart # Draggable bubble & compact chat/voice card
│       │   ├── floating_chat_message.dart         # Chat message & action button domain model
│       │   ├── gemini_live_screen.dart            # Full-screen conversational visualizer & voice orb
│       │   ├── gemini_live_session.dart           # WebSocket client for models/gemini-3.8-live
│       │   └── audio_speech_engine.dart           # Multi-modal PCM/TTS unified audio playback
│       ├── safety/                       # Emergency contact manager & SOS broadcast page
│       ├── settings/                     # Master settings, accessibility, personalization, voice settings
│       ├── alerts/                       # Real-time corridor delay & status alerts
│       └── saved/                        # Saved places & digital passbook tab
├── test/                                 # Automated unit and widget test suite
│   ├── features/floating_ai_assistant_test.dart # Tests for floating bubble, mute & mini window
│   ├── features/gemini_live_test.dart           # Tests for Gemini Live intent & visualizer orb
│   └── ...                               # 120+ unit and widget tests
├── create_research_doc.py                # Research doc generator script using python-docx
├── progress.md                           # Detailed implementation progress log (Chunks 1-23)
└── README.md                             # Project overview & documentation
```

---

## 🧪 Automated Tests

Run the full Flutter automated test suite:
```bash
flutter test
```

> **Test Suite**: Comprehensive unit and widget tests covering live GPS movement, OSRM fallback routing, ticket repository, passenger concession fare math, Gemini Live intent classification and websocket protocol, floating assistant bubble dragging and window muting, and widget tests for all primary screens and modals.

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
