import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/core/settings/app_settings_controller.dart';
import 'package:busbuddy/core/a11y/announcement_coordinator.dart';
import 'package:busbuddy/features/ai_assistant/audio_speech_engine.dart';
import 'package:busbuddy/features/ai_assistant/gemini_live_screen.dart';
import 'package:busbuddy/features/ai_assistant/gemini_live_session.dart';
import 'package:busbuddy/features/ai_assistant/gemini_live_transport.dart';

/// Pins the API-key connect gate added for "the api key is not connecting".
///
/// What used to happen: the dialog stored the key and opened the socket with
/// no validation, the screen announced 'Live Connected' on socket open before
/// any handshake, and close reasons stayed in debugPrint. A bad key, a
/// rejected model and a dead network all looked identical: silence.
///
/// What must happen now: every connect goes through [_connectValidated]
/// (validate first via `GET models`, then open the socket), the status names
/// the real failure, and a key saved from anywhere reconnects the open
/// screen through the settings listener.
void main() {
  setUp(() {
    GeminiLiveSession.testValidateOverride = null;
    AudioSpeechEngine.muteOfflineTts(false);
    AnnouncementCoordinator.instance.reset();
  });
  tearDown(() {
    GeminiLiveSession.testValidateOverride = null;
    AppSettingsController.instance.updateGeminiApiKey('');
  });

  group('validateApiKey', () {
    test('empty key fails without touching the network', () async {
      final error = await GeminiLiveSession.validateApiKey('');
      expect(error, isNotNull);
      expect(error, contains('empty'));
    });

    test('blank key fails without touching the network', () async {
      final error = await GeminiLiveSession.validateApiKey('   ');
      expect(error, isNotNull);
    });

    test('override seam decides without the network', () async {
      GeminiLiveSession.testValidateOverride = (key) async => null;
      expect(await GeminiLiveSession.validateApiKey('anything'), isNull);

      GeminiLiveSession.testValidateOverride =
          (key) async => 'Gemini API error (400): bad key';
      expect(
        await GeminiLiveSession.validateApiKey('anything'),
        contains('400'),
      );
    });
  });

  group('connect gate (widget)', () {
    Future<void> saveKeyViaDialog(WidgetTester tester, String key) async {
      await tester.pumpWidget(const MaterialApp(home: GeminiLiveScreen()));
      await tester.pump();
      await tester.tap(find.text('Connect'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        key,
      );
      await tester.tap(find.text('Save & Connect'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('rejected key names the failure instead of silence',
        (tester) async {
      GeminiLiveSession.testValidateOverride =
          (key) async => 'Gemini API error (400): API key not valid';
      await saveKeyViaDialog(tester, 'bad-key');

      expect(AppSettingsController.instance.geminiApiKey, 'bad-key');
      expect(find.textContaining('Key Invalid'), findsOneWidget);
      // Both the reply box and the transcription line name the failure.
      expect(find.textContaining('API key check failed'), findsWidgets);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    });

    testWidgets('accepted key opens the socket with the full handshake',
        (tester) async {
      GeminiLiveSession.testValidateOverride = (key) async => null;
      final fake = _FakeTransport();
      await tester.pumpWidget(
        MaterialApp(home: GeminiLiveScreen(transportFactory: () => fake)),
      );
      await tester.pump();
      await tester.tap(find.text('Connect'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'good-key',
      );
      await tester.tap(find.text('Save & Connect'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // The gate validated (override) and opened the socket: exactly one setup
      // frame, carrying the transcription requests the reply path needs.
      final setups = fake.frames
          .map((f) => jsonDecode(f) as Map<String, dynamic>)
          .where((f) => f.containsKey('setup'))
          .toList();
      expect(setups, hasLength(1));
      final setupMap =
          (setups.single['setup'] as Map<String, dynamic>);
      final generationConfig =
          setupMap['generationConfig'] as Map<String, dynamic>;
      expect(generationConfig['responseModalities'], <String>['AUDIO']);
      expect(
        setupMap.containsKey('outputAudioTranscription'),
        isTrue,
      );
      expect(
        generationConfig.containsKey('outputAudioTranscription'),
        isFalse,
      );

      // The handshake completes only on setupComplete — the old code announced
      // 'Live Connected' at socket open, which is what made half-open sessions
      // look connected.
      fake.serverSay!('{"setupComplete":{}}');
      await tester.pump();
      expect(find.textContaining('Live Ready'), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    });
  });
}

/// Records frames instead of opening a socket, and lets the test speak as the
/// server.
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
