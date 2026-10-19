import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/features/ai_assistant/gemini_live_screen.dart';
import 'package:busbuddy/core/a11y/announcement_coordinator.dart';
import 'package:busbuddy/features/ai_assistant/audio_speech_engine.dart';

// Regression test (single-voice, Chunk 42 follow-up): the spoken-output live
// region must never carry the reply sentence. The reply is spoken by the
// app's own PCM/TTS voice; a screen reader (TalkBack/ChromeVox) announcing
// the same sentence through its live-region label produces two voices saying
// the same words simultaneously. The live region may only announce the
// speaking-state transition; the reply text stays a regular semantics node
// reachable by navigation.
void main() {
  setUp(() {
    AudioSpeechEngine.muteOfflineTts(false);
    AnnouncementCoordinator.instance.reset();
  });
  group('GeminiLiveScreen single-voice semantics contract', () {
    testWidgets('spoken-output live region never exposes the reply text',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: GeminiLiveScreen()),
      );
      // Flush the initial 600ms mic-start timer + 4s speech animation timer.
      await tester.pump(const Duration(seconds: 6));

      final liveRegions = tester.widgetList<Semantics>(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.liveRegion == true,
        ),
      );

      // The reply is spoken by Gemini/PCM (or the single fallback TTS path).
      // Anything marked as a live region must never carry it, and the current
      // screen deliberately owns no live region at all.
      for (final region in liveRegions) {
        final label = region.properties.label ?? '';
        expect(
          label.contains('announcement'),
          isFalse,
          reason:
              'live region must not interpolate the spoken output text: "$label"',
        );
        expect(
          label,
          anyOf('Gemini is speaking', 'Gemini Live response ready'),
          reason: 'live region label must be a stable state label: "$label"',
        );
      }
      expect(liveRegions, isEmpty);
      // The reply text stays reachable as ordinary semantics content.
      expect(find.textContaining("Hi, I'm BusBuddy"), findsOneWidget);
    });
  });
}
