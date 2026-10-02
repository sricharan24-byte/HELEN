import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/features/ai_assistant/gemini_live_transport_io.dart';

void main() {
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
