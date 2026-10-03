import 'package:flutter/material.dart';

/// What the AI assistant is doing right now. Drives the edge glow that
/// tells the passenger the app is under AI control.
enum AiGlowMode {
  idle,
  listening,
  speaking,
  acting;

  Color get color {
    switch (this) {
      case AiGlowMode.listening:
        return const Color(0xFF007AFF); // brand blue — microphone open
      case AiGlowMode.speaking:
        return const Color(0xFF8B5CF6); // violet — assistant replying
      case AiGlowMode.acting:
        return const Color(0xFFF59E0B); // amber — driving a screen/booking flow
      case AiGlowMode.idle:
        return const Color(0xFF007AFF);
    }
  }
}

/// Single source of truth for "is the AI controlling the app". The Gemini
/// Live screen updates it at every state change; the frame painted in
/// [MaterialApp.builder] reacts on every screen, including the ones the
/// AI itself opens.
class AiControlGlow extends ChangeNotifier {
  AiControlGlow._();
  static final AiControlGlow instance = AiControlGlow._();

  AiGlowMode _mode = AiGlowMode.idle;
  AiGlowMode get mode => _mode;

  void setMode(AiGlowMode next) {
    if (_mode == next) return;
    _mode = next;
    notifyListeners();
  }

  void listening() => setMode(AiGlowMode.listening);

  void speaking() => setMode(AiGlowMode.speaking);

  void acting() => setMode(AiGlowMode.acting);

  void idle() => setMode(AiGlowMode.idle);
}

/// Decorative edge glow (top bar, bottom bar, side rails) shown while the
/// AI is in control. Purely visual: [IgnorePointer] and [ExcludeSemantics]
/// mean it can never take focus, hit-test, or feed a screen reader, and it
/// owns no audio — the single-speaker contract is untouched.
class AiGlowFrame extends StatefulWidget {
  const AiGlowFrame({super.key});

  @override
  State<AiGlowFrame> createState() => _AiGlowFrameState();
}

class _AiGlowFrameState extends State<AiGlowFrame>
    with SingleTickerProviderStateMixin {
  static const double _barHeight = 72;
  static const double _railWidth = 28;

  late final AnimationController _pulse;

  // Created once: a fresh merge per build would force the
  // ListenableBuilder below to swap subscriptions on every
  // pulse tick.
  late final Listenable _listeners =
      Listenable.merge([AiControlGlow.instance, _pulse]);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    // The pulse loop only runs while the AI is active, so
    // pumpAndSettle (tests) and idle batteries are never kept
    // alive by a decorative animation.
    AiControlGlow.instance.addListener(_syncPulse);
    _syncPulse();
  }

  void _syncPulse() {
    final active = AiControlGlow.instance.mode != AiGlowMode.idle;
    if (active && !_pulse.isAnimating) {
      // BUS-P2-04 (discarded_futures): repeat() never completes while
      // the mode is active; intentionally fire-and-forget pulse loop.
      // ignore: discarded_futures
      _pulse.repeat(reverse: true);
    } else if (!active) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    AiControlGlow.instance.removeListener(_syncPulse);
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _listeners,
      builder: (context, _) {
        final mode = AiControlGlow.instance.mode;
        if (mode == AiGlowMode.idle) return const SizedBox.shrink();
        final color = mode.color;
        final strength = 0.55 + 0.45 * _pulse.value;
        return IgnorePointer(
          child: ExcludeSemantics(
            child: Stack(
              children: [
                _edge(
                  color,
                  strength,
                  alpha: 0.85,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  top: 0,
                  left: 0,
                  right: 0,
                  height: _barHeight,
                ),
                _edge(
                  color,
                  strength,
                  alpha: 0.85,
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: _barHeight,
                ),
                _edge(
                  color,
                  strength,
                  alpha: 0.6,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  top: 0,
                  bottom: 0,
                  left: 0,
                  width: _railWidth,
                ),
                _edge(
                  color,
                  strength,
                  alpha: 0.6,
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: _railWidth,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _edge(
    Color color,
    double strength, {
    required double alpha,
    required Alignment begin,
    required Alignment end,
    double? top,
    double? bottom,
    double? left,
    double? right,
    double? height,
    double? width,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      height: height,
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: begin,
            end: end,
            colors: [
              color.withValues(alpha: alpha * strength),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}
