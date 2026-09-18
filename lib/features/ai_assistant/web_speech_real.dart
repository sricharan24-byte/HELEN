// ignore_for_file: deprecated_member_use, uri_does_not_exist
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'package:flutter/foundation.dart';

import '../../core/settings/app_settings_controller.dart';

bool _jsBridgeInitialized = false;

void _ensureJsBridge() {
  if (_jsBridgeInitialized) return;
  _jsBridgeInitialized = true;

  try {
    js.context.callMethod('eval', ['''
      (function() {
        if (window.__bb_speech_engine_initialized) return;
        window.__bb_speech_engine_initialized = true;

        var AudioCtx = window.AudioContext || window.webkitAudioContext;
        window.__bb_audio_ctx = null;
        window.__bb_pcm_next_time = 0;
        window.__bb_active_rec = null;
        window.__bb_active_utterance = null;
        window.__bb_active_sources = [];

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

        window.__bb_unlock_audio = function() {
          try {
            var ctx = window.__bb_get_audio_ctx();
            if (ctx && ctx.state === "suspended") {
              ctx.resume().then(function() {
                console.log("[BusBuddy Audio] AudioContext unlocked (" + ctx.sampleRate + "Hz)");
              });
            }
            // Prime browser audio hardware with a microscopic silent buffer
            if (ctx && ctx.state === "running") {
              var sBuf = ctx.createBuffer(1, 1, 22050);
              var sSrc = ctx.createBufferSource();
              sSrc.buffer = sBuf;
              sSrc.connect(ctx.destination);
              sSrc.start(0);
            }
            if (window.speechSynthesis && window.speechSynthesis.paused) {
              window.speechSynthesis.resume();
            }
          } catch (_) {}
        };

        // Automatically unlock audio context on ANY user tap, click, touch, or key press
        ["click", "pointerdown", "touchstart", "touchend", "keydown"].forEach(function(evt) {
          window.addEventListener(evt, window.__bb_unlock_audio, { capture: true, passive: true });
          document.addEventListener(evt, window.__bb_unlock_audio, { capture: true, passive: true });
        });

        window.__bb_reset_turn = function() {
          window.__bb_generation = (window.__bb_generation || 0) + 1;
          if (window.__bb_speak_timer) {
            clearTimeout(window.__bb_speak_timer);
            window.__bb_speak_timer = null;
          }
          if (window.__bb_audio_end_timer) {
            clearTimeout(window.__bb_audio_end_timer);
            window.__bb_audio_end_timer = null;
          }
          window.__bb_pcm_tail = "";
          if (window.__bb_active_sources && window.__bb_active_sources.length > 0) {
            window.__bb_active_sources.forEach(function(s) {
              try { s.stop(); s.disconnect(); } catch (_) {}
            });
            window.__bb_active_sources = [];
          }
          window.__bb_pcm_next_time = 0;
          window.__bb_is_pcm_active = false;
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

        window.__bb_play_pcm = function(b64, rate) {
          try {
            if (window.__bb_speak_timer) {
              clearTimeout(window.__bb_speak_timer);
              window.__bb_speak_timer = null;
            }
            if (window.__bb_audio_end_timer) {
              clearTimeout(window.__bb_audio_end_timer);
              window.__bb_audio_end_timer = null;
            }
            try {
              if (window.speechSynthesis) window.speechSynthesis.cancel();
            } catch (_) {}
            window.__bb_is_pcm_active = true;
            window.__bb_is_speaking = true;

            var ctx = window.__bb_get_audio_ctx();
            if (!ctx) return;
            if (ctx.state === "suspended") {
              ctx.resume();
            }

            // Clean Base64 string: remove whitespace, convert url-safe base64 (- and _), pad =
            var clean = (b64 || "").replace(/\\s+/g, "").replace(/-/g, "+").replace(/_/g, "/");
            while (clean.length % 4 !== 0) {
              clean += "=";
            }
            if (!clean) return;

            var bin;
            try {
              bin = atob(clean);
            } catch (err) {
              console.error("[BusBuddy Audio] PCM base64 atob failed:", err);
              return;
            }

            // Handle odd-byte carryover across chunks to prevent 16-bit PCM channel/byte misalignment buzzing
            if (window.__bb_pcm_tail) {
              bin = window.__bb_pcm_tail + bin;
              window.__bb_pcm_tail = "";
            }
            if (bin.length % 2 !== 0) {
              window.__bb_pcm_tail = bin.charAt(bin.length - 1);
              bin = bin.substring(0, bin.length - 1);
            }

            var len = Math.floor(bin.length / 2);
            if (len === 0) return;

            var sampleRate = rate || 24000;
            var buf = ctx.createBuffer(1, len, sampleRate);
            var ch = buf.getChannelData(0);
            for (var i = 0; i < len; i++) {
              var b1 = bin.charCodeAt(i * 2);
              var b2 = bin.charCodeAt(i * 2 + 1);
              var s = (b2 << 8) | b1;
              if (s >= 32768) s -= 65536;
              ch[i] = s / 32768.0;
            }

            var src = ctx.createBufferSource();
            src.buffer = buf;
            var gain = ctx.createGain();
            gain.gain.value = 1.0;
            src.connect(gain);
            gain.connect(ctx.destination);

            var now = ctx.currentTime;
            // Schedule strictly sequentially with a 120ms jitter buffer on fresh start
            if (!window.__bb_pcm_next_time || window.__bb_pcm_next_time < now) {
              window.__bb_pcm_next_time = now + 0.12;
            }
            var startTime = window.__bb_pcm_next_time;
            src.start(startTime);
            window.__bb_pcm_next_time = startTime + buf.duration;

            if (!window.__bb_active_sources) {
              window.__bb_active_sources = [];
            }
            window.__bb_active_sources.push(src);
            var currentGen = window.__bb_generation || 0;

            src.onended = function() {
              if (currentGen !== (window.__bb_generation || 0)) {
                try { src.disconnect(); } catch (_) {}
                return;
              }
              if (window.__bb_active_sources) {
                var idx = window.__bb_active_sources.indexOf(src);
                if (idx !== -1) {
                  window.__bb_active_sources.splice(idx, 1);
                }
              }
              try { src.disconnect(); } catch (_) {}

              if (!window.__bb_active_sources || window.__bb_active_sources.length === 0) {
                if (window.__bb_audio_end_timer) {
                  clearTimeout(window.__bb_audio_end_timer);
                }
                window.__bb_audio_end_timer = setTimeout(function() {
                  window.__bb_audio_end_timer = null;
                  if (currentGen !== (window.__bb_generation || 0)) return;
                  if (!window.__bb_active_sources || window.__bb_active_sources.length === 0) {
                    window.__bb_is_pcm_active = false;
                    window.__bb_is_speaking = false;
                    if (window.__bb_on_audio_ended) {
                      try { window.__bb_on_audio_ended(); } catch (_) {}
                    }
                  }
                }, 250);
              }
            };
          } catch (e) {
            console.error("[BusBuddy Audio] PCM playback error:", e);
          }
        };

        window.__bb_speak_text = function(text, lang, rate) {
          // Offline TTS voice mode removed in favor of native Gemini Live 24kHz PCM voice streaming.
          try {
            if (window.speechSynthesis) window.speechSynthesis.cancel();
          } catch (_) {}
        };

        window.__bb_stop_speech = function() {
          try {
            window.__bb_generation = (window.__bb_generation || 0) + 1;
            if (window.__bb_speak_timer) {
              clearTimeout(window.__bb_speak_timer);
              window.__bb_speak_timer = null;
            }
            if (window.__bb_audio_end_timer) {
              clearTimeout(window.__bb_audio_end_timer);
              window.__bb_audio_end_timer = null;
            }
            window.__bb_pcm_tail = "";
            if (window.speechSynthesis) window.speechSynthesis.cancel();
            if (window.__bb_active_sources && window.__bb_active_sources.length > 0) {
              window.__bb_active_sources.forEach(function(s) {
                try { s.stop(); s.disconnect(); } catch (_) {}
              });
              window.__bb_active_sources = [];
            }
            window.__bb_pcm_next_time = 0;
            window.__bb_is_pcm_active = false;
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
  } catch (e) {
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

/// Plays base64-encoded 16-bit linear PCM audio streamed from the Gemini Live API.
void playPcm16Audio(String base64Pcm, {int sampleRate = 24000}) {
  try {
    _ensureJsBridge();
    js.context.callMethod('__bb_play_pcm', [base64Pcm, sampleRate]);
  } catch (e) {
    debugPrint('[WebAudio] playPcm16Audio error: $e');
  }
}

/// Speaks text out loud through Web Speech Synthesis API and plays an audible response chime.
void speakText(String text) {
  try {
    _ensureJsBridge();
    final langCode = AppSettingsController.instance.speechLanguageCode;
    final speechRate = AppSettingsController.instance.speechRate;
    js.context.callMethod('__bb_speak_text', [text, langCode, speechRate]);
  } catch (e) {
    debugPrint('[WebSpeech] speakText error: $e');
  }
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
  required Function(String text, bool isFinal) onResult,
  required Function(String error) onError,
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

/// Resets PCM audio queue time and prepares audio context for a fresh response turn.
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

/// Registers a callback that fires when either speech synthesis or native PCM audio finishes playing.
void setAudioEndedCallback(VoidCallback onEnded) {
  try {
    _ensureJsBridge();
    js.context['__bb_on_audio_ended'] = js_util.allowInterop(([dynamic _]) {
      onEnded();
    });
  } catch (_) {}
}
