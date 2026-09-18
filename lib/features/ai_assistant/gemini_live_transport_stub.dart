abstract class GeminiLiveTransport {
  void connect(
    String url, {
    required void Function() onOpen,
    required void Function(String message) onMessage,
    required void Function(dynamic error) onError,
    required void Function(int? code, String? reason) onClose,
  });
  void send(String data);
  void close();
  bool get isConnected;
}

GeminiLiveTransport createGeminiLiveTransport() =>
    throw UnsupportedError('Cannot create GeminiLiveTransport on this platform.');
