import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/a11y/announcement_coordinator.dart';
import '../../core/settings/app_settings_controller.dart';
import '../../data/repositories/transport_repository.dart';
import '../journey/journey_controller.dart';
import '../tickets/ticket_controller.dart';
import 'ai_control_glow.dart';
import 'audio_speech_engine.dart';
import 'gemini_live_screen.dart';

/// Result of evaluating an incoming speech transcript for the "Hey BusBuddy" wake phrase.
class WakeWordMatch {
  const WakeWordMatch({
    required this.isMatched,
    this.query,
  });

  final bool isMatched;
  final String? query;

  static const noMatch = WakeWordMatch(isMatched: false);
}

/// Service that listens in the background for the "Hey BusBuddy" wake phrase and
/// seamlessly launches the Gemini Live conversational assistant overlay.
///
/// Follows BusBuddy single-speaker audio architecture:
/// 1. Pauses when [GeminiLiveScreen] is open to prevent microphone contention.
/// 2. Respects [AppSettingsController.wakePhrase] setting.
/// 3. Pulses [AiControlGlow] (blue) and plays listening chime when triggered.
/// 4. Passes any trailing prompt query (e.g. "Hey BusBuddy, find a bus to Katpadi")
///    directly into [GeminiLiveScreen.initialQuery].
class WakeWordService extends ChangeNotifier {
  WakeWordService._();

  static final WakeWordService instance = WakeWordService._();

  AudioSpeechEngine? _audioEngine;
  AudioSpeechEngine get audioEngine => _audioEngine ??= AudioSpeechEngine();
  set audioEngine(AudioSpeechEngine? engine) => _audioEngine = engine;

  GlobalKey<NavigatorState>? navigatorKey;
  TicketController? ticketController;
  TransportRepository? repository;
  JourneyController? journeyController;

  bool _isListening = false;
  bool get isListening => _isListening;

  bool _isPaused = false;
  bool get isPaused => _isPaused;

  bool _isProcessingWake = false;
  Timer? _restartTimer;
  bool _initialized = false;

  /// Hook for tests or custom observers when wake word is detected.
  void Function(String? query)? onWakeWordDetected;

  /// Pattern matcher for wake phrase variations: "Hey BusBuddy", "BusBuddy", "OK BusBuddy", etc.
  static WakeWordMatch match(String transcript) {
    final clean = transcript.trim();
    if (clean.isEmpty) return WakeWordMatch.noMatch;

    final regex = RegExp(
      r'^(?:.*?\b)?(?:hey|ok|okay|hi|hello)?\s*(?:bus\s*buddy)[,\.!\?]?\s*(.*)$',
      caseSensitive: false,
    );
    final m = regex.firstMatch(clean);
    if (m != null) {
      final trailing = m.group(1)?.trim();
      return WakeWordMatch(
        isMatched: true,
        query: (trailing != null && trailing.isNotEmpty) ? trailing : null,
      );
    }
    return WakeWordMatch.noMatch;
  }

  /// Initializes the wake word service with the root navigator and dependencies.
  void initialize({
    required GlobalKey<NavigatorState> navigatorKey,
    TicketController? ticketController,
    TransportRepository? repository,
    JourneyController? journeyController,
  }) {
    this.navigatorKey = navigatorKey;
    this.ticketController = ticketController;
    this.repository = repository;
    this.journeyController = journeyController;

    if (!_initialized) {
      _initialized = true;
      AppSettingsController.instance.addListener(_onSettingsChanged);
    }

    if (AppSettingsController.instance.wakePhrase && !_isPaused) {
      startListening();
    }
  }

  void _onSettingsChanged() {
    final enabled = AppSettingsController.instance.wakePhrase;
    if (!enabled && _isListening) {
      stopListening();
    } else if (enabled && !_isListening && !_isPaused) {
      startListening();
    }
  }

  /// Starts listening for the wake word using the speech engine.
  void startListening() {
    if (_isListening || _isPaused || !AppSettingsController.instance.wakePhrase) {
      return;
    }
    _restartTimer?.cancel();
    _restartTimer = null;
    _isProcessingWake = false;
    _isListening = true;
    notifyListeners();

    try {
      audioEngine.startListening(
        onResult: (text, isFinal) {
          _handleTranscript(text, isFinal);
        },
        onError: (err) {
          debugPrint('[WakeWordService] Speech recognition notice: $err');
          if (!_isPaused && AppSettingsController.instance.wakePhrase) {
            _scheduleRestart(delayMs: 1500);
          }
        },
        onEnd: () {
          if (!_isProcessingWake && _isListening && !_isPaused) {
            _scheduleRestart(delayMs: 350);
          }
        },
      );
    } catch (e) {
      debugPrint('[WakeWordService] Failed to start listening: $e');
      _isListening = false;
      notifyListeners();
    }
  }

  void _handleTranscript(String text, bool isFinal) {
    if (_isProcessingWake || !_isListening || _isPaused) return;

    final matched = match(text);
    if (matched.isMatched) {
      triggerWake(query: matched.query);
    }
  }

  void _scheduleRestart({int delayMs = 350}) {
    _restartTimer?.cancel();
    if (_isPaused || !AppSettingsController.instance.wakePhrase) {
      _isListening = false;
      notifyListeners();
      return;
    }
    _restartTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!_isPaused && AppSettingsController.instance.wakePhrase) {
        _isListening = false;
        startListening();
      }
    });
  }

  /// Triggers the wake sequence: chimes, sets edge glow, announces, and opens [GeminiLiveScreen].
  void triggerWake({String? query}) {
    if (_isProcessingWake) return;
    _isProcessingWake = true;
    _stopInternal();

    // 1. Play listening chime
    try {
      audioEngine.playChime(isListening: true);
    } catch (_) {}

    // 2. Pulse AI edge glow blue (listening mode)
    AiControlGlow.instance.listening();

    // 3. Mute offline TTS immediately and silence speech engines
    AudioSpeechEngine.muteOfflineTts(true);
    AnnouncementCoordinator.instance.isAssistantActive = true;
    audioEngine.stop();
    AnnouncementCoordinator.instance.visualStatusText.value =
        'Hey BusBuddy detected. Starting voice assistant...';

    // 4. Fire callback if provided
    onWakeWordDetected?.call(query);

    // 5. Open GeminiLiveScreen via root navigator
    final nav = navigatorKey?.currentState;
    if (nav != null) {
      unawaited(
        nav.push(
          MaterialPageRoute<void>(
            builder: (_) => GeminiLiveScreen(
              initialQuery: query,
              ticketController: ticketController,
              repository: repository,
              journeyController: journeyController,
            ),
          ),
        ),
      );
    }
  }

  /// Simulates a wake word phrase (used for automated testing and manual command triggering).
  bool simulateWakeWord(String spokenText) {
    final result = match(spokenText);
    if (result.isMatched) {
      triggerWake(query: result.query);
      return true;
    }
    return false;
  }

  /// Pauses wake word listening (called while [GeminiLiveScreen] is open).
  void pause() {
    _isPaused = true;
    _stopInternal();
  }

  /// Resumes wake word listening (called when [GeminiLiveScreen] is popped).
  void resume() {
    _isPaused = false;
    _isProcessingWake = false;
    if (AppSettingsController.instance.wakePhrase) {
      _scheduleRestart(delayMs: 400);
    }
  }

  /// Stops wake word listening.
  void stopListening() {
    _stopInternal();
  }

  void _stopInternal() {
    _restartTimer?.cancel();
    _restartTimer = null;
    if (_isListening) {
      _isListening = false;
      try {
        audioEngine.stopListening();
      } catch (_) {}
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _stopInternal();
    if (_initialized) {
      AppSettingsController.instance.removeListener(_onSettingsChanged);
      _initialized = false;
    }
    navigatorKey = null;
    ticketController = null;
    repository = null;
    journeyController = null;
    onWakeWordDetected = null;
  }

  void resetForTesting({bool uninitialize = false}) {
    _stopInternal();
    _isPaused = false;
    _isProcessingWake = false;
    onWakeWordDetected = null;
    if (uninitialize && _initialized) {
      AppSettingsController.instance.removeListener(_onSettingsChanged);
      _initialized = false;
      navigatorKey = null;
      ticketController = null;
      repository = null;
      journeyController = null;
    }
  }
}
