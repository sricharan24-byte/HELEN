import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/features/ai_assistant/gemini_live_session.dart';
import 'package:busbuddy/features/ai_assistant/gemini_live_transport_stub.dart';

/// Pins the setup handshake to the fields the reply path depends on.
///
/// Regression (2026-10-06): the handshake requested `responseModalities:
/// ['AUDIO']` but never asked for `outputAudioTranscription`, so the Live
/// service sent audio with no text. `_currentTurnText` stayed empty, the
/// on-screen transcript never updated, and — because the web PCM decoder was
/// also broken and the turn fell through to the TTS fallback — the fallback
/// had nothing to speak and substituted a generic filler line. The passenger's
/// actual answer was never spoken.
///
/// `inputAudioTranscription` is asserted for the same reason on the Android
/// audio-in path: without it `inputTranscription` never arrives, so the
/// "I heard you say" line is dead code.
///
/// The handshake is private, so it is exercised the way production does:
/// through `connect` against a real loopback WebSocket server that captures
/// the first frame.
void main() {
  group('GeminiLiveSession setup handshake', () {
    /// Connects through a recording transport and returns the setup frame.
    Future<Map<String, dynamic>> captureSetupFrame() async {
      final recorder = _RecordingTransport();
      final live = GeminiLiveSession(
        transportFactory: () => recorder,
      );
      addTearDown(live.dispose);

      live.connect(customApiKey: 'test-key-not-real');
      // connect() completes `connected` synchronously via onOpen(); awaiting a
      // Completer as if it were a Future would never yield the recorded frame.
      if (!recorder.connected.isCompleted) {
        await recorder.connected.future;
      }
      final sent = recorder.frames
          .map((f) => jsonDecode(f) as Map<String, dynamic>)
          .firstWhere((f) => f.containsKey('setup'));
      return sent;
    }

    test('requests outputAudioTranscription so the reply has text', () async {
      final setup = await captureSetupFrame();
      final setupMap = setup['setup'] as Map<String, dynamic>;
      final generationConfig =
          setupMap['generationConfig'] as Map<String, dynamic>;

      expect(
        generationConfig.containsKey('outputAudioTranscription'),
        isFalse,
        reason:
            'outputAudioTranscription must NOT be inside generationConfig. '
            'Google Live API rejects the setup frame and closes the socket if unknown fields are present in generationConfig.',
      );
      expect(
        setupMap.containsKey('outputAudioTranscription'),
        isTrue,
        reason:
            'BidiGenerateContentSetup proto field 11 expects outputAudioTranscription at the top level of setup.',
      );
      // An empty object is what requests it; a truthy non-empty value would be
      // sent to the server as configuration it does not understand.
      expect(setupMap['outputAudioTranscription'], isEmpty);
    });

    test('requests inputAudioTranscription for the Android audio-in path',
        () async {
      final setup = await captureSetupFrame();
      final setupMap = setup['setup'] as Map<String, dynamic>;
      final generationConfig =
          setupMap['generationConfig'] as Map<String, dynamic>;

      expect(
        generationConfig.containsKey('inputAudioTranscription'),
        isFalse,
        reason:
            'inputAudioTranscription must NOT be inside generationConfig. '
            'Google Live API rejects the setup frame and closes the socket if unknown fields are present in generationConfig.',
      );
      expect(
        setupMap.containsKey('inputAudioTranscription'),
        isTrue,
        reason:
            'BidiGenerateContentSetup proto field 10 expects inputAudioTranscription at the top level of setup.',
      );
      expect(setupMap['inputAudioTranscription'], isEmpty);
    });

    test('still requests AUDIO and a prebuilt voice', () async {
      final setup = await captureSetupFrame();
      final generationConfig =
          (setup['setup'] as Map<String, dynamic>)['generationConfig']
              as Map<String, dynamic>;

      // The transcription requests must not cost us the model's own voice.
      expect(generationConfig['responseModalities'], <String>['AUDIO']);
      final speechConfig = generationConfig['speechConfig'] as Map<String, dynamic>;
      final voiceConfig =
          (speechConfig['voiceConfig'] as Map<String, dynamic>);
      final prebuilt = voiceConfig['prebuiltVoiceConfig'] as Map<String, dynamic>;
      expect(prebuilt['voiceName'], isA<String>());
      expect(prebuilt['voiceName'] as String, isNotEmpty);
    });
  });
}

/// A transport that records every frame instead of opening a socket.
class _RecordingTransport implements GeminiLiveTransport {
  final frames = <String>[];
  final connected = Completer<void>();

  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  void connect(
    String url, {
    required void Function() onOpen,
    required void Function(String message) onMessage,
    required void Function(Object error) onError,
    required void Function(int? code, String? reason) onClose,
  }) {
    _connected = true;
    if (!connected.isCompleted) connected.complete();
    onOpen();
  }

  @override
  void send(String data) => frames.add(data);

  @override
  void close() => _connected = false;
}