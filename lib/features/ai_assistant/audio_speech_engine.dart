import 'package:flutter/foundation.dart';

// Conditional web import using JS interop / dart:html via web fallback
import 'web_speech_stub.dart'
    if (dart.library.html) 'web_speech_real.dart' as speech_impl;

class AudioSpeechEngine {
  const AudioSpeechEngine();

  /// Speaks the provided text out loud through the device/browser speakers.
  void speak(String text) {
    if (kIsWeb) {
      speech_impl.speakText(text);
    } else {
      debugPrint('[AudioSpeechEngine] Offline TTS: $text');
    }
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

  /// Feature gate for simulated voice input on platforms lacking speech recognition (e.g., Android/desktop emulator).
  /// Strictly false by default in production per Astra BUS-P0-06.
  static bool get enableSimulatedVoiceInput => speech_impl.enableSimulatedVoiceInput;
  static set enableSimulatedVoiceInput(bool value) {
    speech_impl.enableSimulatedVoiceInput = value;
  }

  /// Sets a callback that fires when speech output (PCM or TTS) finishes playing.
  void setAudioEndedCallback(VoidCallback onEnded) {
    if (kIsWeb) {
      speech_impl.setAudioEndedCallback(onEnded);
    }
  }

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
    } else {
      onError('Microphone voice recognition is currently optimized for Web/Chrome. Please use text input or enable voice simulation.');
      onEnd();
    }
  }

  /// Disposes underlying audio resources and cleans up global event listeners.
  void dispose() {
    if (kIsWeb) {
      speech_impl.disposeAudio();
    }
  }
}
