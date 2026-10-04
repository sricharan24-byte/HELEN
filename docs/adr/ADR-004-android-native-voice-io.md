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

`responseModalities: ['AUDIO']` is requested, and the model's own audio **is** the reply. `ModelVoicePlayer` (`lib/features/ai_assistant/model_voice_player.dart`) is the only model-audio producer and `AudioSpeechEngine` is the only TTS producer, and exactly one of them speaks per turn: when Gemini streamed audio, `hasModelAudioThisTurn` makes the screen skip TTS entirely; TTS speaks only the turns that carried no audio (plain text turn, REST fallback, socket without audio). The turn ends on the playback drain — `onPlaybackDrained` from the Android `AudioTrack`, or the Web Audio queue drain in the browser — because with no TTS utterance running the TTS ended-callback would never fire.

The single-speaker rule moved with the voice rather than being duplicated, so this is still exactly one voice: the natural one. What stays forbidden is speaking a reply through both paths in one turn, and adding a second audio owner (`TtsFallbackArbiter`-style) — deleted in Chunk 43, must not return.

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
| Spoken question → `realtimeInput` → reply | **Superseded by §3.3** — with a valid key the handshake completes and PCM frames are confirmed on the wire; only the *final turn* is unreachable, because the AVD microphone produces silence (see §3.3) so server-side VAD never fires |
| Audible TTS / echo behaviour | The AVD's TTS engine is broken (`errorCode 65561/401`) and the host has no audio backend (`Could not init 'pa' audio driver`); hardware AEC does not exist on an AVD |
| TalkBack announcements | **Corrected 2026-10-04 — see §3.4.** The earlier claim "TalkBack is not installed on the AVD" was **wrong**: `com.google.android.marvin.talkback` ships in the `google_apis` API 34 system image and runs once enabled. What is still unobservable is the *sound*: the emulator cannot open an audio output on this host, so announcements are synthesised (`GoogleTTSServiceImpl: Synthesis request for locale eng-USA`) but never audible. The accessible **node tree** TalkBack reads *is* observable via `adb shell uiautomator dump`. |

An emulator is not a substitute for hardware: it validates the platform wiring, the permission contract and the honest-failure paths, but **echo cancellation, audible replies and TalkBack still require a physical device.** Do not report this ADR as device-verified until then.

### 3.3 Bug found by the device run: the native transport dropped every server frame (P0)

The Chunk 44 audio-in feature **could never have worked on Android or desktop**, and 365 passing tests could not see it.

`IoGeminiLiveTransport` delivered frames like this:

```dart
socket.listen((data) {
  if (data is String) { onMessage(data); }   // everything else silently dropped
});
```

The Gemini Live service frames inconsistently by client: the browser
(`WebGeminiLiveTransport`) receives JSON control frames as **text**, but the native `dart:io`
socket receives the *same* frames as **binary** (`_Uint8ArrayView`). Confirmed on the emulator —
`RX type=_Uint8ArrayView` — and reproduced Dart-to-Dart with a loopback server, so it is a
client-side contract error, not an emulator artefact.

Consequences, all silent:

1. `setupComplete` was never parsed, so `_isSetupDone` stayed `false` **forever**.
2. `GeminiLiveSession.isReady` was therefore permanently `false`.
3. `sendRealtimeAudio` rejected **every** microphone frame — the audio-in path was dead.
4. Every turn silently degraded to the REST fallback (`Live session not ready
   (_isConnected=true, _isSetupDone=false); falling back to REST`), while the UI still showed
   "Live Connected" and a green GEMINI LIVE badge.

A 7-minute session log showed exactly this: connected, setup sent once, zero frames ever received.

**Fix**: `_decodeFrame` normalises `String` and `List<int>` (UTF-8) to JSON text, and undecodable or
unsupported frames now log instead of vanishing. `send` also logs a dropped frame rather than
discarding it silently.

**Regression test**: `test/features/ai_assistant/gemini_live_transport_frames_test.dart` stands up a
real loopback WebSocket server that replies with a **binary** `setupComplete`, exactly as the
service frames it, and asserts the transport surfaces it. Verified to fail against the old
String-only code (`Actual: []`) and pass after.

**Verified on the emulator after the fix**: `setupComplete received: session ready`, the banner
reads "Gemini Live Active · Live Ready", the microphone opens, and 691 `realtimeInput.mediaChunks`
PCM frames were observed on the wire over ~3 minutes.

**Still not proven**: that a *spoken* question produces a spoken reply. The AVD microphone yields
silence (no host audio backend), so server-side VAD never ends a turn. That last link needs real
microphone audio — emulator or hardware.


### 3.2 Bug found by the device run: the screen lied about listening

`_isListening` defaulted to `true`. Two consequences, both invisible to unit tests:

1. The UI showed the "Continuous Mic Active" chip and "Listening…" on open with **no microphone open** and no connection — a direct BUS-P1-08 violation for a screen reader user.
2. Worse, `_startMicrophoneListening` early-returns on its own `if (_isListening && !isRestart) return;` guard, so the **first open never started capture at all**, on any platform. Web was silently mute too.

The flag now starts `false` and is set only once capture is genuinely open; the Android path shows "Preparing the microphone…" across the permission + handshake window and flips the flag inside `_startAndroidVoiceTurn` only after `turn.isActive`. The chime that marks the passenger's turn moved there too, so it marks a real start rather than a request. Two regression tests in `voice_session_lifecycle_test.dart` pin both halves, and both were confirmed to fail against the old default.

The failure message was also corrected: it claimed "BusBuddy is still connecting" even when no API key was configured, which is the common first-run case. It now distinguishes the two and points at the Connect banner.

### 3.4 Web model-audio playback (2026-10-04)

Until this, Chrome threw every model-audio chunk away (`ModelVoicePlayer.isSupported` was Android-only) and spoke replies through `speechSynthesis`. On a host with no system TTS engine — a bare Linux Chrome install, for instance — that engine is silent, so the browser build could show a flawless text transcript with no voice at all. That is the report this section answers.

The web half now schedules the same 24 kHz mono PCM16 through the Web Audio context the listening chime already uses, so the existing gesture unlock primes it and there is no second audio stack to keep alive: `__bb_play_model_audio` / `__bb_stop_model_audio` in `web_speech_real.dart`, start times chained off a queue cursor for gapless playback, and a queue-drain timer as the end-of-turn signal. A chunk that will not schedule (no AudioContext, undecodable payload) returns false, which leaves `hasModelAudioThisTurn` clear and hands that turn back to TTS rather than dropping the reply.

**Proven:** `flutter analyze` clean, `flutter test` 389 green, `flutter build web --profile` compiles under dart2js.

### 3.5 Bug found by the browser run: the page bridge was never installed

The first Chrome run of §3.4 produced chunks but no sound, and one error per chunk:

```
[WebModelAudio] playModelAudio error: NoSuchMethodError: tried to call a
non-function, such as null: 'js.context.__bb_play_model_audio'
```

The audio logic was never reached: the JS bridge was not present in the page. `__bb_speak_text` was equally absent, which is why there had been no voice at all — the web build had never actually been able to speak, it had only ever appeared to.

Two defects, both invisible to `flutter analyze`, `flutter test` and `flutter build web`, none of which execute the page:

1. **Silent failure at the call site.** Installation was tracked by two pieces of state — a Dart flag and a version stamp the page writes for itself — and nothing verified the eval had actually installed anything. A bridge that was never installed produced a bare `NoSuchMethodError` at the first `playModelAudio` call and nothing else.
2. **A failed install could still look successful.** The version stamp is a separate eval written *after* the big one, so it survives an eval that threw or was a no-op. The next call then saw the flag set and a matching version, skipped the install, and the bridge stayed missing for the life of the page — exactly the state observed.

The fix keeps the eval but stops trusting it:

- Calls resolve the entry point first and invoke the **function reference** via `Function.prototype.call`, so a missing bridge is an observable `null` rather than a throw at the call site.
- After every install the required entry points are verified; anything missing resets the flag so the next call retries rather than trusting a stamp written by a failed eval. A throwing install resets it too.
- A missing entry point is reported once, by name, naming the fix ("hot restart, or reload the page") instead of repeating a `NoSuchMethodError` per chunk.

**Proven:** `flutter analyze` clean, `flutter test` 389 green, `flutter build web --profile` compiles under dart2js. The bridge JS is additionally extracted from the Dart source and executed in Node against stubbed browser globals: all six entry points install, `__bb_play_model_audio` returns true for a real 24 kHz PCM16 base64 chunk, the queue cursor advances so consecutive chunks schedule back to back, `__bb_stop_model_audio` clears the queue, and the drain callback fires once playback completes.

**Still not proven:** that it is audible in a real browser, and that it sounds natural. The diagnostic split is now explicit — `[ModelVoice] turn N: playing Gemini's own voice` means chunks are arriving and being scheduled, `[WebSpeech] page bridge has no …` means the page JS is missing (hot restart), and `[BusBuddy ModelAudio]` warnings mean the AudioContext itself failed.

---

## 4. Consequences

**Positive**: Android passengers can ask questions hands-free; one microphone stream spans turns; failure modes are explicit and actionable; the single-voice contract and the BUS-P0-06 no-fabrication rule both survive.

**Negative / accepted risks**: spoken turns are half-duplex by design (frames pause during replies); echo is mitigated by AEC plus pausing rather than by a strict duplex protocol; the Live API audio-in path is exercised only by unit tests until a device run confirms it end-to-end.

**Follow-ups**: confirm the natural voice with a live session on web and on an Android device; optionally request `inputAudioTranscription` explicitly once confirmed against the live service.

