import 'dart:async';

/// Single-voice arbitration for AI reply audio output.
///
/// Problem: when the Gemini Live WebSocket streams native 24 kHz PCM audio,
/// trailing PCM chunks can arrive *after* `onTurnComplete` fires. Speaking
/// the turn text immediately via Web SpeechSynthesis in that window produces
/// two simultaneous voices (native PCM + browser TTS saying the same words).
///
/// The arbiter defers the TTS fallback by [grace] when Live PCM is possible;
/// any PCM chunk arriving first cancels the pending TTS. Local/offline turns
/// (no API key, REST-only transport) speak immediately via [speakNow].
class TtsFallbackArbiter {
  TtsFallbackArbiter({this.grace = const Duration(milliseconds: 600)});

  final Duration grace;
  Timer? _pendingTts;
  bool _pcmReceived = false;

  /// Whether a deferred TTS callback is currently armed.
  bool get hasPendingTts => _pendingTts?.isActive ?? false;

  /// Starts a new conversational turn: drops pending TTS, clears PCM state.
  void beginTurn() {
    cancel();
    _pcmReceived = false;
  }

  /// Records an incoming native PCM chunk; cancels any pending TTS fallback.
  void notifyPcmReceived() {
    _pcmReceived = true;
    cancel();
  }

  /// Cancels a pending deferred TTS without touching PCM state.
  void cancel() {
    _pendingTts?.cancel();
    _pendingTts = null;
  }

  /// Speaks immediately, bypassing the grace window. Use only when native
  /// PCM is impossible for this turn (no Live API key / REST-only transport).
  void speakNow(void Function() speak) {
    cancel();
    speak();
  }

  /// Defers [speak] by [grace]; runs only if no PCM chunk arrives first.
  void scheduleFallback(void Function() speak) {
    cancel();
    if (_pcmReceived) {
      return;
    }
    _pendingTts = Timer(grace, () {
      _pendingTts = null;
      if (!_pcmReceived) {
        speak();
      }
    });
  }

  /// Releases timer resources.
  void dispose() {
    cancel();
  }
}
