import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busbuddy/features/ai_assistant/ai_control_glow.dart';
import 'package:busbuddy/core/a11y/announcement_coordinator.dart';
import 'package:busbuddy/features/ai_assistant/audio_speech_engine.dart';
import 'package:busbuddy/features/ai_assistant/gemini_live_screen.dart';

void main() {
  tearDown(() {
    AiControlGlow.instance.idle();
    AudioSpeechEngine.muteOfflineTts(false);
    AnnouncementCoordinator.instance.reset();
  });

  group('AiControlGlow', () {
    test('notifies once per real mode change', () {
      final glow = AiControlGlow.instance;
      glow.idle();
      var notifications = 0;
      void count() => notifications++;
      glow.addListener(count);
      glow.listening();
      glow.listening(); // duplicate mode is suppressed
      glow.speaking();
      glow.acting();
      glow.idle();
      expect(notifications, 4);
      expect(glow.mode, AiGlowMode.idle);
    });
  });

  group('AiGlowFrame', () {
    testWidgets('paints top bar, bottom bar and both side rails while active',
        (tester) async {
      AiControlGlow.instance.listening();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(children: [SizedBox.expand(), AiGlowFrame()]),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(AiGlowFrame),
          matching: find.byType(DecoratedBox),
        ),
        findsNWidgets(4),
      );
      // Decorative only: never hittable, never a semantics node.
      expect(
        find.descendant(
          of: find.byType(AiGlowFrame),
          matching: find.byType(IgnorePointer),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AiGlowFrame),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      // The glow must actually fill the screen (a Stack whose only
      // children are Positioned expands to its biggest constraints).
      // Guards against a future refactor shrinking the frame to
      // nothing, which would render the glow invisible.
      final topBar = find.descendant(
        of: find.byType(AiGlowFrame),
        matching: find.byType(DecoratedBox),
      ).first;
      final topBarSize = tester.getSize(topBar);
      expect(topBarSize.width, 800);
      expect(topBarSize.height, 72);
    });

    testWidgets('renders nothing when the AI is idle', (tester) async {
      AiControlGlow.instance.idle();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(children: [SizedBox.expand(), AiGlowFrame()]),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(AiGlowFrame),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
    });

    testWidgets('repaints when the mode changes', (tester) async {
      AiControlGlow.instance.idle();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(children: [SizedBox.expand(), AiGlowFrame()]),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(AiGlowFrame),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
      AiControlGlow.instance.acting();
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(AiGlowFrame),
          matching: find.byType(DecoratedBox),
        ),
        findsNWidgets(4),
      );
    });

    testWidgets('GeminiLiveScreen drives the glow while it owns the mic',
        (tester) async {
      AiControlGlow.instance.idle();
      await tester.pumpWidget(const MaterialApp(home: GeminiLiveScreen()));
      // The post-frame mic start flips the screen (and the glow) to
      // listening — the glow can only advertise what the screen owns.
      await tester.pump();
      expect(AiControlGlow.instance.mode, AiGlowMode.listening);
      // Leaving the screen releases the app from AI control.
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(AiControlGlow.instance.mode, AiGlowMode.idle);
    });

    testWidgets('dispose clears the glow even when it was armed mid-teardown',
        (tester) async {
      // Regression: `mounted` stays true for the whole runDisposeSteps window
      // inside GeminiLiveScreen.dispose, so a synchronous teardown callback
      // (the web JS bridge fires some) could re-run setState and re-arm the
      // glow after the idle reset — leaving the glow over Home. The dispose
      // now clears the conversational flags first and resets the glow again
      // as the LAST step, so the worst case below still lands on idle.
      AiControlGlow.instance.idle();
      await tester.pumpWidget(const MaterialApp(home: GeminiLiveScreen()));
      await tester.pump();
      expect(AiControlGlow.instance.mode, AiGlowMode.listening);

      // Worst case: the glow is armed to a stale active mode right before the
      // screen leaves the tree (as if a mid-teardown callback had re-armed it).
      AiControlGlow.instance.speaking();
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(AiControlGlow.instance.mode, AiGlowMode.idle);
    });
  });
}
