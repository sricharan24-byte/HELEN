// ignore_for_file: deprecated_member_use, uri_does_not_exist, avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'package:flutter/foundation.dart';

import '../../core/settings/app_settings_controller.dart';

bool enableSimulatedVoiceInput = false;
bool _jsBridgeInitialized = false;

/// Bump when the JS bridge below changes. Hot reload preserves Dart statics,
/// so without a version check the page keeps running stale JS after an edit.
/// The eval is re-run whenever the page's bridge version mismatches.
///
/// v5: single-speaker rebuild. The Gemini native PCM playback path was
/// removed entirely; [speakText] is the ONLY function in the entire app that
/// can produce speech. One speaker means a double voice is impossible by
/// construction.
///
/// v6: the web half of the Chunk 49 contract. Gemini's own 24 kHz PCM16 is now
/// played here through the Web Audio context this bridge already owns, so the
/// natural model voice finally reaches the browser. The single-speaker rule is
/// unchanged and simply moves with the voice: when model chunks play for a
/// turn, [speakText] is not called for that turn, and the TTS remains the
/// fallback for turns that carry no audio at all.
/// v7: Chrome voice fixes. Two real silence bugs:
///
/// 1. `__bb_play_model_audio` used to schedule chunks even while the
///    AudioContext was suspended (Chrome autoplay policy) and still return
///    true, so the caller believed the model voice had played and skipped TTS
///    for the whole turn — total silence. It now returns false while the
///    context is not running, which routes the turn to the TTS fallback, and
///    it no longer queues chunks that would all pile up at t≈0 and overlap
///    when the context eventually resumes.
/// 2. `__bb_speak_text` called `speechSynthesis.cancel()` and `speak()`
///    synchronously in the same tick — a known Chrome bug swallows the new
///    utterance (it never plays and never fires onend/onerror). The speak is
///    now deferred a tick after a cancel.
///
/// v8: restore the pre-v6 web PCM path that actually produced sound. v6
/// rewrote the decoder and v7 then gated it, and together they made every
/// Chrome reply silent:
///
/// 1. **base64 was fed to `atob` raw.** The Live API commonly emits unpadded
///    and/or URL-safe base64, which `atob` throws on. The pre-v6 code stripped
///    whitespace, mapped `-`/`_` back to `+`/`/`, and padded to a multiple of
///    4; that sanitization was deleted and is restored.
/// 2. **the odd-byte carryover was deleted.** A chunk boundary can split one
///    PCM16 sample; decoding a half sample shifts every later sample by a byte
///    and turns the reply into noise. `__bb_model_audio_tail` carries it.
/// 3. **v7's "return false while suspended" is reverted to resume-then-schedule.**
///    Scheduling on a suspended context is valid — the buffers play once
///    `resume()` completes — and it is how the build that *was* audible
///    worked. Because the audio unlock runs in `initState`, i.e. after the tap
///    that opened the screen, the context is suspended on nearly every turn,
///    so the bail-out meant "never plays". It routed to a TTS fallback that had
///    no text to speak (see the handshake in `gemini_live_session.dart`), which
///    is why the turn was silent rather than merely robotic.
/// v9: setup handshake schema alignment and robust AudioContext priming.
const int kJsBridgeVersion = 9;

int _pageBridgeVersion() {
  try {
    // Legacy `dart:js` lookup, NOT `js_util.getProperty`: `js.context` is a
    // `JsObject` wrapper around the real `window`, and js_util reads the
    // property off the Dart-side wrapper — always `undefined`, so the version
    // check silently returned -1 forever and forced a full re-eval on every
    // call. `JsObject.operator[]` goes through the same native path as
    // `js.context.callMethod`, which is the interop that demonstrably works.
    final v = js.context['__bb_bridge_version'];
    if (v is num) return v.toInt();
  } catch (_) {}
  return -1;
}

/// Resolves one bridge function by name.
///
/// Looked up through the legacy `dart:js` [js.context] `JsObject` API — the
/// same interop path as `js.context.callMethod`, which is what installs the
/// bridge (`eval`) in the first place. The earlier version called
/// `js_util.getProperty(js.context, name)`, which silently returns `null` for
/// *every* name: `js.context` is a `JsObject` wrapper, not a raw JS object, so
/// js_util reads a property off the Dart-side wrapper and sees `undefined`.
/// That made this function report a perfectly installed bridge as missing —
/// `speakText` never invoked `__bb_speak_text`, `playModelAudio` always
/// returned `false`, and every reply fell through to a TTS path that could
/// never run: total silence on every turn (regression introduced by the
/// bridge-verification commit `decab6c`).
///
/// A missing install is still an observable `null` here, so the "bridge has no
/// X" report keeps its original purpose.
Object? _bridgeFn(String name) {
  try {
    return js.context[name];
  } catch (_) {
    return null;
  }
}

/// Runs one bridge function with the legacy `JsObject.callMethod` path.
/// Returns `null` when the function is not installed (or when the JS function
/// itself returns `undefined` — callers that must tell those apart check
/// [_bridgeFn] first).
Object? _callBridgeFn(String name, List<Object?> args) {
  if (_bridgeFn(name) == null) return null;
  return js.context.callMethod(name, args);
}

/// The bridge entry points this file depends on. Verified after install, so a
/// partial or stale page reports the real reason instead of failing later at
/// the first spoken reply.
const List<String> _requiredBridgeFns = <String>[
  '__bb_speak_text',
  '__bb_stop_speech',
  '__bb_play_tone',
  '__bb_play_model_audio',
  '__bb_stop_model_audio',
  '__bb_get_audio_ctx',
];

void _ensureJsBridge() {
  if (_jsBridgeInitialized && _pageBridgeVersion() == kJsBridgeVersion) {
    return;
  }
  _jsBridgeInitialized = true;

  try {
    js.context.callMethod('eval', ['''
      (function() {
        window.__bb_speech_engine_initialized = true;

        var AudioCtx = window.AudioContext || window.webkitAudioContext;
        window.__bb_audio_ctx = window.__bb_audio_ctx || null;
        window.__bb_active_rec = null;
        window.__bb_model_audio_next = 0;
        window.__bb_model_audio_sources = [];
        window.__bb_model_audio_drain_timer = null;
        window.__bb_active_utterance = window.__bb_active_utterance || null;

        window.__bb_get_audio_ctx = function() {
          try {
            if (!window.__bb_audio_ctx && AudioCtx) {
              window.__bb_audio_ctx = new AudioCtx();
            }
            if (window.__bb_audio_ctx && window.__bb_audio_ctx.state === "suspended") {
              window.__bb_audio_ctx.resume().catch(function(e) {
                console.warn("[BusBuddy Audio] AudioContext resume failed:", e);
              });
            }
          } catch (e) {
            console.warn("[BusBuddy Audio] AudioContext error:", e);
          }
          return window.__bb_audio_ctx;
        };

        window.__bb_remove_unlock_listeners = function() {
          if (!window.__bb_unlock_listeners_active) return;
          window.__bb_unlock_listeners_active = false;
          ["click", "pointerdown", "touchstart", "touchend", "keydown"].forEach(function(evt) {
            try {
              window.removeEventListener(evt, window.__bb_unlock_audio, { capture: true });
              document.removeEventListener(evt, window.__bb_unlock_audio, { capture: true });
            } catch (_) {}
          });
        };

        window.__bb_unlock_audio = function() {
          try {
            var ctx = window.__bb_get_audio_ctx();
            var primeHw = function(audioCtx) {
              try {
                if (audioCtx && audioCtx.state === "running") {
                  var sBuf = audioCtx.createBuffer(1, 1, 22050);
                  var sSrc = audioCtx.createBufferSource();
                  sSrc.buffer = sBuf;
                  sSrc.connect(audioCtx.destination);
                  sSrc.start(0);
                }
              } catch (_) {}
            };

            if (ctx && ctx.state === "suspended") {
              ctx.resume().then(function() {
                console.log("[BusBuddy Audio] AudioContext unlocked (" + ctx.sampleRate + "Hz)");
                primeHw(ctx);
                window.__bb_remove_unlock_listeners();
              });
            } else if (ctx && ctx.state === "running") {
              primeHw(ctx);
              window.__bb_remove_unlock_listeners();
            }
            if (window.speechSynthesis && window.speechSynthesis.paused) {
              window.speechSynthesis.resume();
            }
          } catch (_) {}
        };

        // Automatically unlock audio context on user gesture and track active state.
        // Guarded: bridge re-eval (hot reload) must not stack duplicate listeners.
        if (!window.__bb_unlock_listeners_active) {
          window.__bb_unlock_listeners_active = true;
          ["click", "pointerdown", "touchstart", "touchend", "keydown"].forEach(function(evt) {
            window.addEventListener(evt, window.__bb_unlock_audio, { capture: true, passive: true });
            document.addEventListener(evt, window.__bb_unlock_audio, { capture: true, passive: true });
          });
        }

        window.__bb_dispose_audio = function() {
          window.__bb_remove_unlock_listeners();
          if (window.__bb_stop_model_audio) {
            window.__bb_stop_model_audio();
          }
          if (window.__bb_stop_recognition) {
            window.__bb_stop_recognition();
          }
          if (window.__bb_stop_speech) {
            window.__bb_stop_speech();
          }
          if (window.__bb_audio_ctx && window.__bb_audio_ctx.state !== "closed") {
            try { window.__bb_audio_ctx.close(); } catch (_) {}
            window.__bb_audio_ctx = null;
          }
        };

        window.__bb_reset_turn = function() {
          window.__bb_generation = (window.__bb_generation || 0) + 1;
          if (window.__bb_speak_timer) {
            clearTimeout(window.__bb_speak_timer);
            window.__bb_speak_timer = null;
          }
          window.__bb_is_speaking = false;
          try {
            if (window.speechSynthesis) {
              window.speechSynthesis.cancel();
            }
          } catch (_) {}
          window.__bb_unlock_audio();
        };

        window.__bb_play_tone = function(isListening) {
          try {
            var ctx = window.__bb_get_audio_ctx();
            if (!ctx) return;
            var now = ctx.currentTime;
            var osc = ctx.createOscillator();
            var gain = ctx.createGain();
            osc.type = "sine";

            if (isListening) {
              osc.frequency.setValueAtTime(440.0, now);
              osc.frequency.setValueAtTime(880.0, now + 0.08);
              gain.gain.setValueAtTime(0.25, now);
              gain.gain.exponentialRampToValueAtTime(0.001, now + 0.22);
              osc.connect(gain);
              gain.connect(ctx.destination);
              osc.start(now);
              osc.stop(now + 0.22);
            } else {
              osc.frequency.setValueAtTime(523.25, now);
              osc.frequency.setValueAtTime(659.25, now + 0.12);
              osc.frequency.setValueAtTime(783.99, now + 0.24);
              gain.gain.setValueAtTime(0.30, now);
              gain.gain.exponentialRampToValueAtTime(0.001, now + 0.45);
              osc.connect(gain);
              gain.connect(ctx.destination);
              osc.start(now);
              osc.stop(now + 0.45);
            }
          } catch (e) {
            console.warn("[BusBuddy Audio] Tone playback error:", e);
          }
        };

        // ── Gemini's own voice on web (24 kHz mono PCM16) ──────────────────
        // The web half of the Chunk 49 contract. Android plays these chunks
        // through a native AudioTrack; here they go through the same Web Audio
        // context the chime uses, so the existing gesture unlock primes it and
        // there is no second audio stack to keep alive. Chunks are scheduled
        // back to back (start times chained off __bb_model_audio_next) so a
        // streamed reply plays as one continuous utterance, not as gaps.
        window.__bb_model_audio_rate = 24000;
        // Odd trailing byte carried between chunks. A chunk boundary can fall
        // between the two bytes of one PCM16 sample; decoding it alone would
        // shift every following sample by one byte and turn the reply into
        // noise. (Restored in v8 — dropping it was part of the v6 rewrite.)
        window.__bb_model_audio_tail = "";

        window.__bb_schedule_model_audio_drain = function() {
          var ctx = window.__bb_get_audio_ctx();
          if (!ctx) return;
          if (window.__bb_model_audio_drain_timer) {
            clearTimeout(window.__bb_model_audio_drain_timer);
          }
          // Every chunk reschedules this, so it only fires once the queue has
          // really played out. That is the web equivalent of Android's
          // onPlaybackDrained, and what releases the turn.
          var remainingMs =
            Math.max(0, window.__bb_model_audio_next - ctx.currentTime) * 1000 + 60;
          window.__bb_model_audio_drain_timer = setTimeout(function() {
            window.__bb_model_audio_drain_timer = null;
            if (window.__bb_on_model_audio_drained) {
              try { window.__bb_on_model_audio_drained(); } catch (e) {}
            }
          }, remainingMs);
        };

        window.__bb_play_model_audio = function(b64) {
          try {
            var ctx = window.__bb_get_audio_ctx();
            if (!ctx) {
              console.warn("[BusBuddy ModelAudio] no AudioContext yet; reply stays silent");
              return false;
            }
            // Chrome autoplay policy keeps a context created outside a user
            // gesture suspended. Scheduling on a suspended context is valid —
            // the queued buffers play once resume() completes — which is how
            // the pre-v6 build produced audible replies. v7 bailed out here
            // instead, and because the unlock in initState runs after the tap
            // that opened the screen, the context was suspended on essentially
            // every turn: "plays slightly late" became "never plays". The TTS
            // fallback it routed to had no text either (outputAudioTranscription
            // was never requested), so the reply was silent.
            //
            // So: resume, then schedule anyway. resume() is async but the
            // context starts advancing on its own; the queued sources play.
            if (ctx.state !== "running") {
              try { ctx.resume(); } catch (e) {}
            }

            // Normalise the payload before decoding. The Live API commonly
            // emits unpadded and/or URL-safe base64, and atob() throws on
            // both — which used to abort the whole turn (v6/v7 fed the raw
            // string straight to atob).
            var clean = (b64 || "").replace(/\\s+/g, "").replace(/-/g, "+").replace(/_/g, "/");
            while (clean.length % 4 !== 0) { clean += "="; }
            if (!clean) return false;

            var bin;
            try {
              bin = window.atob(clean);
            } catch (err) {
              console.warn("[BusBuddy ModelAudio] base64 decode failed:", err);
              return false;
            }

            // Keep an odd trailing byte for the next chunk so samples never
            // straddle a chunk boundary.
            if (window.__bb_model_audio_tail) {
              bin = window.__bb_model_audio_tail + bin;
              window.__bb_model_audio_tail = "";
            }
            if (bin.length % 2 !== 0) {
              window.__bb_model_audio_tail = bin.charAt(bin.length - 1);
              bin = bin.substring(0, bin.length - 1);
            }

            var frames = Math.floor(bin.length / 2);
            if (frames <= 0) return false;

            // base64 → little-endian PCM16 → normalized Float32 for Web Audio.
            var bytes = new Uint8Array(bin.length);
            for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
            var view = new DataView(bytes.buffer);
            var samples = new Float32Array(frames);
            for (var f = 0; f < frames; f++) {
              samples[f] = view.getInt16(f * 2, true) / 32768.0;
            }

            var buffer = ctx.createBuffer(1, frames, window.__bb_model_audio_rate);
            buffer.copyToChannel(samples, 0);
            var source = ctx.createBufferSource();
            source.buffer = buffer;
            source.connect(ctx.destination);
            // Catch up when scheduling fell behind (tab throttling, a late
            // gesture unlock) instead of replaying a backlog out of order.
            var startAt = Math.max(window.__bb_model_audio_next, ctx.currentTime);
            source.start(startAt);
            window.__bb_model_audio_next = startAt + buffer.duration;
            window.__bb_model_audio_sources.push(source);
            source.onended = function() {
              if (window.__bb_model_audio_sources) {
                var idx = window.__bb_model_audio_sources.indexOf(source);
                if (idx !== -1) window.__bb_model_audio_sources.splice(idx, 1);
              }
            };
            window.__bb_schedule_model_audio_drain();
            return true;
          } catch (e) {
            console.warn("[BusBuddy ModelAudio] play failed:", e);
            return false;
          }
        };

        // Barge-in and teardown: drop everything still queued or playing.
        window.__bb_stop_model_audio = function() {
          try {
            if (window.__bb_model_audio_drain_timer) {
              clearTimeout(window.__bb_model_audio_drain_timer);
              window.__bb_model_audio_drain_timer = null;
            }
            var sources = window.__bb_model_audio_sources || [];
            for (var i = 0; i < sources.length; i++) {
              try { sources[i].stop(); } catch (e) {}
            }
            window.__bb_model_audio_sources = [];
            window.__bb_model_audio_next = 0;
            window.__bb_model_audio_tail = "";
          } catch (e) {}
        };

        // THE single speaker in the entire app. Stop-before-speak: any prior
        // utterance or queued utterance is cancelled, then exactly one new
        // utterance is created and queued. Completion (or error) fires the
        // single __bb_on_audio_ended callback.
        window.__bb_speak_text = function(text, lang, rate) {
          if (!text || !text.trim()) return;
          if (!window.speechSynthesis) {
            console.warn("[BusBuddy TTS] SpeechSynthesis not supported in browser");
            return;
          }
          try {
            window.__bb_generation = (window.__bb_generation || 0) + 1;
            var currentGen = window.__bb_generation;
            if (window.__bb_speak_timer) {
              clearTimeout(window.__bb_speak_timer);
              window.__bb_speak_timer = null;
            }
            window.__bb_is_speaking = true;
            // Chrome bug: an utterance queued in the same tick as cancel() is
            // silently swallowed (no playback, no onend, no onerror). Defer
            // the speak one tick whenever something was actually playing or
            // queued, so the cancel settles first.
            var hadSpeech =
              window.speechSynthesis.speaking || window.speechSynthesis.pending;
            window.speechSynthesis.cancel();

            var cleanText = text.replace(/[*_#`~>]/g, "").trim();
            if (!cleanText) return;

            var utter = new SpeechSynthesisUtterance(cleanText);
            utter.lang = lang || "en-US";
            utter.rate = (typeof rate === "number" && rate > 0) ? rate : 1.0;
            utter.pitch = 1.0;
            window.__bb_active_utterance = utter;

            utter.onend = function() {
              if (currentGen !== (window.__bb_generation || 0)) return;
              window.__bb_active_utterance = null;
              window.__bb_is_speaking = false;
              if (window.__bb_on_audio_ended) {
                try { window.__bb_on_audio_ended(); } catch (_) {}
              }
            };

            utter.onerror = function(e) {
              if (currentGen !== (window.__bb_generation || 0)) return;
              console.warn("[BusBuddy TTS] utterance error:", e);
              window.__bb_active_utterance = null;
              window.__bb_is_speaking = false;
              if (window.__bb_on_audio_ended) {
                try { window.__bb_on_audio_ended(); } catch (_) {}
              }
            };

            var startSpeech = function() {
              if (currentGen !== (window.__bb_generation || 0)) return;
              if (window.speechSynthesis.paused) {
                window.speechSynthesis.resume();
              }
              window.speechSynthesis.speak(utter);
            };
            if (hadSpeech) {
              window.__bb_speak_timer = setTimeout(startSpeech, 60);
            } else {
              startSpeech();
            }
          } catch (e) {
            console.error("[BusBuddy TTS] init exception:", e);
          }
        };

        window.__bb_stop_speech = function() {
          try {
            window.__bb_generation = (window.__bb_generation || 0) + 1;
            if (window.__bb_speak_timer) {
              clearTimeout(window.__bb_speak_timer);
              window.__bb_speak_timer = null;
            }
            if (window.speechSynthesis) window.speechSynthesis.cancel();
            window.__bb_is_speaking = false;
          } catch (_) {}
          window.__bb_active_utterance = null;
        };

        window.__bb_start_recognition = function(lang, onResult, onError, onEnd) {
          window.__bb_stop_recognition();

          var SpeechRec = window.SpeechRecognition || window.webkitSpeechRecognition;
          if (!SpeechRec) {
            if (onError) onError("Web Speech API is not supported in this browser. Please use Chrome or Edge.");
            if (onEnd) onEnd();
            return;
          }

          try {
            var rec = new SpeechRec();
            window.__bb_active_rec = rec;
            rec.continuous = false;
            rec.interimResults = true;
            rec.lang = lang || "en-US";

            rec.onstart = function() {
              console.log("[WebSpeech] Microphone recognition started (" + rec.lang + ")");
            };

            rec.onresult = function(event) {
              try {
                var results = event.results;
                if (!results || results.length === 0) return;
                var last = results[results.length - 1];
                var isFinal = !!last.isFinal;
                var transcript = (last[0] && last[0].transcript) ? last[0].transcript.trim() : "";
                if (transcript.length > 0 && onResult) {
                  onResult(transcript, isFinal);
                }
              } catch (err) {
                console.error("[BusBuddy Speech] Result parse error:", err);
              }
            };

            rec.onerror = function(event) {
              var err = event.error || "unknown";
              if (err === "no-speech" || err === "aborted") return;
              var msg = err === "not-allowed"
                ? "Microphone permission blocked. Please allow microphone access in your browser address bar."
                : ("Voice recognition error: " + err);
              if (onError) onError(msg);
            };

            rec.onend = function() {
              if (window.__bb_active_rec === rec) {
                window.__bb_active_rec = null;
              }
              if (onEnd) onEnd();
            };

            rec.start();
          } catch (e) {
            window.__bb_active_rec = null;
            if (onError) onError("Could not access microphone: " + e);
            if (onEnd) onEnd();
          }
        };

        window.__bb_stop_recognition = function() {
          if (window.__bb_active_rec) {
            try {
              var oldRec = window.__bb_active_rec;
              window.__bb_active_rec = null;
              oldRec.onend = null;
              oldRec.onerror = null;
              oldRec.onresult = null;
              oldRec.abort();
            } catch (_) {}
          }
        };
      })();
    ''']);
    // Stamp the bridge version with a separate tiny eval so hot reload can
    // detect stale page JS and re-run the big eval above.
    js.context.callMethod(
        'eval', ['window.__bb_bridge_version = $kJsBridgeVersion; '
            'console.log("[BusBuddy SingleVoice] JS bridge v$kJsBridgeVersion ready (TTS-only)");']);

    // The version stamp is written even when the eval above did nothing, so
    // the next call would happily believe the bridge is installed. Verify the
    // entry points instead, and force a reinstall if any is missing.
    final missing =
        _requiredBridgeFns.where((name) => _bridgeFn(name) == null).toList();
    if (missing.isNotEmpty) {
      _jsBridgeInitialized = false;
      debugPrint(
        '[WebSpeech] JS bridge v$kJsBridgeVersion installed but missing '
        '${missing.join(', ')} — audio cannot play until the page JS is '
        'reinstalled (hot restart, or reload the page).',
      );
    }
  } catch (e) {
    // Leave the bridge "not initialized" so the next call retries instead of
    // trusting a version stamp written by a failed eval.
    _jsBridgeInitialized = false;
    debugPrint('[WebSpeech] JS bridge init error: $e');
  }
}

/// Plays an audible sound chime via the Web Audio API.
void playAudioTone({bool isListening = false}) {
  try {
    _ensureJsBridge();
    js.context.callMethod('__bb_play_tone', [isListening]);
  } catch (e) {
    debugPrint('[WebAudio] playAudioTone error: $e');
  }
}

/// Speaks text out loud through the Web Speech Synthesis API. This is the
/// app's only speech producer — one call, one utterance, one voice.
void speakText(String text) {
  try {
    _ensureJsBridge();
    // Presence is checked first: `__bb_speak_text` returns `undefined`, so the
    // call result alone cannot distinguish "spoke" from "bridge missing".
    if (_bridgeFn('__bb_speak_text') == null) {
      _reportMissingBridge('__bb_speak_text');
      return;
    }
    final langCode = AppSettingsController.instance.speechLanguageCode;
    final speechRate = AppSettingsController.instance.speechRate;
    js.context.callMethod('__bb_speak_text', <Object?>[
      text,
      langCode,
      speechRate,
    ]);
  } catch (e) {
    debugPrint('[WebSpeech] speakText error: $e');
  }
}

/// Plays one chunk of Gemini's own 24 kHz PCM16 voice through Web Audio.
///
/// Returns false when the chunk could not be scheduled (no AudioContext, an
/// undecodable payload). That is deliberately the caller's signal to fall back
/// to device TTS for the turn: the flag [ModelVoicePlayer.hasModelAudioThisTurn]
/// stays clear, so the reply is spoken rather than silently dropped.
bool playModelAudio(String base64Pcm16) {
  try {
    _ensureJsBridge();
    if (base64Pcm16.isEmpty) return false;
    final played =
        _callBridgeFn('__bb_play_model_audio', <Object?>[base64Pcm16]);
    if (played == null) {
      _reportMissingBridge('__bb_play_model_audio');
      return false;
    }
    return played == true;
  } catch (e) {
    debugPrint('[WebModelAudio] playModelAudio error: $e');
    return false;
  }
}

/// One line per missing entry point, so a silent reply always comes with the
/// reason it was silent.
void _reportMissingBridge(String name) {
  if (_missingBridgeReported.contains(name)) return;
  _missingBridgeReported.add(name);
  debugPrint(
    '[WebSpeech] page bridge has no $name — the JS bridge was not installed in '
    'this page. Hot restart the app (R) or reload the browser page.',
  );
}

final Set<String> _missingBridgeReported = <String>{};

/// Drops model audio that is still queued or playing (barge-in, teardown).
void stopModelAudio() {
  try {
    _ensureJsBridge();
    _callBridgeFn('__bb_stop_model_audio', const <Object?>[]);
  } catch (_) {}
}

/// Registers the one callback that fires when the scheduled model audio has
/// played out, which is the real end of a model-audio turn on web.
void setModelAudioDrainedCallback(VoidCallback onDrained) {
  try {
    _ensureJsBridge();
    if (_bridgeFn('__bb_on_model_audio_drained') == null &&
        _bridgeFn('__bb_play_model_audio') == null) {
      // The drain callback is a plain global assignment, so it only fails when
      // the whole bridge is absent — the same case playModelAudio reports.
      _reportMissingBridge('__bb_play_model_audio');
    }
    js.context['__bb_on_model_audio_drained'] =
        js_util.allowInterop(([dynamic _]) {
      onDrained();
    });
  } catch (_) {}
}

/// Stops any ongoing Web Speech synthesis audio.
void stopSpeech() {
  try {
    _ensureJsBridge();
    js.context.callMethod('__bb_stop_speech');
  } catch (_) {}
}

/// Listens to real microphone input using Web SpeechRecognition API in Chrome.
void startSpeechRecognition({
  required void Function(String text, bool isFinal) onResult,
  required void Function(String error) onError,
  required VoidCallback onEnd,
}) {
  try {
    _ensureJsBridge();
    final langCode = AppSettingsController.instance.speechLanguageCode;

    final onResultInterop = js_util.allowInterop((dynamic text, dynamic isFinal) {
      onResult(text.toString(), isFinal == true);
    });

    final onErrorInterop = js_util.allowInterop((dynamic err) {
      onError(err.toString());
    });

    final onEndInterop = js_util.allowInterop(([dynamic _]) {
      onEnd();
    });

    js.context.callMethod('__bb_start_recognition', [
      langCode,
      onResultInterop,
      onErrorInterop,
      onEndInterop,
    ]);
  } catch (e) {
    debugPrint('[WebSpeech] startSpeechRecognition error: $e');
    onError('Could not access microphone: $e');
    onEnd();
  }
}

/// Stops any ongoing microphone speech recognition session.
void stopSpeechRecognition() {
  try {
    _ensureJsBridge();
    js.context.callMethod('__bb_stop_recognition');
  } catch (_) {}
}

/// Invalidates any in-flight speech and prepares the bridge for a fresh turn.
void resetTurnAudio() {
  try {
    _ensureJsBridge();
    js.context.callMethod('__bb_reset_turn');
  } catch (_) {}
}

/// Ensures the Web Audio AudioContext and speech synthesis are unlocked and resumed on user gestures.
void unlockAudioContext() {
  try {
    _ensureJsBridge();
    js.context.callMethod('__bb_unlock_audio');
  } catch (_) {}
}

/// Registers the single callback that fires when the spoken utterance finishes.
void setAudioEndedCallback(VoidCallback onEnded) {
  try {
    _ensureJsBridge();
    js.context['__bb_on_audio_ended'] = js_util.allowInterop(([dynamic _]) {
      onEnded();
    });
  } catch (_) {}
}

/// Disposes web audio resources, audio context, and removes all global DOM gesture listeners.
void disposeAudio() {
  try {
    _ensureJsBridge();
    js.context.callMethod('__bb_dispose_audio');
  } catch (_) {}
}
