# ADR-004: Android Native Voice I/O and Spoken-Question Audio-In

- **Status**: Accepted (Android runtime verified on emulator 2026-09-30; audio-in round trip still pending a physical device + API key)
- **Date**: 2026-09-26
- **Reviewers**: Accessibility & safety review (Astra P0/P1 constraints) + architectural spec
- **Scope**: Native Android microphone capture, device TTS/chimes, and packing passenger speech into the Gemini Live `realtimeInput` protocol so Android users can *ask* questions by voice.

---

## 1. Context & Motivation

ADR-003 closed the production-readiness audit on the web target, where `AudioSpeechEngine` delegates both directions to the browser: `SpeechRecognition` for spoken questions and `SpeechSynthesis` for replies. Android had neither:

1. **No speech output at all.** The web speech path compiles only on web (`dart:html`/`dart:js` conditional imports), so on Android the assistant had no voice.
2. **No speech input.** No on-device speech-to-text dependency exists (no `speech_to_text`/cloud STT plugin), and the Live API audio-in protocol was unused — `GeminiLiveSession` only ever sent `clientContent` text turns. `AudioSpeechEngine.startListening` reported the honest fallback message (BUS-P0-06), but "type your question" is not hands-free transit assistance for a blind passenger on a moving bus.
3. **No echo path.** Any microphone the app opened had to keep the platform echo canceller engaged, or the assistant's own voice becomes the next question.

A native bridge (`BusBuddyVoiceChannel.kt`) was added on the `busbuddy/voice` method channel plus the `busbuddy/voice/mic` event channel: 16 kHz mono `AudioRecord` capture, `TextToSpeech` replies, `ToneGenerator` chimes, and 24 kHz `AudioTrack` playback capacity.

---

## 2. Decisions

### 2.1 One audio session, and it belongs to `GeminiLiveScreen`

`GeminiLiveScreen` remains the app's sole voice surface and sole audio owner (Chunk 42/43). No second assistant surface, floating bubble or arbiter is reintroduced.

### 2.2 Microphone audio is streamed to the Live session, not transcribed locally

`GeminiLiveSession.sendRealtimeAudio(base64Pcm)` emits:

```json
{"realtimeInput": {"mediaChunks": [{"mimeType": "audio/pcm; rate=16000", "data": "<base64 PCM16>"}]}}
```

- Gated on `isReady` (socket open **and** `setupComplete` received); a frame sent earlier would be rejected or dropped.
- Server-side voice-activity detection ends the question, so **no `audioEnd`/`turnComplete` control frame is sent** — an unrecognised control frame risks tearing down the whole session. The trade-off is accepted: the model answers as soon as the passenger stops talking.
- The Live API wire format matches capture exactly (16 kHz mono PCM16), so no resampling is performed anywhere.

### 2.3 The spoken turn is an explicit, testable object

`AndroidVoiceTurn` (`lib/features/ai_assistant/android_voice_turn.dart`) owns one spoken turn:

| Behaviour | Rationale |
| --- | --- |
| `start()` opens capture, subscribes to PCM + error streams, forwards chunks | One place decides what reaches the model |
| `pause()` / `resume()` | The assistant's reply must never be re-heard as a question; the stream stays open so the passenger can still interrupt (`interrupted` resumes feeding) |
| Every failure reports **exactly once** via `onTurnLost(reason, microphoneUnavailable)`, then releases the microphone | No silent dead-end and no capture left open; a fresh instance is built per turn |
| `microphoneUnavailable: true` only for permission/device failures, `false` for a socket that cannot take audio | The UI says "fix your microphone" only when the passenger can actually fix it |

It is a plain Dart class with injected streams so the whole state machine is unit-testable without a device.

### 2.4 Honest failure policy (BUS-P0-06 / BUS-P1-08 preserved)

- Capture **never** opens before the Live handshake: the screen waits up to 4 s (`_awaitLiveReady`) and otherwise reports that the microphone stayed off, keeping the working text box.
- No transcript is ever fabricated. `inputTranscription` text, when the service reports it, is **display-only** (`🗣️ "…"`) and is never re-submitted as a text turn — the audio it transcribes already reached the model.
- `AudioRecord` failures (no usable input, access revoked) surface through `NativeAudioChannel.microphoneErrors` → `AudioSpeechEngine.liveMicrophoneErrors` → turn loss, so a "Listening…" promise is never left unfulfillable.
- `AudioSpeechEngine.startListening` on Android remains an honest fallback path (just-in-time `RECORD_AUDIO` prompt, rationale-aware, "never ask again" detected) for callers that cannot stream audio.

### 2.5 Replies stay on the single voice

`responseModalities: ['AUDIO']` is still requested, but `AudioSpeechEngine.speak` (web SpeechSynthesis / Android `TextToSpeech`) remains the **only** speech producer, and the reply text arrives through the transcript. The bridge's `AudioTrack` path (`startPlayback`/`writePlayback`/`stopPlayback`) and `GeminiLiveSession.onAudioPcmChunk` are therefore intentionally unwired: feeding model PCM *and* TTS would produce two voices. Both are built, documented and tested, ready for the day streamed model audio replaces TTS.

### 2.6 Echo control

- Capture uses `MediaRecorder.AudioSource.VOICE_COMMUNICATION`; playback and chimes use `USAGE_ASSISTANCE_ACCESSIBILITY` with speech content type, so the hardware echo canceller stays engaged while the microphone is open.
- Defence in depth: frames are withheld while the assistant speaks (`pause`), so AEC is an optimisation, not the only barrier to self-answering.


---

## 3. Verification

- `flutter analyze` — no issues.
- `flutter test` — 367 tests, 100% green, including:
  - `test/features/ai_assistant/android_voice_turn_test.dart` (8 tests): base64 forwarding, one-shot failure reporting with the microphone-vs-socket distinction, pause/resume gating, empty chunks never sent, idempotent `stop()`, and mic-open-once for concurrent `start()`.
  - `test/features/ai_assistant/native_audio_channel_test.dart`: bridge degradation on non-Android/test targets, permission outcomes, error surfacing.
  - `test/features/ai_assistant/voice_session_lifecycle_test.dart`: the screen keeps its listening/speaking lifecycle unchanged on web, plus the microphone-state-honesty regressions in §3.1.

### 3.1 Android runtime verification (2026-09-30)

Run on an API 34 x86_64 emulator (`system-images;android-34;google_apis;x86_64`, KVM-accelerated), debug APK, `RECORD_AUDIO` revoked to force the denial path.

**Verified on a real Android runtime:**

- `flutter build apk --debug` succeeds — the native `BusBuddyVoiceChannel` Kotlin compiles and packages.
- Install + launch + navigation to the voice surface work; no crash and no ANR in the app.
- The installed permission set is exactly the audited contract: `INTERNET`, `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS` (plus Flutter's injected `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`).
- With no Live connection the screen **keeps the microphone off and says so**, names the real reason, and leaves the text box usable — verified before and after the §3.2 fix.
- The app's own TTS path reaches Android's `TextToSpeech` (logcat shows the GSA TTS engine being contacted and then failing on the AVD).

**Not verified — and why:**

| Check | Blocked by |
| --- | --- |
| Spoken question → `realtimeInput` → reply | No valid Gemini API key in this environment; `_awaitLiveReady` correctly refuses to open the mic without one, so the audio-in path is unreachable here |
| Permission dialog wording | Reached only after Live readiness, so it is blocked by the same missing key |
| `AudioRecord` PCM on `busbuddy/voice/mic` | Same |
| Audible TTS / echo behaviour | The AVD's TTS engine is broken (`errorCode 65561/401`) and the host has no audio backend (`Could not init 'pa' audio driver`); hardware AEC does not exist on an AVD |
| TalkBack announcements | TalkBack is not installed on the AVD, and its spoken output is not observable from `adb` |

An emulator is not a substitute for hardware: it validates the platform wiring, the permission contract and the honest-failure paths, but **the audio-in round trip, echo cancellation and TalkBack still require a physical device with a valid API key.** Do not report this ADR as device-verified until then.

### 3.2 Bug found by the device run: the screen lied about listening

`_isListening` defaulted to `true`. Two consequences, both invisible to unit tests:

1. The UI showed the "Continuous Mic Active" chip and "Listening…" on open with **no microphone open** and no connection — a direct BUS-P1-08 violation for a screen reader user.
2. Worse, `_startMicrophoneListening` early-returns on its own `if (_isListening && !isRestart) return;` guard, so the **first open never started capture at all**, on any platform. Web was silently mute too.

The flag now starts `false` and is set only once capture is genuinely open; the Android path shows "Preparing the microphone…" across the permission + handshake window and flips the flag inside `_startAndroidVoiceTurn` only after `turn.isActive`. The chime that marks the passenger's turn moved there too, so it marks a real start rather than a request. Two regression tests in `voice_session_lifecycle_test.dart` pin both halves, and both were confirmed to fail against the old default.

The failure message was also corrected: it claimed "BusBuddy is still connecting" even when no API key was configured, which is the common first-run case. It now distinguishes the two and points at the Connect banner.

---

## 4. Consequences

**Positive**: Android passengers can ask questions hands-free; one microphone stream spans turns; failure modes are explicit and actionable; the single-voice contract and the BUS-P0-06 no-fabrication rule both survive.

**Negative / accepted risks**: spoken turns are half-duplex by design (frames pause during replies); echo is mitigated by AEC plus pausing rather than by a strict duplex protocol; the Live API audio-in path is exercised only by unit tests until a device run confirms it end-to-end.

**Follow-ups**: device verification; optionally request `inputAudioTranscription` explicitly once confirmed against the live service; and — only with a redesigned single-voice contract — switch replies to streamed model audio.

