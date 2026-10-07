import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';

import '../../features/ai_assistant/audio_speech_engine.dart';

/// Announcement priority levels per Astra Section 2.4.
enum AnnouncementPriority {
  /// Safety, SOS, emergency notifications. Always announced immediately.
  urgent,

  /// Bus arrival, boarding call, destination reached.
  high,

  /// Periodic ETA updates, next stop alerts. Politeness-controlled and debounced.
  normal,

  /// General status hints and non-critical navigation facts.
  low,
}

/// Token representing an active route or screen lifecycle scope.
class AnnouncementScopeToken {
  AnnouncementScopeToken._(this.scopeId, this._coordinator);

  final String scopeId;
  final AnnouncementCoordinator _coordinator;
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _coordinator._unregisterScope(this);
  }
}

class QueuedAnnouncement {
  QueuedAnnouncement({
    required this.message,
    required this.priority,
    required this.textDirection,
    required this.routeId,
    required this.createdAt,
    this.ttl = const Duration(seconds: 15),
  });

  final String message;
  final AnnouncementPriority priority;
  final TextDirection textDirection;
  final String? routeId;
  final DateTime createdAt;
  final Duration ttl;

  bool get isExpired => DateTime.now().difference(createdAt) > ttl;
}

/// Centralized Accessibility Announcement Coordinator and Audio Arbiter for BusBuddy.
///
/// Addresses Astra BUS-P1-03:
/// 1. Route-scoped registration tokens with explicit disposal.
/// 2. Filters inactive route updates BEFORE mutating visible status text.
/// 3. Debounces semantic ETA transitions (suppresses rapid 2-second tick noise).
/// 4. Priority queue with TTL: queues high/normal messages while audio plays instead of dropping them.
/// 5. Immediate urgent dispatch and audio ducking notification.
/// 6. Configurable text direction (LTR/RTL).
class AnnouncementCoordinator {
  AnnouncementCoordinator._();

  static final AnnouncementCoordinator instance = AnnouncementCoordinator._();

  static const Duration defaultDebounceWindow = Duration(seconds: 3);
  static const int maxQueueCapacity = 10;

  String? _lastAnnouncedMessage;
  DateTime? _lastAnnouncedTimestamp;
  String? _activeRouteId;
  AnnouncementScopeToken? _activeScopeToken;

  /// Whether the AI assistant or audio engine is currently playing.
  bool _isAudioPlaying = false;
  bool get isAudioPlaying => _isAudioPlaying;

  /// Setter mirror of [setAudioPlaying] for direct test/assignment use.
  set isAudioPlaying(bool value) => setAudioPlaying(value);

  /// Test-only hook: when set, receives dispatched announcements
  /// (message, priority) instead of the platform SemanticsService.
  void Function(String message, AnnouncementPriority priority)?
      testAnnounceHandler;

  /// Resets coordinator state for test isolation (alias of [reset]).
  void resetForTesting() => reset();

  /// Whether spoken accessibility announcements are enabled by the user.
  bool isSpeechEnabled = true;

  /// True when the voice assistant (Gemini Live) is active, suppressing background
  /// spoken announcements so they never interrupt or speak over the conversation.
  bool isAssistantActive = false;

  AudioSpeechEngine? _speechEngine;
  AudioSpeechEngine get speechEngine => _speechEngine ??= AudioSpeechEngine();
  set speechEngine(AudioSpeechEngine? engine) => _speechEngine = engine;

  /// Test hook to observe or intercept spoken voice announcements.
  void Function(String message)? speechSpeaker;

  /// Default text direction for announcements.
  TextDirection textDirection = TextDirection.ltr;

  /// Persistent visual status text representing the latest active announcement.
  final ValueNotifier<String> visualStatusText = ValueNotifier<String>('');

  /// Callback to notify audio engines to duck/pause on urgent alerts.
  VoidCallback? onUrgentAlertTriggered;

  /// Function to mock or intercept platform semantics announcements for testing.
  bool Function(String message, TextDirection direction)? semanticsAnnounceHandler;

  final List<QueuedAnnouncement> _queue = [];
  List<QueuedAnnouncement> get queuedAnnouncements => List.unmodifiable(_queue);

  String? _lastEtaStop;
  int? _lastEtaMinutes;
  DateTime? _lastEtaAnnouncedTime;

  /// Registers an active route or screen lifecycle scope.
  AnnouncementScopeToken registerScope(String scopeId) {
    _activeScopeToken?.dispose();
    _activeRouteId = scopeId;
    _lastEtaStop = null;
    _lastEtaMinutes = null;
    _lastEtaAnnouncedTime = null;
    final token = AnnouncementScopeToken._(scopeId, this);
    _activeScopeToken = token;
    return token;
  }

  void _unregisterScope(AnnouncementScopeToken token) {
    if (_activeScopeToken == token) {
      _activeScopeToken = null;
      _activeRouteId = null;
      _lastEtaStop = null;
      _lastEtaMinutes = null;
      _lastEtaAnnouncedTime = null;
    }
  }

  void setActiveRoute(String? routeId) {
    _activeRouteId = routeId;
  }

  void setAudioPlaying(bool playing) {
    _isAudioPlaying = playing;
    if (!_isAudioPlaying) {
      _drainQueue();
    }
  }

  /// Announces a semantic ETA update, debouncing minor changes and rapid periodic ticks.
  bool announceEtaUpdate({
    required String routeId,
    required String stopName,
    required int etaMinutes,
    AnnouncementPriority priority = AnnouncementPriority.normal,
    TextDirection? direction,
  }) {
    final now = DateTime.now();
    final stopChanged = _lastEtaStop != stopName;
    final minutesDelta = (_lastEtaMinutes != null) ? (etaMinutes - _lastEtaMinutes!).abs() : 999;
    final timeElapsed = _lastEtaAnnouncedTime != null ? now.difference(_lastEtaAnnouncedTime!) : const Duration(minutes: 5);

    // Suppress rapid ticks if stop has not changed and ETA delta < 1 min within 30s
    if (!stopChanged && minutesDelta == 0 && timeElapsed < const Duration(seconds: 30) && priority != AnnouncementPriority.urgent) {
      return false;
    }

    _lastEtaStop = stopName;
    _lastEtaMinutes = etaMinutes;
    _lastEtaAnnouncedTime = now;

    final etaText = etaMinutes <= 1
        ? 'Bus arriving at $stopName now.'
        : 'Next stop $stopName in $etaMinutes minutes.';

    return announce(
      etaText,
      priority: priority,
      routeId: routeId,
      textDirection: direction,
    );
  }

  /// Dispatches an accessible announcement through the coordinator.
  bool announce(
    String message, {
    AnnouncementPriority priority = AnnouncementPriority.normal,
    String? routeId,
    Duration debounceWindow = defaultDebounceWindow,
    TextDirection? textDirection,
  }) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return false;

    // 1. Scope / Route filtering: Suppress before mutating state per BUS-P1-03
    if (routeId != null && _activeRouteId != null && routeId != _activeRouteId && priority != AnnouncementPriority.urgent) {
      return false;
    }

    // Passed route filtering: update visible status text
    visualStatusText.value = trimmed;

    // 2. Exact message deduplication within debounce window
    final now = DateTime.now();
    if (_lastAnnouncedMessage == trimmed && _lastAnnouncedTimestamp != null) {
      final elapsed = now.difference(_lastAnnouncedTimestamp!);
      if (elapsed < debounceWindow && priority != AnnouncementPriority.urgent) {
        return false;
      }
    }

    // 3. User preference check
    if (!isSpeechEnabled && priority != AnnouncementPriority.urgent) {
      return false;
    }

    final effectiveDir = textDirection ?? this.textDirection;

    // 4. Audio Contention Management
    if (_isAudioPlaying) {
      if (priority == AnnouncementPriority.urgent) {
        // Urgent alert interrupts/ducks assistant audio
        onUrgentAlertTriggered?.call();
      } else {
        // Queue high / normal messages in bounded queue
        _cleanQueue();
        if (_queue.length < maxQueueCapacity) {
          _queue.add(
            QueuedAnnouncement(
              message: trimmed,
              priority: priority,
              textDirection: effectiveDir,
              routeId: routeId,
              createdAt: now,
            ),
          );
        }
        return false;
      }
    }

    return _dispatch(trimmed, effectiveDir, priority, now);
  }

  bool _dispatch(String message, TextDirection dir, AnnouncementPriority priority, DateTime timestamp) {
    _lastAnnouncedMessage = message;
    _lastAnnouncedTimestamp = timestamp;

    try {
      if (isSpeechEnabled && !isAssistantActive) {
        if (speechSpeaker != null) {
          speechSpeaker!(message);
        } else if (testAnnounceHandler == null && semanticsAnnounceHandler == null) {
          try {
            speechEngine.speak(message);
          } catch (e) {
            debugPrint('[AnnouncementCoordinator] Failed to speak: $e');
          }
        }
      }

      if (testAnnounceHandler != null) {
        testAnnounceHandler!(message, priority);
        _lastAnnouncedMessage = message;
        _lastAnnouncedTimestamp = timestamp;
        return true;
      }
      if (semanticsAnnounceHandler != null) {
        return semanticsAnnounceHandler!(message, dir);
      }
      // BUS-P2-04: SemanticsService.announce is deprecated (incompatible with
      // multiple windows); sendAnnouncement is view-scoped. Tests inject
      // testAnnounceHandler/semanticsAnnounceHandler, so production reaches
      // the implicit view here — exactly the deprecated single-window path.
      // ignore: deprecated_member_use
      unawaited(SemanticsService.announce(message, dir));
      return true;
    } catch (e) {
      debugPrint('[AnnouncementCoordinator] Failed to dispatch announcement: $e');
      return false;
    }
  }

  void _cleanQueue() {
    _queue.removeWhere((item) => item.isExpired);
  }

  void _drainQueue() {
    _cleanQueue();
    if (_queue.isEmpty) return;

    // Sort by priority descending (urgent -> high -> normal -> low)
    _queue.sort((a, b) => a.priority.index.compareTo(b.priority.index));

    while (_queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      if (!next.isExpired) {
        // Verify route still active
        if (next.routeId != null && _activeRouteId != null && next.routeId != _activeRouteId && next.priority != AnnouncementPriority.urgent) {
          continue;
        }
        _dispatch(next.message, next.textDirection, next.priority, DateTime.now());
        break;
      }
    }
  }

  /// Resets coordinator state (for tests and session teardown).
  void reset() {
    _lastAnnouncedMessage = null;
    _lastAnnouncedTimestamp = null;
    _activeRouteId = null;
    _activeScopeToken?.dispose();
    _activeScopeToken = null;
    _isAudioPlaying = false;
    isSpeechEnabled = true;
    isAssistantActive = false;
    textDirection = TextDirection.ltr;
    visualStatusText.value = '';
    onUrgentAlertTriggered = null;
    semanticsAnnounceHandler = null;
    testAnnounceHandler = null;
    speechSpeaker = null;
    _speechEngine = null;
    _queue.clear();
    _lastEtaStop = null;
    _lastEtaMinutes = null;
    _lastEtaAnnouncedTime = null;
  }
}
