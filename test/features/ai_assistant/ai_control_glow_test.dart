import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busbuddy/features/ai_assistant/ai_control_glow.dart';
import 'package:busbuddy/core/a11y/announcement_coordinator.dart';
import 'package:busbuddy/core/settings/app_settings_controller.dart';
import 'package:busbuddy/features/ai_assistant/audio_speech_engine.dart';
import 'package:busbuddy/features/ai_assistant/gemini_live_screen.dart';
import 'package:busbuddy/features/ai_assistant/gemini_live_session.dart';
import 'package:busbuddy/features/ai_assistant/gemini_live_transport.dart';

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
      await _pumpReadyAssistant(tester);
      // The screen owns a live voice turn, so it — not anything else — has
      // lit the glow. (With simulated capture the turn flows straight into a
      // query, so the exact mode is the turn's; what is pinned is that the
      // screen, and only the screen, is driving it.)
      expect(AiControlGlow.instance.mode, isNot(AiGlowMode.idle));
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
      await _pumpReadyAssistant(tester);
      expect(AiControlGlow.instance.mode, isNot(AiGlowMode.idle));

      // Worst case: the glow is armed to a stale active mode right before the
      // screen leaves the tree (as if a mid-teardown callback had re-armed it).
      AiControlGlow.instance.speaking();
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(AiControlGlow.instance.mode, AiGlowMode.idle);
    });
  });
}

/// Pumps GeminiLiveScreen with a connected, handshake-complete session and
/// simulated voice input, so the screen genuinely owns a voice turn.
///
/// The microphone is earned now (BUS-P1-08): the screen never claims — or
/// lights the glow for — a mic that is not open, so these tests must take the
/// full path: key set, gate satisfied, capture opened. The pending-timer pump
/// lets the post-frame start's in-flight handshake poll expire before the
/// tree is disposed.
Future<void> _pumpReadyAssistant(WidgetTester tester) async {
  AudioSpeechEngine.enableSimulatedVoiceInput = true;
  GeminiLiveSession.testValidateOverride = (key) async => null;
  AppSettingsController.instance.updateGeminiApiKey('test-key');
  addTearDown(() {
    AudioSpeechEngine.enableSimulatedVoiceInput = false;
    GeminiLiveSession.testValidateOverride = null;
    AppSettingsController.instance.updateGeminiApiKey('');
  });
  final fake = _FakeTransport();
  await tester.pumpWidget(
    MaterialApp(home: GeminiLiveScreen(transportFactory: () => fake)),
  );
  await tester.pump();
  fake.serverSay!('{"setupComplete":{}}');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 4300));
}

/// Records frames instead of opening a socket, and lets the test speak as the
/// server (same shape as the fake in key_connect_gate_test.dart).
class _FakeTransport implements GeminiLiveTransport {
  final frames = <String>[];
  bool _open = false;
  void Function(String message)? serverSay;

  @override
  bool get isConnected => _open;

  @override
  void connect(
    String url, {
    required void Function() onOpen,
    required void Function(String message) onMessage,
    required void Function(Object error) onError,
    required void Function(int? code, String? reason) onClose,
  }) {
    _open = true;
    serverSay = onMessage;
    onOpen();
  }

  @override
  void send(String data) => frames.add(data);

  @override
  void close() => _open = false;
}
