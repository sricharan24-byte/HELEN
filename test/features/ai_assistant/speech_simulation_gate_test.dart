import 'package:flutter_test/flutter_test.dart';
import 'package:busbuddy/features/ai_assistant/audio_speech_engine.dart';

void main() {
  group('Speech Simulation Feature Gate Tests (BUS-P0-06)', () {
    tearDown(() {
      AudioSpeechEngine.enableSimulatedVoiceInput = false;
    });

    test('enableSimulatedVoiceInput defaults to false', () {
      expect(AudioSpeechEngine.enableSimulatedVoiceInput, isFalse);
    });

    test('when gate is false, startListening fails gracefully without fake query', () {
      AudioSpeechEngine.enableSimulatedVoiceInput = false;
      final engine = AudioSpeechEngine();

      String? receivedText;
      String? receivedError;
      bool didEnd = false;

      engine.startListening(
        onResult: (text, isFinal) {
          receivedText = text;
        },
        onError: (err) {
          receivedError = err;
        },
        onEnd: () {
          didEnd = true;
        },
      );

      expect(receivedText, isNull);
      expect(receivedError, isNotNull);
      expect(receivedError, contains('Microphone voice recognition'));
      expect(didEnd, isTrue);
    });

    test('when gate is explicitly true, simulated voice query is emitted', () {
      AudioSpeechEngine.enableSimulatedVoiceInput = true;
      final engine = AudioSpeechEngine();

      String? receivedText;
      String? receivedError;
      bool didEnd = false;

      engine.startListening(
        onResult: (text, isFinal) {
          receivedText = text;
        },
        onError: (err) {
          receivedError = err;
        },
        onEnd: () {
          didEnd = true;
        },
      );

      expect(receivedText, equals('Where is my bus?'));
      expect(receivedError, isNull);
      expect(didEnd, isTrue);
    });
  });
}
