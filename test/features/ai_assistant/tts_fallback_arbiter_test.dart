import 'package:busbuddy/features/ai_assistant/tts_fallback_arbiter.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TtsFallbackArbiter single-voice arbitration', () {
    test('speaks after grace elapses when no PCM arrives', () {
      fakeAsync((async) {
        final arbiter = TtsFallbackArbiter();
        var speaks = 0;
        arbiter.scheduleFallback(() => speaks++);
        async.elapse(const Duration(milliseconds: 599));
        expect(speaks, 0);
        async.elapse(const Duration(milliseconds: 1));
        expect(speaks, 1);
        expect(arbiter.hasPendingTts, isFalse);
      });
    });

    test('PCM arriving during grace suppresses the pending TTS', () {
      fakeAsync((async) {
        final arbiter = TtsFallbackArbiter();
        var speaks = 0;
        arbiter.scheduleFallback(() => speaks++);
        async.elapse(const Duration(milliseconds: 200));
        arbiter.notifyPcmReceived();
        async.elapse(const Duration(seconds: 5));
        expect(speaks, 0);
        expect(arbiter.hasPendingTts, isFalse);
      });
    });

    test('PCM received before scheduling suppresses TTS entirely', () {
      fakeAsync((async) {
        final arbiter = TtsFallbackArbiter();
        var speaks = 0;
        arbiter.notifyPcmReceived();
        arbiter.scheduleFallback(() => speaks++);
        async.elapse(const Duration(seconds: 5));
        expect(speaks, 0);
      });
    });

    test('beginTurn clears PCM state so the next turn can speak', () {
      fakeAsync((async) {
        final arbiter = TtsFallbackArbiter();
        var speaks = 0;
        arbiter.notifyPcmReceived();
        arbiter.beginTurn();
        arbiter.scheduleFallback(() => speaks++);
        async.elapse(const Duration(milliseconds: 600));
        expect(speaks, 1);
      });
    });

    test('cancel drops pending TTS without marking PCM received', () {
      fakeAsync((async) {
        final arbiter = TtsFallbackArbiter();
        var speaks = 0;
        arbiter.scheduleFallback(() => speaks++);
        arbiter.cancel();
        async.elapse(const Duration(seconds: 5));
        expect(speaks, 0);
        // PCM flag untouched: a later schedule still fires after grace.
        arbiter.scheduleFallback(() => speaks++);
        async.elapse(const Duration(milliseconds: 600));
        expect(speaks, 1);
      });
    });

    test('speakNow bypasses the grace window', () {
      fakeAsync((async) {
        final arbiter = TtsFallbackArbiter();
        var speaks = 0;
        arbiter.speakNow(() => speaks++);
        expect(speaks, 1);
        async.elapse(const Duration(seconds: 5));
        expect(speaks, 1);
      });
    });
  });
}
