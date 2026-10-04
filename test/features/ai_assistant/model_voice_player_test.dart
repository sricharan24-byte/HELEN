import 'package:busbuddy/features/ai_assistant/native_audio_channel.dart';
import 'package:busbuddy/features/ai_assistant/model_voice_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the native playback calls the player makes, and lets a test push the
/// engine's `onPlaybackDrained` notification back up to Dart.
class FakeNativePlayback {
  FakeNativePlayback() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(NativeAudioChannel.methodChannelName),
      (call) async {
        calls.add(call.method);
        if (call.method == 'writePlayback') {
          chunks.add((call.arguments as Map)['pcmBase64'] as String);
        }
        return true;
      },
    );
  }

  final calls = <String>[];
  final chunks = <String>[];

  /// Simulates the native AudioTrack finishing its buffer.
  Future<void> emitDrained() async {
    await TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .handlePlatformMessage(
      NativeAudioChannel.methodChannelName,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('onPlaybackDrained'),
      ),
      (_) {},
    );
  }

  void dispose() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(NativeAudioChannel.methodChannelName),
      null,
    );
  }
}

/// Builds a player with the native-audio platform seam open: `Platform.isAndroid`
/// is false while tests run on the Linux VM, so both the channel and the player
/// need telling that the `AudioTrack` bridge exists.
ModelVoicePlayer _androidPlayer({bool supported = true}) => ModelVoicePlayer(
      channel: NativeAudioChannel(isPlatformSupported: () => true),
      isSupported: () => supported,
    );

void main() {
  // Needed for TestDefaultBinaryMessengerBinding (method-channel mocking).
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeNativePlayback native;

  setUp(() => native = FakeNativePlayback());
  tearDown(() => native.dispose());

  group('ModelVoicePlayer — Gemini\'s own voice on the native AudioTrack', () {
    test('the first chunk opens playback and every chunk is written', () async {
      final player = _androidPlayer();
      expect(player.isSupported, isTrue);
      expect(player.isPlaying, isFalse);

      await player.addChunk('AAAA');
      expect(native.calls, ['startPlayback', 'writePlayback']);

      await player.addChunk('BBBB');
      // Playback is opened once per turn, not per chunk.
      expect(native.calls.where((c) => c == 'startPlayback').length, 1);
      expect(native.chunks, ['AAAA', 'BBBB']);
      expect(player.isPlaying, isTrue);

      await player.dispose();
    });

    test('the turn is marked as model-audio so TTS can be skipped', () async {
      final player = _androidPlayer();
      expect(player.hasModelAudioThisTurn, isFalse);

      await player.addChunk('AAAA');
      expect(player.hasModelAudioThisTurn, isTrue);

      // A new turn clears it, so a text-only turn still falls back to TTS.
      player.beginTurn();
      expect(player.hasModelAudioThisTurn, isFalse);

      await player.dispose();
    });

    test('a turn with no audio never touches the AudioTrack', () async {
      final player = _androidPlayer();
      player.beginTurn();
      expect(player.hasModelAudioThisTurn, isFalse);
      expect(native.calls, isEmpty);
      await player.dispose();
    });

    test('an unsupported platform leaves audio to the TTS fallback', () async {
      // Web: isSupported() is false, so nothing opens playback and the caller
      // keeps speaking through AudioSpeechEngine.
      final player = _androidPlayer(supported: false);
      await player.addChunk('AAAA');
      expect(native.calls, isEmpty);
      expect(player.hasModelAudioThisTurn, isFalse);
      await player.stop();
      expect(native.calls, isEmpty);
      await player.dispose();
    });

    test('empty chunks are ignored', () async {
      final player = _androidPlayer();
      await player.addChunk('');
      expect(native.calls, isEmpty);
      expect(player.hasModelAudioThisTurn, isFalse);
      await player.dispose();
    });

    test('the drain notification ends the turn', () async {
      final player = _androidPlayer();
      var drained = 0;
      player.onDrained.listen((_) => drained++);

      await player.addChunk('AAAA');
      expect(player.isPlaying, isTrue);

      await native.emitDrained();
      await Future<void>.delayed(Duration.zero);

      expect(drained, 1);
      expect(player.isPlaying, isFalse);
      await player.dispose();
    });

    test('stop() drops queued audio (barge-in) and is idempotent', () async {
      final player = _androidPlayer();
      await player.addChunk('AAAA');

      await player.stop();
      expect(native.calls.last, 'stopPlayback');
      expect(player.isPlaying, isFalse);

      // Nothing is playing, so a second stop must not re-enter the bridge.
      await player.stop();
      expect(native.calls.where((c) => c == 'stopPlayback').length, 1);
      await player.dispose();
    });

    test('dispose stops playback so the AudioTrack cannot outlive the screen',
        () async {
      final player = _androidPlayer();
      await player.addChunk('AAAA');
      await player.dispose();
      expect(native.calls.last, 'stopPlayback');
    });

    test('stop() before any audio does not open the bridge', () async {
      final player = _androidPlayer();
      await player.stop();
      expect(native.calls, isEmpty);
      await player.dispose();
    });
  });
}
