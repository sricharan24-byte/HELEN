import 'dart:async';
import 'dart:io';
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
            if (data is String) {
              onMessage(data);
            }
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
}

GeminiLiveTransport createGeminiLiveTransport() => IoGeminiLiveTransport();
