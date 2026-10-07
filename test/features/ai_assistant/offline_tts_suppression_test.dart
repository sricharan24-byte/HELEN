import 'package:flutter_test/flutter_test.dart';
import 'package:busbuddy/core/a11y/announcement_coordinator.dart';
import 'package:busbuddy/features/ai_assistant/audio_speech_engine.dart';
import 'package:busbuddy/features/ai_assistant/wake_word_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AudioSpeechEngine.muteOfflineTts(false);
    AnnouncementCoordinator.instance.reset();
  });

  tearDown(() {
    AudioSpeechEngine.muteOfflineTts(false);
    AnnouncementCoordinator.instance.reset();
  });

  group('Offline TTS Suppression for Gemini Live', () {
    test('muteOfflineTts silences speech in AudioSpeechEngine', () {
      expect(AudioSpeechEngine.isOfflineTtsMuted, isFalse);

      AudioSpeechEngine.muteOfflineTts(true);
      expect(AudioSpeechEngine.isOfflineTtsMuted, isTrue);

      // Calling speak while muted must be a safe no-op
      final engine = AudioSpeechEngine();
      engine.speak('Test utterance while muted');

      AudioSpeechEngine.muteOfflineTts(false);
      expect(AudioSpeechEngine.isOfflineTtsMuted, isFalse);
    });

    test('AnnouncementCoordinator suppresses spoken speech when isAssistantActive is true', () {
      final coordinator = AnnouncementCoordinator.instance;
      coordinator.isSpeechEnabled = true;
      coordinator.isAssistantActive = true;

      String? spokenMessage;
      coordinator.speechSpeaker = (msg) => spokenMessage = msg;

      final result = coordinator.announce('Bus 18B approaching');
      expect(result, isTrue);
      // Spoken voice callback was suppressed because assistant is active
      expect(spokenMessage, isNull);

      coordinator.isAssistantActive = false;
      coordinator.announce('Bus 18B arrived');
      expect(spokenMessage, equals('Bus 18B arrived'));
    });

    test('WakeWordService triggerWake immediately mutes offline TTS', () {
      expect(AudioSpeechEngine.isOfflineTtsMuted, isFalse);

      WakeWordService.instance.triggerWake(query: 'check bus');

      expect(AudioSpeechEngine.isOfflineTtsMuted, isTrue);
      expect(AnnouncementCoordinator.instance.isAssistantActive, isTrue);
    });
  });
}
