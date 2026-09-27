import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/features/ai_assistant/android_voice_turn.dart';

/// Fake microphone + session pair standing in for `BusBuddyVoiceChannel` and
/// `GeminiLiveSession`, so the turn state machine is testable without a device.
// ignore_for_file: close_sinks
class _FakeAudio {
  final StreamController<Uint8List> pcm = StreamController<Uint8List>.broadcast();
  final StreamController<String> errors = StreamController<String>.broadcast();

  /// Non-null means the microphone refuses to open, with this passenger text.
  String? openFailure;

  int openCalls = 0;
  int closeCalls = 0;
  bool sessionAcceptsAudio = true;
  final List<String> sent = <String>[];
  final List<String> lostReasons = <String>[];

  /// True when the loss was a microphone problem (permission/device), false
  /// when the live session was the one that could not take the audio.
  final List<bool> lostAsMicProblem = <bool>[];

  AndroidVoiceTurn buildTurn() => AndroidVoiceTurn(
        openMicrophone: () async {
          openCalls++;
          return openFailure;
        },
        closeMicrophone: () async {
          closeCalls++;
        },
        microphonePcm: () => pcm.stream,
        microphoneErrors: () => errors.stream,
        sendAudio: (base64Pcm) {
          if (!sessionAcceptsAudio) return false;
          sent.add(base64Pcm);
          return true;
        },
        onTurnLost: (reason, microphoneUnavailable) {
          lostReasons.add(reason);
          lostAsMicProblem.add(microphoneUnavailable);
        },
      );

  void emit(List<int> bytes) => pcm.add(Uint8List.fromList(bytes));

  Future<void> pump() => Future<void>.delayed(Duration.zero);
}

void main() {
  group('AndroidVoiceTurn', () {
    test('streams microphone PCM to the session as base64 once open', () async {
      final audio = _FakeAudio();
      final turn = audio.buildTurn();

      expect(await turn.start(), isTrue);
      expect(turn.isActive, isTrue);

      audio.emit(<int>[1, 2, 3, 4]);
      await audio.pump();

      expect(audio.sent, <String>[base64Encode(<int>[1, 2, 3, 4])]);
      await turn.stop();
    });

    test('a refusal to open the mic releases the passenger with one reason', () async {
      final audio = _FakeAudio()..openFailure = 'Microphone permission was not granted.';
      final turn = audio.buildTurn();

      expect(await turn.start(), isFalse);
      await audio.pump();

      expect(turn.isActive, isFalse);
      expect(audio.lostReasons, <String>['Microphone permission was not granted.']);
      expect(audio.lostAsMicProblem, <bool>[true]);
      expect(audio.closeCalls, greaterThan(0), reason: 'capture handle must be released');
    });

    test('frames are withheld while the assistant speaks and flow again on resume', () async {
      final audio = _FakeAudio();
      final turn = audio.buildTurn();
      await turn.start();

      turn.pause();
      expect(turn.isPaused, isTrue);
      audio.emit(<int>[9]);
      await audio.pump();
      expect(audio.sent, isEmpty, reason: 'own TTS must never be fed back as a question');

      turn.resume();
      audio.emit(<int>[7]);
      await audio.pump();
      expect(audio.sent, <String>[base64Encode(<int>[7])]);
      await turn.stop();
    });

    test('empty chunks are never sent', () async {
      final audio = _FakeAudio();
      final turn = audio.buildTurn();
      await turn.start();

      audio.emit(<int>[]);
      await audio.pump();

      expect(audio.sent, isEmpty);
      await turn.stop();
    });

    test('a session that cannot accept audio ends the turn once', () async {
      final audio = _FakeAudio()..sessionAcceptsAudio = false;
      final turn = audio.buildTurn();
      await turn.start();

      audio.emit(<int>[5, 6]);
      await audio.pump();
      audio.emit(<int>[7, 8]);
      await audio.pump();

      expect(audio.lostReasons, hasLength(1));
      expect(audio.lostReasons.single, contains('type your question'));
      expect(audio.lostAsMicProblem, <bool>[false],
          reason: 'a socket that is not ready must not raise a mic warning');
      expect(turn.isActive, isFalse);
    });

    test('a native capture failure mid-turn ends the turn once', () async {
      final audio = _FakeAudio();
      final turn = audio.buildTurn();
      await turn.start();

      audio.errors.add('The microphone could not be opened on this device');
      audio.errors.add('The microphone could not be opened on this device');
      await audio.pump();

      expect(audio.lostReasons, hasLength(1));
      expect(audio.lostAsMicProblem, <bool>[true]);
      expect(turn.isActive, isFalse);
      expect(audio.closeCalls, greaterThan(0));
    });

    test('stop is idempotent and ignores chunks that arrive late', () async {
      final audio = _FakeAudio();
      final turn = audio.buildTurn();
      await turn.start();
      await turn.stop();
      await turn.stop();

      audio.emit(<int>[1]);
      await audio.pump();

      expect(audio.sent, isEmpty);
      expect(turn.isActive, isFalse);
    });

    test('starting twice opens the microphone once', () async {
      final audio = _FakeAudio();
      final turn = audio.buildTurn();

      final first = turn.start();
      final second = turn.start();
      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(audio.openCalls, 1);

      await turn.stop();
      expect(await turn.start(), isTrue);
      expect(audio.openCalls, 2, reason: 'a stopped turn can be reopened');
      await turn.stop();
    });
  });
}
