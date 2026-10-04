import 'dart:async';

import 'package:flutter/foundation.dart';

import 'native_audio_channel.dart';
import 'native_platform_io.dart';

// Same seam the speech engine uses: the web backend below needs dart:js, and
// the stub keeps this file compiling (and inert) on Android and desktop.
import 'web_speech_stub.dart'
    if (dart.library.html) 'web_speech_real.dart' as speech_impl;

/// Plays Gemini Live's **own** audio — the 24 kHz mono PCM16 the model streams
/// back — instead of re-speaking the reply text with the device
/// text-to-speech engine.
///
/// Why this exists: Android's `TextToSpeech` engine is the robotic one, and
/// before Chunk 49's web half the browser had no path at all — it dropped these
/// chunks and fell back to `speechSynthesis`, which is silent on a machine with
/// no system TTS engine. The model audio is the natural voice the passenger
/// asked for, and the Live API already sends it
/// (`responseModalities: ['AUDIO']`).
///
/// The single-speaker contract from Chunk 43 still holds, and this class is
/// what keeps it true:
///
///  * **Exactly one voice.** [hasModelAudioThisTurn] is the decision input for
///    the caller: if the model streamed audio for this turn, the reply is NOT
///    also handed to TTS. Device TTS remains the fallback for turns that carry
///    no audio at all (plain text turns, REST fallback, a dead socket).
///  * **No overlap.** [addChunk] opens playback lazily on the first chunk, so a
///    turn that never produces audio never touches the playback backend and
///    never competes with TTS.
///  * **Barge-in.** [stop] drops queued and playing audio, which the session
///    calls on interruption.
///
/// Android plays through the native `AudioTrack`; web plays the same PCM
/// through the Web Audio context that already backs the listening chime (so the
/// existing gesture unlock primes it). Desktop and tests support neither and
/// report [isSupported] false, leaving TTS in charge.
class ModelVoicePlayer {
  ModelVoicePlayer({
    NativeAudioChannel? channel,
    bool Function()? isSupported,
  })  : _channel = channel ?? NativeAudioChannel(),
        _isSupported = isSupported ?? _defaultSupported {
    if (kIsWeb) {
      // Web has no platform event: the drain is scheduled off the
      // AudioContext queue in the JS bridge.
      speech_impl.setModelAudioDrainedCallback(_handleDrained);
    } else {
      // Cancelled by dispose(), which is the documented teardown call.
      // ignore: cancel_subscriptions
      _drainSub = _channel.onPlaybackDrained.listen((_) => _handleDrained());
    }
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

  /// True where model audio can actually be played: Android (native
  /// `AudioTrack`) and web (Web Audio).
  bool get isSupported => kIsWeb || _isSupported();

  /// Whether the model streamed audio for the turn in progress. The caller must
  /// skip TTS while this is true, or the reply is spoken twice.
  bool get hasModelAudioThisTurn => _hasModelAudioThisTurn;

  /// Whether audio is currently queued or playing.
  bool get isPlaying => _playing;

  /// Fires when playback has drained, which is the real end of the assistant's
  /// turn.
  Stream<void> get onDrained => _drained.stream;

  /// Marks the start of a new conversational turn.
  void beginTurn() {
    _hasModelAudioThisTurn = false;
  }

  /// Forwards one streamed PCM chunk to the active playback backend.
  ///
  /// Returns without touching audio on unsupported platforms, so a desktop build
  /// keeps using TTS and never has a half-open playback session.
  Future<void> addChunk(String base64Pcm16) async {
    if (base64Pcm16.isEmpty) return;
    if (kIsWeb) {
      // A chunk that will not schedule (no AudioContext yet, undecodable
      // payload) leaves the flag clear, which is exactly how this turn falls
      // back to TTS instead of dropping the reply on the floor.
      if (speech_impl.playModelAudio(base64Pcm16)) {
        _hasModelAudioThisTurn = true;
        _playing = true;
      }
      return;
    }
    if (!isSupported) return;
    _hasModelAudioThisTurn = true;
    if (!_playing) {
      _playing = true;
      await _channel.startPlayback();
    }
    await _channel.writePlaybackChunk(base64Pcm16);
  }

  /// Barge-in and teardown: drop everything queued plus whatever is playing.
  Future<void> stop() async {
    if (kIsWeb) {
      speech_impl.stopModelAudio();
      _playing = false;
      return;
    }
    if (!isSupported) return;
    if (!_playing) return;
    _playing = false;
    await _channel.stopPlayback();
  }

  void _handleDrained() {
    _playing = false;
    if (!_drained.isClosed) _drained.add(null);
  }

  Future<void> dispose() async {
    await stop();
    await _drainSub?.cancel();
    _drainSub = null;
    await _drained.close();
  }
}
