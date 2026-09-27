import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Real OS check on VM targets, constant false on web (see native_platform_io).
import 'native_platform_stub.dart'
    if (dart.library.io) 'native_platform_io.dart';

/// Outcome of a just-in-time microphone permission request.
class NativeMicPermission {
  const NativeMicPermission({required this.granted, this.permanentlyDenied = false});

  /// Marks the no-engine case (non-Android or a build without native audio) so
  /// callers can tell "not available here" apart from "the user said no".
  const NativeMicPermission.unavailable()
      : granted = false,
        permanentlyDenied = false;

  final bool granted;
  final bool permanentlyDenied;
}

/// Native Android audio bridge.
///
/// Owns microphone capture (`AudioRecord`), streamed PCM playback
/// (`AudioTrack`) and device text-to-speech (`TextToSpeech`) behind two
/// channels implemented by `BusBuddyVoiceChannel.kt`:
///  * `busbuddy/voice`     — method calls plus engine → app completion events
///  * `busbuddy/voice/mic` — 16 kHz mono PCM16 microphone chunks (base64)
///
/// Web keeps using the Web Speech APIs (`web_speech_real.dart`); this class is
/// inert there ([isSupported] is false) so the single-voice contract holds.
class NativeAudioChannel {
  NativeAudioChannel({bool Function()? isPlatformSupported})
      : _isPlatformSupported = isPlatformSupported ?? _defaultPlatformSupported;

  static const String methodChannelName = 'busbuddy/voice';
  static const String micChannelName = 'busbuddy/voice/mic';

  // Channels are looked up by name, so tests mock them through
  // `TestDefaultBinaryMessenger` instead of needing injected instances.
  static const MethodChannel _methods = MethodChannel(methodChannelName);
  static const EventChannel _mic = EventChannel(micChannelName);

  final bool Function() _isPlatformSupported;

  final StreamController<String> _nativeEvents = StreamController<String>.broadcast();
  final StreamController<Uint8List> _micChunks = StreamController<Uint8List>.broadcast();
  final StreamController<String> _micErrors = StreamController<String>.broadcast();
  // Cancelled by stopMicrophone(), which is the documented stop call.
  // ignore: cancel_subscriptions
  StreamSubscription<dynamic>? _micSub;
  bool _handlerInstalled = false;
  bool _disposed = false;

  /// True when native audio is wired up on this platform (Android today).
  /// False after [dispose], because the broadcast controllers are closed and a
  /// reused singleton would throw instead of degrading quietly.
  bool get isSupported => !_disposed && _isPlatformSupported();

  static bool _defaultPlatformSupported() => platformHasNativeAudio;

  /// Engine → app signals: `onSpeakDone`, `onPlaybackDrained`.
  Stream<String> get nativeEvents => _nativeEvents.stream;

  /// Capture failures reported by `AudioRecord` (device has no usable input,
  /// permission revoked mid-recording). Subscribers must treat any event as
  /// "microphone is gone" and release the passenger back to text input.
  Stream<String> get microphoneErrors => _micErrors.stream;

  /// Fires once the device TTS engine finishes an utterance.
  Stream<String> get onSpeakDone =>
      _nativeEvents.stream.where((event) => event == 'onSpeakDone');

  /// Fires when streamed model audio has fully played out of the buffer.
  Stream<String> get onPlaybackDrained =>
      _nativeEvents.stream.where((event) => event == 'onPlaybackDrained');

  Future<void> _onNativeCall(MethodCall call) async {
    _nativeEvents.add(call.method);
  }

  /// Installs the native → Dart handler on first real use. Doing it lazily
  /// keeps the process-wide bridge safe to construct in plain unit tests that
  /// never initialise the Flutter binding (no binary messenger yet).
  void _ensureHandler() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _methods.setMethodCallHandler(_onNativeCall);
  }

  Future<bool> _invoke(String method, [Map<String, Object?>? args]) async {
    if (!isSupported) return false;
    _ensureHandler();
    try {
      await _methods.invokeMethod<void>(method, args);
      return true;
    } on PlatformException catch (error) {
      debugPrint('[NativeAudio] $method failed: ${error.message}');
      return false;
    } on MissingPluginException {
      // Unit tests, or a build without the channel registered.
      return false;
    }
  }

  Future<bool> _invokeResult(String method, [Map<String, Object?>? args]) async {
    if (!isSupported) return false;
    _ensureHandler();
    try {
      return await _methods.invokeMethod<bool>(method, args) ?? false;
    } on PlatformException catch (error) {
      debugPrint('[NativeAudio] $method failed: ${error.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// True only when the Android side of the bridge actually answers. This keeps
  /// desktop runs, unit tests, and any build without the plugin registered on
  /// the plain text-only path instead of pretending the mic exists.
  Future<bool> isChannelAvailable() async {
    if (!isSupported) return false;
    _ensureHandler();
    try {
      await _methods.invokeMethod<bool>('hasMicPermission');
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      // The channel exists; the call itself failed. Still "wired up".
      return true;
    }
  }

  // ── Microphone ───────────────────────────────────────────────────────────
  Future<bool> hasMicrophonePermission() => _invokeResult('hasMicPermission');

  /// Shows the system `RECORD_AUDIO` prompt. Callers must announce the purpose
  /// first (BUS-P2-01 just-in-time rule); this never fires unprompted.
  Future<NativeMicPermission> requestMicrophonePermission() async {
    if (!isSupported) return const NativeMicPermission.unavailable();
    _ensureHandler();
    try {
      final reply = await _methods.invokeMethod<Map<dynamic, dynamic>>('requestMicPermission');
      if (reply == null) return const NativeMicPermission.unavailable();
      return NativeMicPermission(
        granted: reply['granted'] == true,
        permanentlyDenied: reply['permanentlyDenied'] == true,
      );
    } on PlatformException {
      return const NativeMicPermission.unavailable();
    } on MissingPluginException {
      return const NativeMicPermission.unavailable();
    }
  }

  /// Opens `AudioRecord` and emits PCM chunks until [stopMicrophone].
  Future<bool> startMicrophone() async {
    if (!isSupported) return false;
    if (_micSub != null) return true;
    _ensureHandler();
    try {
      _micSub = _mic.receiveBroadcastStream().listen(
        (chunk) {
          if (chunk is String) _micChunks.add(base64Decode(chunk));
        },
        // `AudioRecord` reports failures (no usable input, revoked access) as a
        // stream error. Keep the subscription alive but publish the reason so
        // the caller can release the passenger to text input instead of leaving
        // a "Listening..." promise that can never be fulfilled.
        onError: (Object error) {
          final reason = error is PlatformException
              ? (error.message ?? error.code)
              : error.toString();
          debugPrint('[NativeAudio] mic stream error: $error');
          if (!_micErrors.isClosed) _micErrors.add(reason);
        },
      );
      return true;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> stopMicrophone() async {
    final sub = _micSub;
    _micSub = null;
    await sub?.cancel();
  }

  /// Live microphone PCM; subscribe after [startMicrophone] succeeds.
  Stream<Uint8List> get microphone => _micChunks.stream;

  // ── Model audio playback (Gemini Live 24 kHz PCM16) ──────────────────────
  // NOT wired to a reply producer today, on purpose. Chunk 43's single-voice
  // contract makes AudioSpeechEngine.speak (device TTS here) the only speech
  // producer in the app. These calls exist for the day streamed model audio
  // replaces TTS; wiring them alongside speak() would reintroduce two voices.
  Future<bool> startPlayback() => _invoke('startPlayback');

  Future<bool> writePlaybackChunk(String base64Pcm16) =>
      _invoke('writePlayback', <String, Object?>{'pcmBase64': base64Pcm16});

  /// Drops everything queued (barge-in) and reports drained playback.
  Future<bool> stopPlayback() => _invoke('stopPlayback');

  // ── Device text-to-speech ────────────────────────────────────────────────
  /// Queues [text] on the system TTS engine. Returns false when nothing could
  /// be spoken (no engine, blank text, or a platform without native audio).
  Future<bool> speakTts({
    required String text,
    String languageCode = 'en-IN',
    double rate = 1.0,
  }) =>
      _invokeResult('speakTts', <String, Object?>{
        'text': text,
        'languageCode': languageCode,
        'rate': rate,
      });

  Future<bool> stopTts() => _invoke('stopTts');

  /// Ready/acknowledgment chime, synthesized natively (no asset needed).
  Future<bool> playTone({bool isListening = false}) =>
      _invoke('playTone', <String, Object?>{'isListening': isListening});

  Future<void> dispose() async {
    await stopMicrophone();
    await _invoke('dispose');
    if (_handlerInstalled) {
      _handlerInstalled = false;
      _methods.setMethodCallHandler(null);
    }
    // Marks the process-wide singleton as spent only after the native teardown
    // call above has gone out: isSupported() reports false from here on, so a
    // later startMicrophone() degrades quietly instead of adding to a closed
    // broadcast controller.
    _disposed = true;
    if (!_nativeEvents.isClosed) await _nativeEvents.close();
    if (!_micChunks.isClosed) await _micChunks.close();
    if (!_micErrors.isClosed) await _micErrors.close();
  }
}

