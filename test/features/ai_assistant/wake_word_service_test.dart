import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busbuddy/core/settings/app_settings_controller.dart';
import 'package:busbuddy/core/a11y/announcement_coordinator.dart';
import 'package:busbuddy/features/ai_assistant/ai_control_glow.dart';
import 'package:busbuddy/features/ai_assistant/audio_speech_engine.dart';
import 'package:busbuddy/features/ai_assistant/gemini_live_screen.dart';
import 'package:busbuddy/features/ai_assistant/wake_word_service.dart';

class FakeAudioSpeechEngine extends AudioSpeechEngine {
  bool isListeningStarted = false;
  bool isListeningStopped = false;
  int chimeCount = 0;
  void Function(String text, bool isFinal)? lastOnResult;

  @override
  void startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function(String error) onError,
    required VoidCallback onEnd,
  }) {
    isListeningStarted = true;
    lastOnResult = onResult;
  }

  @override
  void stopListening() {
    isListeningStopped = true;
    isListeningStarted = false;
  }

  @override
  void playChime({bool isListening = false}) {
    chimeCount++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AiControlGlow.instance.idle();
    AudioSpeechEngine.muteOfflineTts(false);
    AnnouncementCoordinator.instance.reset();
    AppSettingsController.instance.updateWakePhrase(true);
    WakeWordService.instance.resetForTesting();
  });

  tearDown(() {
    WakeWordService.instance.resetForTesting(uninitialize: true);
    AudioSpeechEngine.muteOfflineTts(false);
    AnnouncementCoordinator.instance.reset();
    AiControlGlow.instance.idle();
  });

  group('WakeWordMatch pattern matching', () {
    test('matches exact wake phrases', () {
      final m1 = WakeWordService.match('Hey BusBuddy');
      expect(m1.isMatched, isTrue);
      expect(m1.query, isNull);

      final m2 = WakeWordService.match('hey busbuddy');
      expect(m2.isMatched, isTrue);
      expect(m2.query, isNull);

      final m3 = WakeWordService.match('bus buddy');
      expect(m3.isMatched, isTrue);
      expect(m3.query, isNull);

      final m4 = WakeWordService.match('OK BusBuddy');
      expect(m4.isMatched, isTrue);
      expect(m4.query, isNull);

      final m5 = WakeWordService.match('Hello BusBuddy');
      expect(m5.isMatched, isTrue);
      expect(m5.query, isNull);
    });

    test('extracts trailing queries', () {
      final m1 = WakeWordService.match('Hey BusBuddy, where is my bus?');
      expect(m1.isMatched, isTrue);
      expect(m1.query, equals('where is my bus?'));

      final m2 = WakeWordService.match('hey bus buddy find a bus to katpadi');
      expect(m2.isMatched, isTrue);
      expect(m2.query, equals('find a bus to katpadi'));

      final m3 = WakeWordService.match('OK BusBuddy: can you book a ticket?');
      expect(m3.isMatched, isTrue);
      expect(m3.query, equals('can you book a ticket?'));
    });

    test('rejects unrelated speech or empty strings', () {
      expect(WakeWordService.match('').isMatched, isFalse);
      expect(WakeWordService.match('   ').isMatched, isFalse);
      expect(WakeWordService.match('hello there').isMatched, isFalse);
      expect(WakeWordService.match('the buddy is on the bus').isMatched, isFalse);
      expect(WakeWordService.match('where is the bus station').isMatched, isFalse);
    });
  });

  group('WakeWordService trigger sequence', () {
    test('triggerWake sets glow, plays chime, and triggers callback', () {
      final fakeEngine = FakeAudioSpeechEngine();
      WakeWordService.instance.audioEngine = fakeEngine;

      String? capturedQuery;
      WakeWordService.instance.onWakeWordDetected = (q) => capturedQuery = q;

      WakeWordService.instance.triggerWake(query: 'what is my seat number?');

      expect(AiControlGlow.instance.mode, equals(AiGlowMode.listening));
      expect(fakeEngine.chimeCount, equals(1));
      expect(capturedQuery, equals('what is my seat number?'));
    });

    test('simulateWakeWord invokes wake sequence when matched', () {
      final fakeEngine = FakeAudioSpeechEngine();
      WakeWordService.instance.audioEngine = fakeEngine;

      String? capturedQuery;
      WakeWordService.instance.onWakeWordDetected = (q) => capturedQuery = q;

      final matched = WakeWordService.instance.simulateWakeWord('Hey BusBuddy, check route 1');
      expect(matched, isTrue);
      expect(capturedQuery, equals('check route 1'));
      expect(fakeEngine.chimeCount, equals(1));
    });

    test('simulateWakeWord returns false on unmatched input', () {
      final fakeEngine = FakeAudioSpeechEngine();
      WakeWordService.instance.audioEngine = fakeEngine;

      final matched = WakeWordService.instance.simulateWakeWord('just talking about buses');
      expect(matched, isFalse);
      expect(fakeEngine.chimeCount, equals(0));
    });
  });

  group('WakeWordService pause & resume lifecycle', () {
    test('pause stops listening and prevents wake trigger', () {
      final fakeEngine = FakeAudioSpeechEngine();
      WakeWordService.instance.audioEngine = fakeEngine;
      final navKey = GlobalKey<NavigatorState>();
      WakeWordService.instance.initialize(navigatorKey: navKey);

      expect(WakeWordService.instance.isListening, isTrue);

      WakeWordService.instance.pause();
      expect(WakeWordService.instance.isPaused, isTrue);
      expect(WakeWordService.instance.isListening, isFalse);
      expect(fakeEngine.isListeningStopped, isTrue);

      // Feeding transcript while paused must not trigger
      int detectCount = 0;
      WakeWordService.instance.onWakeWordDetected = (_) => detectCount++;
      fakeEngine.lastOnResult?.call('Hey BusBuddy', true);
      expect(detectCount, equals(0));
    });

    test('settings toggle disables and re-enables wake word listening', () {
      final fakeEngine = FakeAudioSpeechEngine();
      WakeWordService.instance.audioEngine = fakeEngine;
      final navKey = GlobalKey<NavigatorState>();
      WakeWordService.instance.initialize(navigatorKey: navKey);

      expect(WakeWordService.instance.isListening, isTrue);

      AppSettingsController.instance.updateWakePhrase(false);
      expect(WakeWordService.instance.isListening, isFalse);

      AppSettingsController.instance.updateWakePhrase(true);
      expect(WakeWordService.instance.isListening, isTrue);
    });
  });

  group('WakeWordService navigation integration', () {
    testWidgets('triggerWake pushes GeminiLiveScreen with initialQuery onto navigator',
        (tester) async {
      final fakeEngine = FakeAudioSpeechEngine();
      WakeWordService.instance.audioEngine = fakeEngine;
      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: const Scaffold(body: Text('Home Page')),
        ),
      );

      WakeWordService.instance.initialize(navigatorKey: navKey);

      WakeWordService.instance.simulateWakeWord('Hey BusBuddy, when is next bus?');
      // GeminiLiveScreen runs repeating animations and a live connection:
      // pump frames manually instead of pumpAndSettle (which never settles).
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(GeminiLiveScreen), findsOneWidget);

      // Tear the tree down the same way the connect-gate tests do: replacing
      // the widget disposes the screen without a pop transition, then one
      // pump flushes the 400ms ambient-listen resume timer dispose arms
      // (fake engine schedules nothing further) so no timer outlives the test.
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Home Page'))),
      );
      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}
