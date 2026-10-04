import 'package:flutter/foundation.dart';

/// One named teardown step.
typedef DisposeStep = ({String name, void Function() run});

/// Runs teardown steps in order, isolating failures.
///
/// Flutter's [State.dispose] runs to completion only if nothing throws. Several
/// of BusBuddy's dispose steps touch process-wide state — the microphone feed,
/// the AI control glow, the audio session — so a single throwing step used to
/// skip every step after it. That is how the AI edge glow could survive a
/// screen change and stay painted over Home for the rest of the session: the
/// live-socket teardown threw on a real device, and the glow reset sat below it.
///
/// Each step here is isolated: a failure is reported and the remaining steps
/// still run. Put process-wide resets FIRST so they cannot be stranded.
void runDisposeSteps(List<DisposeStep> steps) {
  for (final step in steps) {
    try {
      step.run();
    } catch (error, stack) {
      debugPrint(
        'BusBuddy: dispose step "${step.name}" threw and was skipped: $error\n'
        '$stack',
      );
    }
  }
}
