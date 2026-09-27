import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

// Fields are assigned in the initialiser list because Dart forbids private
// names on named parameters, so `this._openMicrophone` is not available.
// ignore_for_file: prefer_initializing_formals

/// One spoken passenger turn, streamed into the live Gemini session.
///
/// Android has no on-device speech-to-text in this app, so instead of
/// transcribing locally the microphone PCM is forwarded straight to the
/// `BidiGenerateContent` session (`realtimeInput`), and the server decides when
/// the question is over. The assistant's own voice must never be fed back as a
/// question, so [pause] is called while it speaks and [resume] once it finishes
/// — hardware echo cancellation reduces, but does not remove, the need.
///
/// Every way this can fail ends in exactly one [onTurnLost] call with a reason
/// the passenger can act on; the caller then hands them the text box. It never
/// invents a transcript (Astra BUS-P0-06). A failure is reported once per
/// instance, so callers build a fresh turn for each spoken question.
class AndroidVoiceTurn {
  AndroidVoiceTurn({
    required Future<String?> Function() openMicrophone,
    required Future<void> Function() closeMicrophone,
    required Stream<Uint8List> Function() microphonePcm,
    required Stream<String> Function() microphoneErrors,
    required bool Function(String base64Pcm) sendAudio,
    required void Function(String reason, bool microphoneUnavailable) onTurnLost,
  })  : _openMicrophone = openMicrophone,
        _closeMicrophone = closeMicrophone,
        _microphonePcm = microphonePcm,
        _microphoneErrors = microphoneErrors,
        _sendAudio = sendAudio,
        _onTurnLost = onTurnLost;

  final Future<String?> Function() _openMicrophone;
  final Future<void> Function() _closeMicrophone;
  final Stream<Uint8List> Function() _microphonePcm;
  final Stream<String> Function() _microphoneErrors;
  final bool Function(String base64Pcm) _sendAudio;
  final void Function(String reason, bool microphoneUnavailable) _onTurnLost;

  // Owned per turn; cancelled by stop()/_fail(), hence not reported here.
  // ignore: cancel_subscriptions
  StreamSubscription<Uint8List>? _pcmSub;
  // ignore: cancel_subscriptions
  StreamSubscription<String>? _errorSub;

  bool _open = false;
  bool _paused = false;
  bool _reportedLost = false;
  Future<bool>? _starting;

  /// True while microphone capture for this turn is held open.
  bool get isActive => _open;

  /// True while capture is open but frames are withheld (assistant is speaking).
  bool get isPaused => _paused;

  /// Opens the microphone and starts forwarding. Returns false when the turn
  /// could not start — [onTurnLost] has already carried the reason by then.
  Future<bool> start() {
    if (_open) return Future<bool>.value(true);
    final pending = _starting ??= _start().whenComplete(() => _starting = null);
    return pending;
  }

  Future<bool> _start() async {
    // Errors first: a device that fails immediately should not have its
    // failure land in a stream nobody is listening to yet.
    _errorSub = _microphoneErrors().listen(
      (reason) => _loseTurn(reason, microphoneUnavailable: true),
    );
    final reason = await _openMicrophone();
    if (reason != null) {
      await stop();
      _loseTurn(reason, microphoneUnavailable: true);
      return false;
    }
    _open = true;
    _pcmSub = _microphonePcm().listen(
      (chunk) {
        if (!_open || _paused || chunk.isEmpty) return;
        if (!_sendAudio(base64Encode(chunk))) {
          // Not a microphone problem: the live socket is not ready, so the
          // passenger is pointed back at the text box without a mic warning.
          _loseTurn(
            'BusBuddy is not connected to the live service yet. Please type your question.',
            microphoneUnavailable: false,
          );
        }
      },
      onError: (Object error) => _loseTurn(
        'The microphone stopped working. Please type your question.',
        microphoneUnavailable: true,
      ),
    );
    return true;
  }

  /// Withholds frames while the assistant is talking. Capture stays open so the
  /// passenger can still interrupt (the session reports the interruption).
  void pause() => _paused = true;

  void resume() => _paused = false;

  /// Releases the microphone. Safe to call repeatedly and from [dispose].
  Future<void> stop() async {
    _open = false;
    _paused = false;
    final pcm = _pcmSub;
    final errors = _errorSub;
    _pcmSub = null;
    _errorSub = null;
    await pcm?.cancel();
    await errors?.cancel();
    await _closeMicrophone();
  }

  void _loseTurn(String reason, {required bool microphoneUnavailable}) {
    if (_reportedLost) return;
    _reportedLost = true;
    unawaited(stop());
    _onTurnLost(reason, microphoneUnavailable);
  }
}
