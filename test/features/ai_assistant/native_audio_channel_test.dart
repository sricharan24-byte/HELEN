import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/features/ai_assistant/audio_speech_engine.dart';
import 'package:busbuddy/features/ai_assistant/native_audio_channel.dart';

const _codec = StandardMethodCodec();

/// Pushes a native → Dart signal (`onSpeakDone`, `onPlaybackDrained`) through
/// the real method-call handler the bridge installs on `busbuddy/voice`.
Future<void> _emitNativeSignal(String method) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    NativeAudioChannel.methodChannelName,
    _codec.encodeMethodCall(MethodCall(method)),
    (_) {},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(
      const MethodChannel(NativeAudioChannel.methodChannelName),
      null,
    );
  });

  group('NativeAudioChannel without the Android plugin', () {
    // Desktop runs and unit tests: the channel exists on the Dart side only.
    test('every call degrades instead of throwing', () async {
      final channel = NativeAudioChannel(isPlatformSupported: () => true);

      expect(await channel.isChannelAvailable(), isFalse);
      expect(await channel.hasMicrophonePermission(), isFalse);
      expect(await channel.speakTts(text: 'Turn left at the next stop'), isFalse);
      expect(await channel.playTone(isListening: true), isFalse);
      expect(await channel.startPlayback(), isFalse);
      expect(await channel.writePlaybackChunk('AAA='), isFalse);
      expect(await channel.stopPlayback(), isFalse);

      final permission = await channel.requestMicrophonePermission();
      expect(permission.granted, isFalse);
      expect(permission.permanentlyDenied, isFalse);
    });

    test('blank text never reaches the engine', () async {
      final channel = NativeAudioChannel(isPlatformSupported: () => true);
      expect(await channel.speakTts(text: '   '), isFalse);
    });

    test('unsupported platforms short-circuit before touching channels', () async {
      final channel = NativeAudioChannel(isPlatformSupported: () => false);
      expect(channel.isSupported, isFalse);
      expect(await channel.isChannelAvailable(), isFalse);
      expect(await channel.startMicrophone(), isFalse);
      expect(await channel.speakTts(text: 'Hello'), isFalse);
    });

    test('native onSpeakDone signal reaches listeners', () async {
      final channel = NativeAudioChannel(isPlatformSupported: () => true);
      final heard = Completer<String>();
      channel.onSpeakDone.listen(heard.complete);

      // Installing the handler is a side effect of the first real call.
      await channel.speakTts(text: 'Board route 12 from Bagayam');
      await _emitNativeSignal('onSpeakDone');

      expect(
        await heard.future.timeout(const Duration(seconds: 1)),
        'onSpeakDone',
      );
    });
  });


  group('NativeAudioChannel with a mocked Android platform', () {
    final calls = <MethodCall>[];

    void mock(Object? Function(MethodCall call) reply) {
      messenger.setMockMethodCallHandler(
        const MethodChannel(NativeAudioChannel.methodChannelName),
        (call) async {
          calls.add(call);
          return reply(call);
        },
      );
    }

    setUp(calls.clear);

    test('speakTts forwards text, language and rate', () async {
      mock((_) => true);
      final channel = NativeAudioChannel(isPlatformSupported: () => true);

      expect(
        await channel.speakTts(
          text: 'Miss the 8:15',
          languageCode: 'ta-IN',
          rate: 1.4,
        ),
        isTrue,
      );

      expect(calls.single.method, 'speakTts');
      expect(calls.single.arguments['text'], 'Miss the 8:15');
      expect(calls.single.arguments['languageCode'], 'ta-IN');
      expect(calls.single.arguments['rate'], 1.4);
    });

    test('playback calls travel as expected', () async {
      mock((_) => true);
      final channel = NativeAudioChannel(isPlatformSupported: () => true);

      await channel.startPlayback();
      await channel.writePlaybackChunk(base64Encode(const [0, 1, 2, 3]));
      await channel.stopPlayback();
      await channel.playTone(isListening: true);

      expect(calls.map((call) => call.method), [
        'startPlayback',
        'writePlayback',
        'stopPlayback',
        'playTone',
      ]);
      expect(calls[1].arguments['pcmBase64'], base64Encode(const [0, 1, 2, 3]));
      expect(calls[3].arguments['isListening'], isTrue);
    });

    test('permission result maps granted and permanentlyDenied', () async {
      mock((call) => switch (call.method) {
            'hasMicPermission' => false,
            'requestMicPermission' => {
                'granted': false,
                'permanentlyDenied': true,
              },
            _ => null,
          });
      final channel = NativeAudioChannel(isPlatformSupported: () => true);

      expect(await channel.hasMicrophonePermission(), isFalse);
      final permission = await channel.requestMicrophonePermission();
      expect(permission.granted, isFalse);
      expect(permission.permanentlyDenied, isTrue);
    });

    test('engine routes replies to native TTS and resumes on onSpeakDone', () async {
      mock((call) => call.method == 'speakTts');
      final engine = AudioSpeechEngine(
        nativeAudio: NativeAudioChannel(isPlatformSupported: () => true),
      );
      addTearDown(engine.dispose);

      var endedCalls = 0;
      engine.setAudioEndedCallback(() => endedCalls++);
      engine.speak('Leave Bagayam at 8:10 and you will make the connection.');

      await Future<void>.delayed(Duration.zero);
      expect(calls.map((call) => call.method), contains('speakTts'));

      await _emitNativeSignal('onSpeakDone');
      expect(endedCalls, 1);

      // A stray second signal must not restart listening twice.
      await _emitNativeSignal('onSpeakDone');
      expect(endedCalls, 1);
    });
  });
}
