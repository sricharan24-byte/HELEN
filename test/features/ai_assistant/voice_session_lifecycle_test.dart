import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/features/ai_assistant/audio_speech_engine.dart';
import 'package:busbuddy/core/a11y/announcement_coordinator.dart';
import 'package:busbuddy/core/settings/app_settings_controller.dart';
import 'package:busbuddy/features/ai_assistant/gemini_live_session.dart';
import 'package:busbuddy/features/ai_assistant/gemini_live_screen.dart';
import 'package:busbuddy/features/ai_assistant/gemini_live_transport.dart';

void main() {
  setUp(() {
    AudioSpeechEngine.muteOfflineTts(false);
    AnnouncementCoordinator.instance.reset();
  });
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

  group('BUS-P1-08 Microphone State Honesty', () {
    // Found on an Android emulator run (2026-09-30): the screen opened showing
    // "Continuous Mic Active" and "Listening…" with no microphone open, because
    // `_isListening` defaulted to `true`. That also made
    // `_startMicrophoneListening` early-return on its own `_isListening` guard,
    // so the very first open never started capture at all — on any platform.
    // Found only by running the app: no unit test reached this state.
    //
    // Found again in Chrome (2026-10-11): the web path skipped the Live
    // gate entirely, so a first-run passenger with no API key saw the same
    // "Continuous Mic Active" / "Listening…" pair under a NOT CONNECTED
    // banner — the screen promised a microphone that could not answer.
    const neutral = 'Tap the microphone or a chip below to ask BusBuddy something.';
    const active = 'Listening... Speak into your microphone.';
    const needsKey =
        'BusBuddy needs a Gemini Live key before it can listen, so the '
        'microphone stayed off. Please type your question, or tap Connect '
        'to add your key.';

    testWidgets('first frame does not claim to be listening', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: GeminiLiveScreen()));

      // Nothing is capturing yet, so the screen must not imply that it is.
      expect(find.text(neutral), findsOneWidget);
      expect(find.text('Continuous Mic Active'), findsNothing);
    });

    testWidgets('first open with no API key names the key, not listening', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: GeminiLiveScreen()));

      // The post-frame start must still run — but with no key connected the
      // gate keeps the microphone closed and the screen says exactly that,
      // instead of the old "Listening…" over a NOT CONNECTED session.
      await tester.pump();
      expect(find.text(needsKey), findsOneWidget);
      expect(find.text(active), findsNothing);
      expect(find.text('Continuous Mic Active'), findsNothing);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    });

    testWidgets('a ready session opens the mic path and earns the listening claim', (tester) async {
      GeminiLiveSession.testValidateOverride = (key) async => null;
      addTearDown(() => GeminiLiveSession.testValidateOverride = null);
      AppSettingsController.instance.updateGeminiApiKey('test-key');
      addTearDown(() => AppSettingsController.instance.updateGeminiApiKey(''));
      final fake = _FakeTransport();

      await tester.pumpWidget(
        MaterialApp(home: GeminiLiveScreen(transportFactory: () => fake)),
      );
      await tester.pump();
      fake.serverSay!('{"setupComplete":{}}');
      // A zero-duration pump: flushes the microtasks that carry the gated
      // start through the now-ready session, without advancing the fake clock
      // (which would fire the silent-cycle restart timers).
      await tester.pump();

      // Handshake complete: the mic path now runs, but the listening claim is
      // earned — the test environment has no recognizer, so capture never
      // reports onstart and the honest "Preparing the microphone…" holds
      // instead of "Listening…" or the pill.
      expect(find.textContaining('Live Ready'), findsOneWidget);
      expect(find.text('Preparing the microphone...'), findsOneWidget);
      expect(find.text('Continuous Mic Active'), findsNothing);
      expect(find.text(active), findsNothing);

      // Let the fake clock run past the post-frame start's in-flight handshake
      // poll (200 ms steps, 4 s deadline) and the silent-cycle cutoff, so no
      // timer is left pending when the tree is disposed.
      await tester.pump(const Duration(milliseconds: 4300));

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    });

    testWidgets('three silent cycles stop the listening promise and name the problem', (tester) async {
      GeminiLiveSession.testValidateOverride = (key) async => null;
      addTearDown(() => GeminiLiveSession.testValidateOverride = null);
      AppSettingsController.instance.updateGeminiApiKey('test-key');
      addTearDown(() => AppSettingsController.instance.updateGeminiApiKey(''));
      final fake = _FakeTransport();

      await tester.pumpWidget(
        MaterialApp(home: GeminiLiveScreen(transportFactory: () => fake)),
      );
      await tester.pump();
      fake.serverSay!('{"setupComplete":{}}');
      await tester.pump(const Duration(milliseconds: 300));

      // Every cycle ends with no transcript at all (no recognizer here), the
      // continuous mode restarts — and after three empty cycles the screen
      // must say the microphone heard nothing instead of looping "Listening…"
      // forever (the wrong-input-device case has no other visible symptom).
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining("couldn't hear anything"), findsOneWidget);
      expect(find.text(active), findsNothing);
      expect(find.text('Continuous Mic Active'), findsNothing);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    });
  });
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
