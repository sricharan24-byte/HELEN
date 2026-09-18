// ignore_for_file: deprecated_member_use
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'gemini_live_transport_stub.dart';
export 'gemini_live_transport_stub.dart';

class WebGeminiLiveTransport implements GeminiLiveTransport {
  html.WebSocket? _socket;
  bool _connected = false;

  @override
  bool get isConnected =>
      _connected && _socket != null && _socket!.readyState == html.WebSocket.OPEN;

  @override
  void connect(
    String url, {
    required void Function() onOpen,
    required void Function(String message) onMessage,
    required void Function(dynamic error) onError,
    required void Function(int? code, String? reason) onClose,
  }) {
    try {
      close();
      final socket = html.WebSocket(url);
      _socket = socket;

      socket.onOpen.listen((_) {
        _connected = true;
        onOpen();
      });

      socket.onMessage.listen((event) {
        final data = event.data;
        if (data is String) {
          onMessage(data);
        } else if (data is html.Blob) {
          final reader = html.FileReader();
          reader.onLoadEnd.listen((_) {
            if (reader.result is String) {
              onMessage(reader.result as String);
            }
          });
          reader.readAsText(data);
        }
      });

      socket.onError.listen((event) {
        _connected = false;
        onError(event);
      });

      socket.onClose.listen((event) {
        _connected = false;
        onClose(event.code, event.reason);
      });
    } catch (e) {
      _connected = false;
      onError(e);
    }
  }

  @override
  void send(String data) {
    if (isConnected) {
      _socket?.sendString(data);
    }
  }

  @override
  void close() {
    _connected = false;
    try {
      _socket?.close();
    } catch (_) {}
    _socket = null;
  }
}

GeminiLiveTransport createGeminiLiveTransport() => WebGeminiLiveTransport();
