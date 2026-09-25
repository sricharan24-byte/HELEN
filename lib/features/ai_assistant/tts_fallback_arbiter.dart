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
  TtsFallbackArbiter({
    this.grace = const Duration(milliseconds: 600),
    this.liveGrace = const Duration(milliseconds: 1800),
  });

  /// App-wide arbitration instance. The Gemini Live screen and the floating
  /// assistant drive separate sessions but share ONE global audio bridge
  /// (native PCM + browser TTS on the same window object); each owner's
  /// private arbiter can only arbitrate its own turns, so handoff moments
  /// (fullscreen transitions, in-flight turns) could let an armed TTS from
  /// one owner overlap late PCM from the other. First-starter-wins must be
  /// enforced against the single shared output, so both owners must use
  /// this same instance.
  static final TtsFallbackArbiter shared = TtsFallbackArbiter();

  /// Grace for offline/REST turns (PCM impossible or unlikely).
  final Duration grace;

  /// Extended grace for Live WebSocket turns where native PCM routinely
  /// arrives hundreds of ms after the text turn completes. Prevents the
  /// double-voice race (TTS started, then late PCM overlaps it).
  final Duration liveGrace;

  Timer? _pendingTts;
  bool _pcmReceived = false;
  bool _ttsStarted = false;

  /// Generation for which the TTS fallback already fired. A turn's completion
  /// can arrive twice (tool-protocol turn + follow-up answer share one text
  /// accumulator); without this, the same turn speaks twice with the second
  /// voice joining mid-utterance over the first.
  int _firedGeneration = -1;

  /// Monotonic turn counter. Every [beginTurn] bumps it; scheduled callbacks
  /// capture the generation and no-op when stale so a late callback from a
  /// previous query can never speak over the current turn.
  int _generation = 0;
  int get generation => _generation;

  /// Whether a deferred TTS callback is currently armed.
  bool get hasPendingTts => _pendingTts?.isActive ?? false;

  /// Whether the browser TTS fallback has already started speaking for this
  /// turn. Once true, late native PCM must be dropped (TTS wins) — otherwise
  /// the two voices overlap mid-sentence.
  bool get ttsStarted => _ttsStarted;

  /// Starts a new conversational turn: drops pending TTS, clears PCM state.
  void beginTurn() {
    _generation++;
    cancel();
    _pcmReceived = false;
    _ttsStarted = false;
  }

  /// Records an incoming native PCM chunk; cancels any pending TTS fallback.
  /// Returns the current generation so callers can tag PCM playback.
  int notifyPcmReceived() {
    _pcmReceived = true;
    cancel();
    return _generation;
  }

  /// First-starter-wins claim for a native PCM chunk. Returns true when PCM
  /// may play (cancels pending TTS). Returns false when the browser TTS has
  /// already started speaking for this turn — the caller must drop the chunk
  /// so the single started voice finishes alone.
  bool tryClaimPcm() {
    if (_ttsStarted) return false;
    notifyPcmReceived();
    return true;
  }

  /// Cancels a pending deferred TTS without touching PCM state.
  void cancel() {
    _pendingTts?.cancel();
    _pendingTts = null;
  }

  /// Speaks immediately, bypassing the grace window. Use only when native
  /// PCM is impossible for this turn (no Live API key / REST-only transport).
  /// The callback is still generation-guarded: if a new turn begins before
  /// [speak] runs, it is dropped.
  void speakNow(void Function() speak) {
    cancel();
    final gen = _generation;
    // speakNow is synchronous by contract; guard re-entrancy via generation.
    if (gen == _generation && _firedGeneration != _generation) {
      _firedGeneration = _generation;
      _ttsStarted = true;
      speak();
    }
  }

  /// Defers [speak] by [grace] (or [liveGrace] when [isLive] is true); runs
  /// only if no PCM chunk arrives first and the turn is still current.
  /// Marks the turn as TTS-started so late PCM is dropped (first-starter-wins).
  /// Fires at most once per generation: a repeated schedule for a turn that
  /// already spoke is dropped instead of layering a second voice on top.
  void scheduleFallback(void Function() speak, {bool isLive = false}) {
    cancel();
    if (_pcmReceived) {
      return;
    }
    if (_firedGeneration == _generation) {
      return;
    }
    final gen = _generation;
    final delay = isLive ? liveGrace : grace;
    _pendingTts = Timer(delay, () {
      _pendingTts = null;
      if (gen != _generation) return;
      if (_firedGeneration == _generation) return;
      if (!_pcmReceived) {
        _firedGeneration = _generation;
        _ttsStarted = true;
        speak();
      }
    });
  }

  /// Releases timer resources.
  void dispose() {
    cancel();
  }
}
