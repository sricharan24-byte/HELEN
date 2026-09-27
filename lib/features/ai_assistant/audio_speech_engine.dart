import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

// Conditional web import using JS interop / dart:html via web fallback
import 'web_speech_stub.dart'
    if (dart.library.html) 'web_speech_real.dart' as speech_impl;
import '../../core/settings/app_settings_controller.dart';
import 'native_audio_channel.dart';

/// Process-wide native audio bridge (Android `AudioRecord`/`AudioTrack`/TTS).
/// One instance owns the platform channels for the whole app session.
final NativeAudioChannel nativeAudioChannel = NativeAudioChannel();

class AudioSpeechEngine {
  AudioSpeechEngine({NativeAudioChannel? nativeAudio})
      : _native = nativeAudio ?? nativeAudioChannel;

  final NativeAudioChannel _native;

  // Native TTS bookkeeping: the platform reports `onSpeakDone` when an
  // utterance finishes, which is what resumes continuous listening.
  VoidCallback? _onEnded;
  Timer? _endFallback;
  // Cancelled by _cancelEndTracking (stop/dispose/end), not in this method.
  // ignore: cancel_subscriptions
  StreamSubscription<String>? _doneSub;

  /// Speaks the provided text out loud through the device/browser speakers.
  void speak(String text) {
    if (kIsWeb) {
      speech_impl.speakText(text);
      return;
    }
    if (_native.isSupported) {
      // One utterance, stop-before-speak, exactly like the web bridge.
      unawaited(
        _native
            .speakTts(
          text: text,
          languageCode: AppSettingsController.instance.speechLanguageCode,
          rate: AppSettingsController.instance.speechRate,
        )
            .then((bool started) {
          if (started) {
            _armEndFallback(text);
          } else {
            // No usable system engine: keep the conversation moving at once
            // instead of waiting on the screen's watchdog.
            _fireEnded();
          }
        }),
      );
      return;
    }
    debugPrint('[AudioSpeechEngine] Offline TTS: $text');
  }

  /// Stops any currently playing audio.
  void stop() {
    if (kIsWeb) {
      speech_impl.stopSpeech();
      return;
    }
    // Barge-in: drop the pending utterance and its completion fallback without
    // firing the ended callback (the caller is about to speak the next turn).
    _cancelEndTracking(fireEnded: false);
    unawaited(_native.stopTts());
    unawaited(_native.stopPlayback());
  }

  /// Stops any ongoing microphone speech recognition.
  void stopListening() {
    if (kIsWeb) {
      speech_impl.stopSpeechRecognition();
      return;
    }
    unawaited(_native.stopMicrophone());
  }

  /// Plays a quick sound chime through Web Audio API.
  void playChime({bool isListening = false}) {
    if (kIsWeb) {
      speech_impl.playAudioTone(isListening: isListening);
      return;
    }
    unawaited(_native.playTone(isListening: isListening));
  }

  /// Resets audio timing and clears queue for a fresh conversational response.
  void resetTurn() {
    if (kIsWeb) {
      speech_impl.resetTurnAudio();
    }
  }

  /// Unlocks the Web Audio Context and Speech Synthesis on user gesture.
  void unlockAudio() {
    if (kIsWeb) {
      speech_impl.unlockAudioContext();
    }
  }

  /// Shown when no microphone recognition path exists on this platform, so the
  /// passenger is never left without an explanation (BUS-P0-06 / BUS-P1-08).
  static const String noRecognitionFallbackMessage =
      'Microphone voice recognition is currently optimized for Web/Chrome. '
      'Please use text input or enable voice simulation.';

  /// Feature gate for simulated voice input on platforms lacking speech recognition (e.g., Android/desktop emulator).
  /// Strictly false by default in production per Astra BUS-P0-06.
  static bool get enableSimulatedVoiceInput => speech_impl.enableSimulatedVoiceInput;
  static set enableSimulatedVoiceInput(bool value) {
    speech_impl.enableSimulatedVoiceInput = value;
  }

  /// Sets a callback that fires when speech output (PCM or TTS) finishes playing.
  void setAudioEndedCallback(VoidCallback onEnded) {
    _onEnded = onEnded;
    if (kIsWeb) {
      speech_impl.setAudioEndedCallback(onEnded);
    }
  }

  /// Watches the native utterance for completion. If the system engine never
  /// reports back (dead engine, audio-focus loss), the callback still fires
  /// once the utterance could have finished, so continuous listening resumes.
  void _armEndFallback(String text) {
    _cancelEndTracking(fireEnded: false);
    _doneSub = _native.onSpeakDone.listen((_) => _fireEnded());
    final words = text.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
    _endFallback = Timer(Duration(milliseconds: 2500 + math.min(52500, words * 320)), _fireEnded);
  }

  void _fireEnded() {
    _cancelEndTracking(fireEnded: true);
  }

  void _cancelEndTracking({required bool fireEnded}) {
    _endFallback?.cancel();
    _endFallback = null;
    final sub = _doneSub;
    _doneSub = null;
    if (sub != null) unawaited(sub.cancel());
    if (fireEnded) _onEnded?.call();
  }

  /// True when this platform can stream microphone PCM into the live session:
  /// Android with `BusBuddyVoiceChannel` registered. Web uses the Web Speech
  /// API path, and desktop/tests use neither.
  bool get supportsLiveAudioInput => !kIsWeb && _native.isSupported;

  /// Microphone PCM for a voice turn; subscribe after [openLiveMicrophone]
  /// returns null.
  Stream<Uint8List> get liveMicrophonePcm => _native.microphone;

  /// Reasons the native capture thread gave for going quiet mid-turn (device
  /// input unusable, access revoked). A turn must be released on any event.
  Stream<String> get liveMicrophoneErrors => _native.microphoneErrors;

  /// Opens native microphone capture for a voice turn, asking `RECORD_AUDIO`
  /// just in time (the screen has already announced the purpose).
  ///
  /// Returns `null` on success, otherwise a passenger-facing reason that already
  /// tells them to fall back to the text box (BUS-P0-06 / BUS-P1-08).
  Future<String?> openLiveMicrophone() async {
    if (!supportsLiveAudioInput) return noRecognitionFallbackMessage;
    if (!await _native.isChannelAvailable()) {
      // Desktop runs or a build without the native plugin: no mic at all.
      return noRecognitionFallbackMessage;
    }
    if (!await _native.hasMicrophonePermission()) {
      final reply = await _native.requestMicrophonePermission();
      if (!reply.granted) {
        return reply.permanentlyDenied
            ? 'Microphone access is turned off for BusBuddy in Android settings. Please type your question.'
            : 'Microphone permission was not granted. Please type your question.';
      }
    }
    if (!await _native.startMicrophone()) {
      return 'The microphone could not be opened on this device. Please type your question.';
    }
    return null;
  }

  /// Releases microphone capture taken by [openLiveMicrophone].
  Future<void> closeLiveMicrophone() => _native.stopMicrophone();

  /// Starts listening to the user's microphone for live voice speech recognition.
  void startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function(String error) onError,
    required VoidCallback onEnd,
  }) {
    if (kIsWeb) {
      speech_impl.startSpeechRecognition(
        onResult: onResult,
        onError: onError,
        onEnd: onEnd,
      );
    } else if (enableSimulatedVoiceInput) {
      onResult('Where is my bus?', true);
      onEnd();
    } else if (_native.isSupported) {
      unawaited(
        _startAndroidListening(onResult: onResult, onError: onError, onEnd: onEnd),
      );
    } else {
      onError(noRecognitionFallbackMessage);
      onEnd();
    }
  }

  /// Transcript-free Android path for callers that cannot stream microphone
  /// audio into a live session: it still runs the honest permission flow, then
  /// says plainly that a spoken question is not understood yet.
  ///
  /// No transcript is invented here: BUS-P0-06 keeps [enableSimulatedVoiceInput]
  /// off in production, and this path never fabricates one either. Passengers
  /// keep the text box, and the microphone is not left open doing nothing —
  /// lighting the recording indicator while the assistant cannot hear would
  /// mislead a TalkBack user (BUS-P1-08).
  Future<void> _startAndroidListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function(String error) onError,
    required VoidCallback onEnd,
  }) async {
    final reason = await openLiveMicrophone();
    if (reason == null) await closeLiveMicrophone();
    onError(
      reason ??
          'BusBuddy can speak to you on this device, but this screen cannot turn '
              'a spoken question into a request yet. Please type your question.',
    );
    onEnd();
  }

  /// Disposes underlying audio resources and cleans up global event listeners.
  void dispose() {
    // The platform bridge is app-scoped (MainActivity releases its audio handles
    // on destroy), so screens only release their own turn state here.
    _cancelEndTracking(fireEnded: false);
    unawaited(_native.stopMicrophone());
    if (kIsWeb) {
      speech_impl.disposeAudio();
    }
  }
}
