# ADR-004: Android Native Voice I/O and Spoken-Question Audio-In

- **Status**: Accepted (device verification pending)
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
- `flutter test` — 365 tests, 100% green, including:
  - `test/features/ai_assistant/android_voice_turn_test.dart` (8 tests): base64 forwarding, one-shot failure reporting with the microphone-vs-socket distinction, pause/resume gating, empty chunks never sent, idempotent `stop()`, and mic-open-once for concurrent `start()`.
  - `test/features/ai_assistant/native_audio_channel_test.dart`: bridge degradation on non-Android/test targets, permission outcomes, error surfacing.
  - `test/features/ai_assistant/voice_session_lifecycle_test.dart`: the screen keeps its listening/speaking lifecycle unchanged on web.
- **Not yet verified on hardware** (no Android SDK/emulator in the build environment). Outstanding device checks: permission dialog wording, no echo/feedback loop on speakerphone, `adb logcat -s BusBuddyVoiceChannel:V` channel activity, and TalkBack announcements for the listening and permission-blocked states.

---

## 4. Consequences

**Positive**: Android passengers can ask questions hands-free; one microphone stream spans turns; failure modes are explicit and actionable; the single-voice contract and the BUS-P0-06 no-fabrication rule both survive.

**Negative / accepted risks**: spoken turns are half-duplex by design (frames pause during replies); echo is mitigated by AEC plus pausing rather than by a strict duplex protocol; the Live API audio-in path is exercised only by unit tests until a device run confirms it end-to-end.

**Follow-ups**: device verification; optionally request `inputAudioTranscription` explicitly once confirmed against the live service; and — only with a redesigned single-voice contract — switch replies to streamed model audio.

