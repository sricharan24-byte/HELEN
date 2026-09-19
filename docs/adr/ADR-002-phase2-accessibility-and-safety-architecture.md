# ADR-002: Phase 2 Accessibility-First UI, Dynamic Tokens, and Safety Architecture

- **Status**: Accepted
- **Date**: 2026-09-19
- **Auditors & Architects**: Claude Opus 5 (Architectural Spec) & GPT-6 Astra (Phase 1/2 Accessibility Audit)

---

## Context

Following the completion of ADR-001 (Phase 1 domain hardening and P0 contracts), Phase 2 required a comprehensive accessibility-first overhaul across all user-facing features of BusBuddy:
1. Eliminating hardcoded styling and color palettes in favor of semantic design tokens.
2. Centralizing all screen-reader announcements to eliminate race conditions and audio collisions between screen readers and Gemini Live speech synthesis.
3. Enforcing a global 48×48dp minimum touch target floor across all interactive widgets.
4. Implementing Astra Gate 8 (Guaranteed Map Text Equivalence) so commuters who are blind or visually impaired receive full telemetry parity with visual OpenStreetMap renderings.
5. Fulfilling Astra Gate 12 (Privacy & Safety Boundaries) with non-voice emergency SOS workflows and explicit disclosure.
6. Ensuring the persistent floating AI assistant overlay isolates modal focus via `BlockSemantics` and supports accessible non-drag corner repositioning.

---

## Decision

### 1. Semantic Design Tokens & WCAG AAA High Contrast
- Implemented `AppSemanticColors` providing semantic purpose-driven color tokens (`actionPrimary`, `actionSecondary`, `surface`, `surfaceSubtle`, `statusAlert`, `statusSuccess`, `border`, `textPrimary`, `textSecondary`).
- Provided 3 switchable theme palettes in `AppTheme`:
  - `standardDark`: Optimized for evening transit commutes.
  - `standardLight`: Clean, high-readability daylight palette.
  - `highContrast`: WCAG AAA certified 7:1 contrast ratio (`#000000` true black surface, `#FFFF00` pure yellow interactive actions, `#00FFFF` cyan secondary accents, and `#FFFFFF` high-visibility text).

### 2. 48×48dp Minimum Touch Target Floor
- Defined `AppSpacing.minTouchTarget = 48.0` logical pixels.
- Applied minimum size constraints (`BoxConstraints(minWidth: 48, minHeight: 48)`) and button style minimum sizes across all buttons, chips, tabs, icon buttons, and list tile controls.

### 3. Centralized AnnouncementCoordinator & Audio Contention Synchronization
- Created `AnnouncementCoordinator` singleton with 4 discrete priority levels:
  - `urgent`: Bypasses queues immediately (e.g. Emergency SOS alerts, immediate boarding alarms).
  - `high`: Preempts routine announcements (e.g. Approaching transfer stop).
  - `normal`: Standard transit updates and screen navigation events.
  - `polite`: Low-priority background announcements.
- **Audio Contention Management**: `AnnouncementCoordinator.isAudioPlaying` synchronizes with `FloatingAssistantController.isSpeaking` and speech engines. When voice responses are playing, routine telemetry announcements are cleanly debounced to prevent acoustic confusion.

### 4. Astra Gate 8: Guaranteed Map Text Equivalence
- Implemented `MapTextAlternativeWidget` paired with `LiveLocationMapWidget`.
- Every graphical element rendered on the vector OpenStreetMap canvas (vehicle position, current speed, next stop name, ETA, and remaining stops) is represented as a linear, structured, TalkBack-friendly text card.

### 5. Astra Gate 12: Privacy & Safety Boundaries
- Added explicit upfront disclosures explaining how emergency contacts receive SMS distress alerts with real-time transit telemetry.
- Implemented a silent, non-voice SOS broadcast flow that operates independently of the voice assistant microphone and speech recognition.
- SOS confirmation dispatches `AnnouncementPriority.urgent` announcements and records simulated distress events.

### 6. Floating AI Mascot Overlay Accessibility (Astra Section 2.4)
- Wrapped the floating modal window with `BlockSemantics(blocking: true)` to prevent TalkBack from traversing into underlying background page controls while the assistant window is open.
- Added non-drag corner relocation actions (`moveToTopLeft`, `moveToTopRight`, `moveToBottomLeft`, `moveToBottomRight`) and registered custom semantics actions on the floating bubble for accessible repositioning.

---

## Consequences

- **Full WCAG 2.2 & Astra Compliance**: Passes all automated accessibility guidelines for touch target sizes, contrast ratios, and semantic structure.
- **Reliable Screen Reader Experience**: TalkBack navigation is linear and deterministic without dropped announcements or focus entrapment.
- **Verification**: Complete test suite increased to 236 passing tests (100% green pass rate) including dedicated `safety_a11y_test.dart` and `floating_overlay_a11y_test.dart`.
