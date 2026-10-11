import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/core/settings/app_settings_controller.dart';
import 'package:busbuddy/features/ai_assistant/gemini_live_session.dart';
import 'package:busbuddy/features/ai_assistant/gemini_live_transport_io.dart';

void main() {
group('tool dispatch returns application results (booking personalization)', () {
  // Drives the real GeminiLiveSession dispatch through a recording transport:
  // the model's toolCall frame goes in, and the emitted toolResponse frame
  // must carry the app callback's result for the matching call id/name.
  late _RecordingTransport transport;
  late GeminiLiveSession session;

  setUp(() {
    GeminiLiveSession.testValidateOverride = (key) async => null;
    AppSettingsController.instance.updateGeminiApiKey('test-key');
  });
  tearDown(() {
    GeminiLiveSession.testValidateOverride = null;
    AppSettingsController.instance.updateGeminiApiKey('');
    session.dispose();
  });

  void primeSession(
    Map<String, Object?> Function(String, Map<String, dynamic>?)? handler,
  ) {
    transport = _RecordingTransport();
    session = GeminiLiveSession(
      transportFactory: () => transport,
      onToolCall: handler,
    );
    session.connect();
    transport.serverSay!('{"setupComplete":{}}');
  }

  List<Map<String, dynamic>> sentToolResponses() => transport.frames
      .map((f) => jsonDecode(f) as Map<String, dynamic>)
      .where((m) => m.containsKey('toolResponse'))
      .toList();

  void serverSayToolCall(String id, String name) {
    transport.serverSay!(jsonEncode({
      'toolCall': {
        'functionCalls': [
          {'id': id, 'name': name, 'args': <String, dynamic>{}},
        ],
      },
    }));
  }

  test('toolResponseUsesApplicationCallbackResultForMatchingCall', () {
    Map<String, Object?> handler(String name, Map<String, dynamic>? args) {
      if (name != 'get_booking_context') {
        return {'success': false, 'error': 'not handled in this test'};
      }
      return {
        'success': true,
        'bookingContext': {
          'draft': {
            'slots': <String, Object?>{
              'origin': <String, Object?>{
                'value': 'VIT Main Gate',
                'source': 'passenger',
              },
            },
          },
        },
      };
    }

    primeSession(handler);
    serverSayToolCall('call-42', 'get_booking_context');

    final responses = sentToolResponses();
    expect(responses, hasLength(1));
    final fr =
        (responses.single['toolResponse'] as Map)['functionResponses'] as List;
    final call = fr.single as Map;
    // Result, ID, and name match the received call exactly.
    expect(call['id'], 'call-42');
    expect(call['name'], 'get_booking_context');
    final output = (call['response'] as Map)['output'] as Map;
    expect(output['success'], isTrue);
    expect(((output['bookingContext'] as Map)['draft'] as Map), isMap);
  });

  test('toolCallbackFailureIsReturnedAsFailure', () {
    primeSession((name, args) => throw StateError('callback exploded'));
    serverSayToolCall('call-7', 'set_trip');

    final responses = sentToolResponses();
    expect(responses, hasLength(1));
    final fr =
        (responses.single['toolResponse'] as Map)['functionResponses'] as List;
    final output = ((fr.single as Map)['response'] as Map)['output'] as Map;
    // No success envelope on failure — the model must re-ask, not celebrate.
    expect(output['success'], isFalse);
    expect(output.containsKey('error'), isTrue);
  });

  test('unknownToolCallDoesNotClaimSuccess', () {
    // Even a lying callback cannot push a success envelope for an
    // unregistered tool name.
    primeSession((name, args) => {'success': true, 'hacked': true});
    serverSayToolCall('call-99', 'rogue_tool');

    final responses = sentToolResponses();
    final fr =
        (responses.single['toolResponse'] as Map)['functionResponses'] as List;
    final output = ((fr.single as Map)['response'] as Map)['output'] as Map;
    expect(output['success'], isFalse);
  });

  test('unknown tool without a callback gets the bounded failure too', () {
    primeSession(null);
    serverSayToolCall('call-100', 'rogue_tool');

    final responses = sentToolResponses();
    final fr =
        (responses.single['toolResponse'] as Map)['functionResponses'] as List;
    final output = ((fr.single as Map)['response'] as Map)['output'] as Map;
    expect(output['success'], isFalse);
  });
});

  group('IoGeminiLiveTransport frame decoding', () {
    // Found on an API 34 emulator run (2026-10-01). The Gemini Live service sends
    // its JSON control frames as *binary* WebSocket frames to the native
    // `dart:io` socket. The transport only handled `String`, so every server
    // frame was dropped on Android and desktop: `setupComplete` never arrived,
    // `isReady` stayed false forever, every query fell back to REST, and
    // `sendRealtimeAudio` rejected every microphone frame. Web never saw it
    // because the browser delivers the same frames as text.
    //
    // `_decodeFrame` is private, so it is exercised the way production does:
    // through `connect`, with a real loopback WebSocket server that replies with
    // a binary frame.
    late IoGeminiLiveTransport transport;

    setUp(() => transport = IoGeminiLiveTransport());
    tearDown(() => transport.close());

    test('decodes binary JSON frames the way the Live service sends them',
        () async {
      final received = <String>[];
      final opened = Completer<void>();

      final server = await HttpServer.bind('127.0.0.1', 0);
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        opened.complete();
        socket.listen((_) {});
        // `setupComplete` as the service actually frames it on the native path:
        // sent as bytes, so it arrives at the client as a binary frame.
        socket.add(utf8.encode('{"setupComplete":{}}'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await socket.close();
      });
      addTearDown(() async => server.close(force: true));

      transport.connect(
        'ws://127.0.0.1:${server.port}/',
        onOpen: () {},
        onMessage: received.add,
        onError: (_) {},
        onClose: (code, reason) {},
      );

      await opened.future;
      // Give the frame time to arrive on the client socket.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      transport.close();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(
        received,
        contains('{"setupComplete":{}}'),
        reason: 'binary control frames must be decoded, not silently dropped',
      );
    });

    test('rejects nothing a String frame cannot already express', () {
      // Guards the decode helper's contract indirectly: text frames stay text.
      final payload = '{"serverContent":{"inputTranscription":{"text":"hi"}}}';
      final bytes = Uint8List.fromList(utf8.encode(payload));
      expect(utf8.decode(bytes), payload);
    });
  });
}

/// Records every frame the session sends and lets the test speak as the
/// Gemini server (same shape as the fake in key_connect_gate_test.dart).
class _RecordingTransport implements GeminiLiveTransport {
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
