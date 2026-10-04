import 'package:busbuddy/core/a11y/dispose_guard.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the contract that lets [GeminiLiveScreen.dispose] hand a process-wide
/// reset to a helper: no single teardown failure may strand global state.
void main() {
  group('runDisposeSteps (AI glow / microphone teardown safety)', () {
    test('runs every step in the order given', () {
      final order = <String>[];
      runDisposeSteps([
        (name: 'glow', run: () => order.add('glow')),
        (name: 'timers', run: () => order.add('timers')),
        (name: 'session', run: () => order.add('session')),
      ]);
      expect(order, ['glow', 'timers', 'session']);
    });

    test('a throwing step does not skip the steps after it', () {
      final ran = <String>[];
      runDisposeSteps([
        (name: 'before', run: () => ran.add('before')),
        (
          name: 'liveSession',
          run: () => throw StateError('socket teardown failed'),
        ),
        (name: 'after', run: () => ran.add('after')),
      ]);
      expect(ran, ['before', 'after']);
    });

    // The exact regression: the AI edge glow is a singleton painted above the
    // navigator, so a glow reset that sits *below* a throwing live-socket
    // teardown leaves the glow lit over Home for the rest of the process.
    test('a later failure cannot strand a reset that already ran', () {
      var released = false;
      runDisposeSteps([
        (
          name: 'aiControlGlow',
          run: () => released = true,
        ),
        (
          name: 'liveSession',
          run: () => throw StateError('socket teardown failed'),
        ),
      ]);
      expect(
        released,
        isTrue,
        reason: 'process-wide resets run first, so a later throw cannot strand them',
      );
    });

    test('several failures are all isolated', () {
      var last = false;
      runDisposeSteps([
        (name: 'a', run: () => throw StateError('first')),
        (name: 'b', run: () => throw StateError('second')),
        (name: 'c', run: () => last = true),
      ]);
      expect(last, isTrue);
    });

    test('an empty step list is a no-op', () {
      expect(() => runDisposeSteps([]), returnsNormally);
    });
  });
}
