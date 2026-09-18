import 'package:flutter/foundation.dart';

void playAudioTone({bool isListening = false}) {
  debugPrint('[AudioTone Stub] tone played: isListening=$isListening');
}

void playPcm16Audio(String base64Pcm, {int sampleRate = 24000}) {
  debugPrint('[PcmAudio Stub] ${base64Pcm.length} chars @ $sampleRate Hz');
}

void speakText(String text) {
  debugPrint('[TTS Stub] $text');
}

void stopSpeech() {}

void stopSpeechRecognition() {}

void resetTurnAudio() {}

void unlockAudioContext() {}
void setAudioEndedCallback(VoidCallback onEnded) {}

void startSpeechRecognition({
  required Function(String text, bool isFinal) onResult,
  required Function(String error) onError,
  required VoidCallback onEnd,
}) {
  onResult('Where is my bus?', true);
  onEnd();
}
