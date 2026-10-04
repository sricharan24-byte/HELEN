import 'dart:async';

import 'native_audio_channel.dart';
import 'native_platform_io.dart';

/// Plays Gemini Live's **own** audio — the 24 kHz mono PCM16 the model streams
/// back — through the native `AudioTrack`, instead of re-speaking the reply
/// text with the device text-to-speech engine.
///
/// Why this exists: Android's `TextToSpeech` engine is the robotic one. The
/// model audio is the natural voice the passenger asked for, and the Live API
/// already sends it (`responseModalities: ['AUDIO']`).
///
/// The single-speaker contract from Chunk 43 still holds, and this class is
/// what keeps it true:
///
///  * **Exactly one voice.** [hasModelAudioThisTurn] is the decision input for
///    the caller: if the model streamed audio for this turn, the reply is NOT
///    also handed to TTS. Device TTS remains the fallback for turns that carry
///    no audio at all (plain text turns, REST fallback, a dead socket).
///  * **No overlap.** [addChunk] opens playback lazily on the first chunk, so a
///    turn that never produces audio never touches the `AudioTrack` and never
///    competes with TTS.
///  * **Barge-in.** [stop] drops queued and playing audio, which the session
///    calls on interruption.
///
/// Android only. Web keeps `AudioSpeechEngine.speak` (Web SpeechSynthesis),
/// and [isSupported] is false there so the caller falls back to it.
class ModelVoicePlayer {
  ModelVoicePlayer({
    NativeAudioChannel? channel,
    bool Function()? isSupported,
  })  : _channel = channel ?? NativeAudioChannel(),
        _isSupported = isSupported ?? _defaultSupported {
    // Cancelled by dispose(), which is the documented teardown call.
    // ignore: cancel_subscriptions
    _drainSub = _channel.onPlaybackDrained.listen((_) {
      _playing = false;
      if (!_drained.isClosed) _drained.add(null);
    });
  }

  /// `Platform.isAndroid` is false while tests run on the Linux VM, so the
  /// check is injectable exactly like [NativeAudioChannel.isPlatformSupported].
  static bool _defaultSupported() => platformHasNativeAudio;

  final NativeAudioChannel _channel;
  final bool Function() _isSupported;
  final StreamController<void> _drained = StreamController<void>.broadcast();
  StreamSubscription<void>? _drainSub;

  bool _playing = false;
  bool _hasModelAudioThisTurn = false;

  /// True only where the native `AudioTrack` path exists (Android).
  bool get isSupported => _isSupported();

  /// Whether the model streamed audio for the turn in progress. The caller must
  /// skip TTS while this is true, or the reply is spoken twice.
  bool get hasModelAudioThisTurn => _hasModelAudioThisTurn;

  /// Whether audio is currently queued or playing.
  bool get isPlaying => _playing;

  /// Fires when the `AudioTrack` has drained (the native side posts this once
  /// the buffer empties), which is the real end of the assistant's turn.
  Stream<void> get onDrained => _drained.stream;

  /// Marks the start of a new conversational turn.
  void beginTurn() {
    _hasModelAudioThisTurn = false;
  }

  /// Forwards one streamed PCM chunk to the native `AudioTrack`.
  ///
  /// Returns without touching audio on unsupported platforms, so a web build
  /// keeps using TTS and never has a half-open playback session.
  Future<void> addChunk(String base64Pcm16) async {
    if (!isSupported || base64Pcm16.isEmpty) return;
    _hasModelAudioThisTurn = true;
    if (!_playing) {
      _playing = true;
      await _channel.startPlayback();
    }
    await _channel.writePlaybackChunk(base64Pcm16);
  }

  /// Barge-in and teardown: drop everything queued plus whatever is playing.
  Future<void> stop() async {
    if (!isSupported) return;
    if (!_playing) return;
    _playing = false;
    await _channel.stopPlayback();
  }

  Future<void> dispose() async {
    await _drainSub?.cancel();
    _drainSub = null;
    await stop();
    await _drained.close();
  }
}
