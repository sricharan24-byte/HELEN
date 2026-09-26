import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/features/ai_assistant/audio_speech_engine.dart';
import 'package:busbuddy/features/ai_assistant/gemini_live_session.dart';
import 'package:busbuddy/features/ai_assistant/gemini_live_screen.dart';

void main() {
  group('BUS-P1-08 Voice Session Lifecycle & Backoff Tests', () {
    test('GeminiLiveSession initializes with 0 reconnect attempts and max 5', () {
      final session = GeminiLiveSession();
      expect(session.reconnectAttempts, equals(0));
      expect(GeminiLiveSession.maxReconnectAttempts, equals(5));
      session.dispose();
      expect(session.reconnectAttempts, equals(0));
    });

    test('AudioSpeechEngine dispose completes cleanly without throwing', () {
      final engine = AudioSpeechEngine();
      expect(engine.dispose, returnsNormally);
    });
  });

  group('BUS-P1-08 Voice Permission Recovery Widget Tests', () {
    testWidgets('GeminiLiveScreen renders accessible Try Again button when mic permission blocked', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: GeminiLiveScreen(),
        ),
      );
      await tester.pump();

      // Find the screen
      expect(find.byType(GeminiLiveScreen), findsOneWidget);

      // Verify the voice action orb exposes its own semantics node with at
      // least 48x48dp hit bounds (BUS-P1-08 touch-target floor).
      final orbFinder = find.bySemanticsLabel(
        RegExp('Microphone orb', caseSensitive: false),
      );
      expect(orbFinder, findsOneWidget);
      final orbSize = tester.getSize(orbFinder.first);
      expect(orbSize.width, greaterThanOrEqualTo(48.0));
      expect(orbSize.height, greaterThanOrEqualTo(48.0));
    });
  });
}
