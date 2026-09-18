import 'package:flutter/foundation.dart';

// Conditional web import using JS interop / dart:html via web fallback
import 'web_speech_stub.dart'
    if (dart.library.html) 'web_speech_real.dart' as speech_impl;

class AudioSpeechEngine {
  const AudioSpeechEngine();

  /// Speaks the provided text out loud through the device/browser speakers.
  /// Note: Offline TTS has been removed in favor of native Gemini Live 24kHz PCM voice streaming.
  void speak(String text) {
    // Offline TTS removed. Voice output is streamed directly via Gemini Live playPcmAudio.
    debugPrint('[AudioSpeechEngine] Offline TTS disabled: $text');
  }

  /// Stops any currently playing audio.
  void stop() {
    if (kIsWeb) {
      speech_impl.stopSpeech();
    }
  }

  /// Stops any ongoing microphone speech recognition.
  void stopListening() {
    if (kIsWeb) {
      speech_impl.stopSpeechRecognition();
    }
  }

  /// Plays a quick sound chime through Web Audio API.
  void playChime({bool isListening = false}) {
    if (kIsWeb) {
      speech_impl.playAudioTone(isListening: isListening);
    }
  }

  /// Plays native PCM audio returned directly from the Gemini Live API.
  void playPcmAudio(String base64Pcm, {int sampleRate = 24000}) {
    if (kIsWeb) {
      speech_impl.playPcm16Audio(base64Pcm, sampleRate: sampleRate);
    }
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

  /// Sets a callback that fires when speech output (PCM or TTS) finishes playing.
  void setAudioEndedCallback(VoidCallback onEnded) {
    if (kIsWeb) {
      speech_impl.setAudioEndedCallback(onEnded);
    }
  }

  /// Starts listening to the user's microphone for live voice speech recognition.
  void startListening({
    required Function(String text, bool isFinal) onResult,
    required Function(String error) onError,
    required VoidCallback onEnd,
  }) {
    if (kIsWeb) {
      speech_impl.startSpeechRecognition(
        onResult: onResult,
        onError: onError,
        onEnd: onEnd,
      );
    } else {
      onResult('Where is my bus?', true);
      onEnd();
    }
  }
}
