import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'gemini_live_transport_stub.dart';
export 'gemini_live_transport_stub.dart';

class IoGeminiLiveTransport implements GeminiLiveTransport {
  WebSocket? _socket;
  bool _connected = false;

  @override
  bool get isConnected =>
      _connected && _socket != null && _socket!.readyState == WebSocket.open;

  @override
  void connect(
    String url, {
    required void Function() onOpen,
    required void Function(String message) onMessage,
    required void Function(Object error) onError,
    required void Function(int? code, String? reason) onClose,
  }) {
    close();
    unawaited(
      WebSocket.connect(url).then((socket) {
        _socket = socket;
        _connected = true;
        onOpen();

        socket.listen(
          (data) {
            final text = _decodeFrame(data);
            if (text != null) onMessage(text);
          },
          onError: (Object err) {
            _connected = false;
            onError(err);
          },
          onDone: () {
            _connected = false;
            onClose(socket.closeCode, socket.closeReason);
          },
        );
      }).catchError((Object err) {
        _connected = false;
        onError(err);
      }),
    );
  }

  @override
  void send(String data) {
    if (isConnected) {
      _socket?.add(data);
    } else {
      // Dropped rather than queued: the session treats a dropped frame as a dead
      // socket, and queueing stale audio after a reconnect would replay the
      // previous question into the new turn.
      debugPrint(
        '[LiveTransport] dropped outgoing frame (${data.length} bytes): socket not open',
      );
    }
  }

  @override
  void close() {
    _connected = false;
    try {
      unawaited(_socket?.close());
    } catch (_) {}
    _socket = null;
  }

  /// Normalises one inbound WebSocket frame to the JSON text the session parses.
  ///
  /// The Gemini Live service does **not** frame consistently: the browser
  /// (`WebGeminiLiveTransport`) receives text frames as `String`, but the native
  /// `dart:io` socket receives the very same JSON control frames as **binary**
  /// (`Uint8List`). Handling only `String` therefore silently discarded
  /// everything the server said on Android and desktop — including
  /// `setupComplete`, which left `_isSetupDone` false forever, made
  /// `GeminiLiveSession.isReady` permanently false, forced every query down the
  /// REST fallback, and made `sendRealtimeAudio` reject every microphone frame.
  /// Found on an API 34 emulator run (2026-10-01), where the screen reported
  /// "Live Connected" while the handshake could never complete.
  ///
  /// Unrecognised frames return null rather than being dropped in silence, so a
  /// future framing change surfaces as a log line instead of a dead session.
  static String? _decodeFrame(Object? data) {
    if (data is String) return data;
    if (data is List<int>) {
      try {
        return utf8.decode(data);
      } on FormatException catch (e) {
        debugPrint('[LiveTransport] undecodable binary frame '
            '(${data.length} bytes): $e');
        return null;
      }
    }
    debugPrint('[LiveTransport] unsupported frame type ${data.runtimeType}');
    return null;
  }
}

GeminiLiveTransport createGeminiLiveTransport() => IoGeminiLiveTransport();


