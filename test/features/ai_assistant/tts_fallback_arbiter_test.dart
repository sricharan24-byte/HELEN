import 'package:busbuddy/domain/assistant/assistant_command.dart';
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

    test('Live grace holds TTS for late PCM (doubling fix)', () {
      fakeAsync((async) {
        final arbiter = TtsFallbackArbiter();
        var speaks = 0;
        // Offline grace would have fired at 600ms; Live holds to 1800ms.
        arbiter.scheduleFallback(() => speaks++, isLive: true);
        async.elapse(const Duration(milliseconds: 800));
        expect(speaks, 0);
        arbiter.notifyPcmReceived();
        async.elapse(const Duration(seconds: 5));
        expect(speaks, 0);
      });
    });

    test('Live fallback still speaks when no PCM ever arrives', () {
      fakeAsync((async) {
        final arbiter = TtsFallbackArbiter();
        var speaks = 0;
        arbiter.scheduleFallback(() => speaks++, isLive: true);
        async.elapse(const Duration(milliseconds: 1799));
        expect(speaks, 0);
        async.elapse(const Duration(milliseconds: 1));
        expect(speaks, 1);
      });
    });

    test('stale generation never speaks over the current turn', () {
      fakeAsync((async) {
        final arbiter = TtsFallbackArbiter();
        var speaks = 0;
        arbiter.scheduleFallback(() => speaks++);
        // New query starts before grace elapses: old callback is stale.
        arbiter.beginTurn();
        arbiter.scheduleFallback(() => speaks++);
        async.elapse(const Duration(milliseconds: 600));
        // Only the current turn speaks, exactly once.
        expect(speaks, 1);
      });
    });

    test('first-starter-wins: late PCM dropped after TTS starts', () {
      fakeAsync((async) {
        final arbiter = TtsFallbackArbiter();
        var speaks = 0;
        arbiter.scheduleFallback(() => speaks++);
        async.elapse(const Duration(milliseconds: 600));
        expect(speaks, 1);
        expect(arbiter.ttsStarted, isTrue);
        // Late PCM must NOT play over the started TTS voice.
        expect(arbiter.tryClaimPcm(), isFalse);
      });
    });

    test('first-starter-wins: PCM before TTS claims playback', () {
      final arbiter = TtsFallbackArbiter();
      expect(arbiter.tryClaimPcm(), isTrue);
      expect(arbiter.ttsStarted, isFalse);
    });

    test('speakNow marks TTS started so late PCM is dropped', () {
      final arbiter = TtsFallbackArbiter();
      arbiter.speakNow(() {});
      expect(arbiter.ttsStarted, isTrue);
      expect(arbiter.tryClaimPcm(), isFalse);
    });

    test('beginTurn resets TTS-started flag for the next turn', () {
      final arbiter = TtsFallbackArbiter();
      arbiter.speakNow(() {});
      arbiter.beginTurn();
      expect(arbiter.ttsStarted, isFalse);
      expect(arbiter.tryClaimPcm(), isTrue);
    });

    test('same turn never speaks twice (protocol + answer completions)', () {
      fakeAsync((async) {
        final arbiter = TtsFallbackArbiter();
        var speaks = 0;
        arbiter.scheduleFallback(() => speaks++);
        async.elapse(const Duration(milliseconds: 600));
        expect(speaks, 1);
        // Follow-up completion re-schedules: must be dropped, not layered.
        arbiter.scheduleFallback(() => speaks++);
        async.elapse(const Duration(seconds: 5));
        expect(speaks, 1);
      });
    });

    test('speakNow fires once per generation', () {
      final arbiter = TtsFallbackArbiter();
      var speaks = 0;
      arbiter.speakNow(() => speaks++);
      arbiter.speakNow(() => speaks++);
      expect(speaks, 1);
    });

    test('silent protocol actions are classified', () {
      expect(AssistantCommandGateway.isSilentProtocol('set_trip'), isTrue);
      expect(AssistantCommandGateway.isSilentProtocol('select_bus'), isTrue);
      expect(AssistantCommandGateway.isSilentProtocol('set_passenger'), isTrue);
      expect(AssistantCommandGateway.isSilentProtocol('set_payment'), isTrue);
      expect(AssistantCommandGateway.isSilentProtocol('confirm_booking'), isFalse);
      expect(AssistantCommandGateway.isSilentProtocol('book_ticket'), isFalse);
      expect(AssistantCommandGateway.isSilentProtocol(null), isFalse);
    });
  });

  group('TtsFallbackArbiter.shared cross-owner arbitration', () {
    // The Gemini Live screen and the floating assistant drive separate
    // sessions but share one global audio bridge; these tests pin the
    // contract that both owners arbitrate against the SAME instance so a
    // voice from one owner can never be doubled by the other.
    test('is a single app-wide instance', () {
      expect(identical(TtsFallbackArbiter.shared, TtsFallbackArbiter.shared),
          isTrue);
    });

    test('PCM claimed by one owner suppresses TTS armed by the other', () {
      fakeAsync((async) {
        final shared = TtsFallbackArbiter.shared;
        shared.beginTurn(); // isolate from any prior test state
        var ttsSpeaks = 0;
        // Screen owner arms the deferred fallback for its turn...
        shared.scheduleFallback(() => ttsSpeaks++, isLive: true);
        // ...and the floating owner's late PCM claims playback first.
        expect(shared.tryClaimPcm(), isTrue);
        async.elapse(const Duration(seconds: 5));
        expect(ttsSpeaks, 0);
        shared.beginTurn(); // clean up shared state for other tests
      });
    });

    test('handoff beginTurn from the other owner drops a stale armed TTS', () {
      fakeAsync((async) {
        final shared = TtsFallbackArbiter.shared;
        shared.beginTurn();
        var ttsSpeaks = 0;
        // TTS armed while the previous owner still held the turn...
        shared.scheduleFallback(() => ttsSpeaks++, isLive: true);
        // ...then the other owner takes over (fullscreen handoff).
        shared.beginTurn();
        async.elapse(const Duration(seconds: 5));
        expect(ttsSpeaks, 0);
      });
    });

    test('TTS started by one owner drops late PCM claimed by the other', () {
      fakeAsync((async) {
        final shared = TtsFallbackArbiter.shared;
        shared.beginTurn();
        var ttsSpeaks = 0;
        shared.scheduleFallback(() => ttsSpeaks++);
        async.elapse(const Duration(milliseconds: 600));
        expect(ttsSpeaks, 1);
        // Late PCM from the other owner's session must not layer a voice.
        expect(shared.tryClaimPcm(), isFalse);
        shared.beginTurn();
      });
    });
  });
}
