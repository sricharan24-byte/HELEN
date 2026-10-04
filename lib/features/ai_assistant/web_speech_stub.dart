import 'package:flutter/foundation.dart';

bool enableSimulatedVoiceInput = false;

void playAudioTone({bool isListening = false}) {
  debugPrint('[AudioTone Stub] tone played: isListening=$isListening');
}

void speakText(String text) {
  debugPrint('[TTS Stub] $text');
}

/// Web-only model-audio playback. Inert everywhere else, so a desktop run or a
/// unit test can never reach Web Audio.
bool playModelAudio(String base64Pcm16) => false;

void stopModelAudio() {}

void setModelAudioDrainedCallback(VoidCallback onDrained) {}

void stopSpeech() {}

void stopSpeechRecognition() {}

void resetTurnAudio() {}

void unlockAudioContext() {}
void setAudioEndedCallback(VoidCallback onEnded) {}
void disposeAudio() {}


void startSpeechRecognition({
  required void Function(String text, bool isFinal) onResult,
  required void Function(String error) onError,
  required VoidCallback onEnd,
}) {
  if (enableSimulatedVoiceInput) {
    onResult('Where is my bus?', true);
    onEnd();
  } else {
    onError('Microphone voice recognition is currently optimized for Web/Chrome. Please use text input or enable voice simulation.');
    onEnd();
  }
}
