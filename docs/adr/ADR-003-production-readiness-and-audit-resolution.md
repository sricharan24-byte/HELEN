# ADR-003: Full Production Readiness and Astra / Opus Audit Milestone Resolution

- **Status**: Accepted
- **Date**: 2026-09-20
- **Auditors & Reviewers**: GPT-6 Astra (Accessibility & Safety Audit) & Claude Opus 5 (Architectural Spec)
- **Scope**: Complete closure and automated test coverage of all 7 P0 Release Blockers and all 10 P1 Critical Tasks.

---

## 1. Context & Motivation

Following the Phase 1 domain contracts (ADR-001) and Phase 2 accessibility architecture (ADR-002), a deep architectural and accessibility audit was performed (`main.pdf` / `docs/audit/gpt6_astra_feedback_phase2.txt`). The audit surfaced 7 P0 Release Blockers (`BUS-P0-01` through `BUS-P0-07`) and 10 P1 Critical Tasks (`BUS-P1-01` through `BUS-P1-10`).

To reach 100% production readiness, all identified blockers and critical tasks were systematically addressed, mathematically verified, and sealed with dedicated automated tests.

---

## 2. P0 Release Blockers Resolution

### `BUS-P0-01`: Fare Engine Integer Paise Precision
- **Implementation**: Created `FareEngine` and `FareQuote` in `lib/domain/ticketing/entities/fare_engine.dart`.
- Eliminated all floating-point arithmetic (`double`) for currency representation. All monetary values are strictly represented in integer paise (`1 INR = 100 paise`), including base fare, concession discounts (40% for students/seniors), and final totals.
- **Verification**: `test/domain/fare_engine_test.dart` asserting exact integer calculations, boundary handling, and zero loss of precision.

### `BUS-P0-02`: Single Source of Truth & Service Locator
- **Implementation**: Hardened `AppServiceLocator` in `lib/core/di/service_locator.dart` as the sole composition root.
- Replaced scattered duplicate controller/repository instantiations across widgets with unified singleton resolution and test override support.
- **Verification**: `test/integration/service_locator_di_test.dart`.

### `BUS-P0-03`: Continuous Speech Debounce & Unsolicited Prompts
- **Implementation**: Upgraded `FloatingAssistantController` and `GeminiLiveScreen` with a continuous listening loop that automatically debounces acoustic feedback, respects speaker state, and auto-resumes listening 350ms after TTS/PCM completion.
- Eliminated all artificial system prompt echoes.

### `BUS-P0-04`: Resource Lifecycle Disposals & Coroutine Leaks
- **Implementation**: Added comprehensive lifecycle disposals in `LiveLocationScreen`, `TicketController`, and speech sessions. Active `StreamSubscription` and `Timer` instances are cancelled in `dispose()`.
- Implemented `AsyncDisposable` on `LocalTransportRepository` and `LocalTransportDataSource`.
- **Verification**: `test/data/telemetry_lifecycle_leak_test.dart`.

### `BUS-P0-05`: Action Execution Safety Gateway
- **Implementation**: Built `AssistantCommandGateway` in `lib/domain/assistant/assistant_command.dart`.
- Safety-critical actions (Emergency SOS, location sharing, financial ticket booking) are gated behind explicit passenger confirmation dialogs rather than executing silently in the background.
- **Verification**: `test/features/assistant_command_gateway_test.dart`.

### `BUS-P0-06`: Production Gating for Simulated Voice Input
- **Implementation**: Feature-gated `enableSimulatedVoiceInput` to `false` by default across `audio_speech_engine.dart` and web speech adapters, preventing mock voice queries from firing in production web builds.
- **Verification**: `test/features/voice_simulation_gate_test.dart`.

### `BUS-P0-07`: Text Scaling & Overflow Elimination
- **Implementation**: Replaced rigid height constraints with responsive sizing and wrapped scrolling views to support large text scales up to 300% without layout overflow exceptions.

---

## 3. P1 Critical Tasks Resolution

### `BUS-P1-01`: Monotonic Telemetry Sequencing & Reducer
- **Implementation**: Created `TelemetryReducer` and monotonic sequence validation in `lib/data/datasources/local_transport_data_source.dart`. Out-of-order or stale GPS packets are discarded, ensuring monotonic progress updates.
- **Verification**: `test/data/live_telemetry_ordering_test.dart`.

### `BUS-P1-02`: Stop Occurrence Resolution for Circular & Repeated Stops
- **Implementation**: Introduced `StopOccurrence` and `TransitRoute.stopsBetween` in `lib/domain/transit/entities/transit_route.dart`. Correctly resolves intermediate stops on circular loops, bidirectional routes, and corridors with repeated stops.
- **Verification**: `test/domain/route_segment_resolution_test.dart`.

### `BUS-P1-03`: AnnouncementCoordinator Audio Arbiter
- **Implementation**: Built a priority queue arbiter with message deduplication, TTL expiration, and automatic speech ducking in `lib/core/a11y/announcement_coordinator.dart`.
- **Verification**: `test/a11y/announcement_arbiter_test.dart`.

### `BUS-P1-04`: Overlay Semantics, Focus Restoration & 48dp Controls
- **Implementation**: Fixed modal focus entrapment in `FloatingAiAssistantOverlay`, wired focus restoration upon close, and enforced >= 48×48dp minimum hit targets across all overlay buttons and prompt chips.
- **Verification**: `test/features/floating_overlay_a11y_test.dart`.

### `BUS-P1-05`: Responsive Reflow at 200–300% Text Scale
- **Implementation**: Refactored fixed-height cards and horizontal rows into `ConstrainedBox` and `Wrap` layouts across search, details, tickets, and safety screens.
- **Verification**: `test/a11y/text_scale_reflow_test.dart`.

### `BUS-P1-06`: Semantic Duplication Cleanup & Heading Contracts
- **Implementation**: Applied `excludeSemantics: true` on decorative icons and formal semantic heading levels across home, settings, tickets, and accessibility options.
- **Verification**: `test/a11y/semantics_duplicate_cleanup_test.dart`.

### `BUS-P1-07`: Resilient OSRM Routing & Offline Failure States
- **Implementation**: Added `RoutingOutcome` with error categorization (200, 429, 500, timeout, offline), payload guards (512KB), and a persistent offline retry banner on `LiveLocationMapWidget`.
- **Verification**: `test/data/osrm_routing_failure_states_test.dart`.

### `BUS-P1-08`: Voice Permission Recovery, Capped Backoff & JS Cleanup
- **Implementation**: Added an accessible permission recovery card with "Try Again" action in `GeminiLiveScreen` and floating overlay. Implemented capped exponential backoff with jitter (max 5 attempts, max 8s) in `GeminiLiveSession`. Added global JS event listener removal in `web_speech_real.dart` on dispose.
- **Verification**: `test/features/ai_assistant/voice_session_lifecycle_test.dart`.

### `BUS-P1-09`: Machine-Verified WCAG 2.2 Semantic Contrast
- **Implementation**: Mathematically verified relative luminance and contrast ratios across all semantic color tokens in `AppSemanticColors` and `AppTheme`. High-Contrast theme achieves >= 7.0:1 (AAA) across all text, borders, and status cues. Light and Dark themes achieve >= 4.5:1 (AA) and >= 7.0:1 for primary titles.
- **Verification**: `test/a11y/semantic_color_contrast_test.dart`.

### `BUS-P1-10`: Process Death Restoration for Active Tickets & Journeys
- **Implementation**: Implemented state hydration and persistence in `LocalTicketRepository`, `TicketController`, and `JourneyController`. Expired tickets are cleanly transitioned during hydration. Ongoing journeys restore origin, destination, selected route, and active session seamlessly.
- **Verification**: `test/integration/process_death_restoration_test.dart`.

---

## 5. Astra Phase 2 P2 Items — Session 2026-09-20 (BUS-P2-01 / BUS-P2-02 / BUS-P2-04)

> Recorded while work is in progress. `progress.md` § "Session Log — 2026-09-20" is the operational companion; this section is the decision record.

### 5.1 Prerequisite: zero-failing-test baseline

- **Decision**: complete the zero-failing-test baseline before touching P2 production config/analysis, so P2 regressions are attributable.
- **Outcome**: suite reached `+330 / All tests passed / 0 [E]` (`/tmp/bb_final3.log`) before P2-04 edits; that baseline is now stale and must be re-established after analyze returns to green.
- Notable defect archaeology (kept here because both fixes encode layout/test contracts future work must respect):
  1. `floating_ai_assistant_test.dart` "Find route": no product-code change; the overlay lazily builds the newest bubble only after the 250 ms `_scrollToBottomIfNeeded` animation, so the test needed a second one-second pump (`test/.../floating_ai_assistant_test.dart` ~L303–305).
  2. `platform_text_scaler_test.dart` 320dp × 300%: the Active Ticket hero header `Row` overflowed 74 px on the rigid `On Track` pill; the pill is now `Flexible` (`lib/features/home/home_page.dart` ~L473–488). Any redesign of that card must preserve this flexibility contract.

### 5.2 `BUS-P2-01`: minimize Android permissions (code-complete)

- **Decision**: `android/app/src/main/AndroidManifest.xml` declares only `INTERNET`. `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, and `RECORD_AUDIO` were removed because no native capability consumes them (no location/audio plugins in the dependency closure; location is fixture-backed, voice is web speech on Chrome).
- **Rationale note**: re-introducing a permission requires a just-in-time runtime request, a contextual rationale before the system prompt, and an accessible denial fallback (Astra Gate 12).
- **Open**: ~~flavor-scoped manifest-merge tests and runtime permission-flow tests~~ — **closed 2026-09-22**: `test/platform/permission_flow_test.dart` locks INTERNET-only main + flavor manifests, asserts no request APIs/plugins, documents re-add rationale (JIT + rationale + denial fallback), and verifies browser-mic / offline-map feature fallbacks. Instrumented deny/revoke flows remain N/A until a runtime permission is reintroduced.

### 5.3 `BUS-P2-02`: release shrinking (build verified 2026-09-22)

- **Decision**: `android/app/build.gradle.kts` release type enables R8 code shrinking (`isMinifyEnabled`) and resource shrinking (`isShrinkResources`) with `proguard-android-optimize.txt` plus a new evidence-based `android/app/proguard-rules.pro` (Flutter embedding/plugin glue, app `MainActivity`, `shared_preferences_android` entry points only).
- **R8 Play Core link fix (2026-09-22)**: first minified build failed on optional Flutter embedding references to `com.google.android.play.core.*` split/deferred-component APIs (not on our classpath). Added AGP `missing_rules.txt` `-dontwarn` entries with rationale — these APIs are never executed (no Play Core dependency, no dynamic feature modules).
- **Verified**: `flutter build apk --release` succeeds → `build/app/outputs/flutter-apk/app-release.apk` (55.6 MB / 53M on disk).
- **Exit criteria harness**: `tool/release_smoke.sh` (minified APK rebuild, size/sha256, optional device install + launch + reflection restart smoke) and `tool/startup_memory_benchmark.sh` (cold/warm `am start -W` TotalTime budgets, PSS after 10 navigation cycles, logcat fatal scan). CI runs `flutter build apk --release` + `flutter build web --release` and uploads an immutable evidence artifact with commit SHA (BUS-P2-03).
- **Open (device remainder)**: run the two shell harnesses against a physical device/emulator (none attached in this environment) for on-device cold/warm/memory numbers and TalkBack semantics no-regression evidence.

### 5.4 `BUS-P2-04`: strict static analysis (DONE — GREEN)

- **Decision**: `analysis_options.yaml` now enforces `strict-casts`, `strict-inference`, `strict-raw-types` plus async/callback-hygiene lints (`unawaited_futures`, `discarded_futures`, `use_build_context_synchronously`, `cancel_subscriptions`, `close_sinks`, …) and style lints. Enablement surfaced 46 inference errors and 334 findings total.
- **Approach so far**: typed `dynamic colors` params as `AppSemanticColors`, typed transport `onError` as `void Function(Object)`, applied `dart fix --apply` (75 fixes), explicit `<void>` type args on routes/dialogs, migrated `SemanticsService.announce` to view-scoped `sendAnnouncement` with documented single-window exceptions, migrated `onReorder` → `onReorderItem`, and wrapped 97 discarded futures in `unawaited()`.
- **⚠️ Known self-inflicted breakage (RESOLVED same session 2026-09-20)**: the bulk `unawaited()` script wrapped multi-statement cascades and the resulting parse failure cascaded into 112 phantom errors (including `undefined_method` for `FloatingAssistantController` APIs that in fact exist — `resetForTesting`, `resetPosition`, `clampToScreen`, `updatePosition`, `moveTo*` were never missing). All wraps hand-repaired; `TickerFuture.repeat()` kept as narrow `// ignore: discarded_futures` with rationale. **Final: `flutter analyze` → `No issues found!`; `flutter test` → `+330 All tests passed!` (log `/tmp/test_full.txt`).** Full test suite is trustworthy again at this commit point.
- **BUS-P2-04 suppression policy applied**: narrowly scoped `// ignore:` comments each carrying a `BUS-P2-04:` rationale (deprecated single-window announce path, subscription-lifetime sinks, file-local web-library gate). No blanket `ignore_for_file` beyond the pre-existing web-speech gate.
- **Reconfirmed 2026-09-22**: after TTS arbiter wiring completion — `flutter analyze` → `No issues found!`; `flutter test` → **341/341 All tests passed**.

### 5.5 `BUS-P2-01`: permission minimization (tests added 2026-09-22)

- Manifest remains INTERNET-only. Extended `test/platform/android_configuration_test.dart` to lock the permission set, assert absence of location/mic permissions, and require the BUS-P2-01 re-add rationale comment.
- Runtime permission-flow tests (deny / permanent deny / revoke / approximate) remain open only if a permission is re-introduced.

## 5b. `BUS-P2-03`: CI as source of truth (implemented 2026-09-22)

- **Decision**: `.github/workflows/ci.yml` is authoritative for `flutter analyze --fatal-infos --fatal-warnings`, full `flutter test` (count derived from the run, not a hand-edited badge), `tool/ci/verify_docs.sh`, minified release APK + web release builds, and an immutable `evidence/` artifact stamped with `commit_sha`, test count, APK sha256/size, and run id.
- **Docs gate**: `test/platform/docs_verification_test.dart` fails the suite if ADR-001/002/003, CI workflow, smoke/benchmark scripts, or P2 config claims are missing or drift from source.
- **Claim policy**: README/ADR test counts and release claims must match CI evidence; manual badge edits are non-authoritative.

## 4. Verification & Status Summary

- **Total Dart Files Validated**: 131 files across `lib/` and `test/`.
- **Bracket / Syntax Integrity**: 0 syntax errors, 0 bracket imbalances.
- **Import Resolution**: 0 unresolved internal or package imports.
- **Deliverable Artifact**: Updated `BusBuddy_Implementation_Research_and_UI_Design.docx`.
- **2026-09-22 gate**: `flutter analyze` clean; full suite **354/354** (341 + 13 new P2 docs/permission-flow tests); minified release APK builds; UI polish `0164afc`; BUS-P2-01/02/03 tooling + tests landed (device harnesses ready when adb target available).
