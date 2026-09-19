import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';

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

/// Centralized Accessibility Announcement Coordinator for BusBuddy.
///
/// Addresses Astra Section 2.4 / P0 Architecture Gates:
/// 1. Deduplicates rapid consecutive ETA ticks within a debounce window.
/// 2. Suppresses announcements from background/hidden routes.
/// 3. Respects user speech/haptic preferences.
/// 4. Never competes with ongoing Gemini Live or TTS audio.
/// 5. Exposes a persistent visual/text status [ValueNotifier] as a fallback for deaf/hard-of-hearing commuters.
class AnnouncementCoordinator {
  AnnouncementCoordinator._();

  static final AnnouncementCoordinator instance = AnnouncementCoordinator._();

  /// Debounce threshold for non-urgent duplicate announcements.
  static const Duration defaultDebounceWindow = Duration(seconds: 3);

  String? _lastAnnouncedMessage;
  DateTime? _lastAnnouncedTimestamp;
  String? _activeRouteId;

  /// Whether the AI assistant or audio engine is currently speaking.
  bool isAudioPlaying = false;

  /// Whether spoken accessibility announcements are enabled by the user.
  bool isSpeechEnabled = true;

  /// Persistent visual status text representing the latest announcement.
  /// Guarantees that alerts are accessible even if audio is muted or dropped.
  final ValueNotifier<String> visualStatusText = ValueNotifier<String>('');

  /// Sets the currently focused transit route. Updates for other routes are suppressed.
  void setActiveRoute(String? routeId) {
    _activeRouteId = routeId;
  }

  /// Dispatches an accessible announcement through the coordinator.
  ///
  /// Returns `true` if the announcement was spoken via [SemanticsService],
  /// or `false` if it was suppressed (e.g. duplicate, muted, or route mismatch).
  bool announce(
    String message, {
    AnnouncementPriority priority = AnnouncementPriority.normal,
    String? routeId,
    Duration debounceWindow = defaultDebounceWindow,
  }) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return false;

    // Always update visual text status regardless of audio suppression
    visualStatusText.value = trimmed;

    // Route isolation: suppress if message belongs to a non-active route
    if (routeId != null && _activeRouteId != null && routeId != _activeRouteId && priority != AnnouncementPriority.urgent) {
      return false;
    }

    // Deduplication check: suppress identical messages within debounce window
    final now = DateTime.now();
    if (_lastAnnouncedMessage == trimmed && _lastAnnouncedTimestamp != null) {
      final elapsed = now.difference(_lastAnnouncedTimestamp!);
      if (elapsed < debounceWindow && priority != AnnouncementPriority.urgent) {
        return false;
      }
    }

    // Contention check: do not talk over active voice assistant
    if (isAudioPlaying && priority != AnnouncementPriority.urgent) {
      return false;
    }

    // User preference check
    if (!isSpeechEnabled && priority != AnnouncementPriority.urgent) {
      return false;
    }

    // Commit announcement
    _lastAnnouncedMessage = trimmed;
    _lastAnnouncedTimestamp = now;

    // Dispatch polite or assertive platform announcement
    try {
      SemanticsService.announce(trimmed, TextDirection.ltr);
      return true;
    } catch (e) {
      debugPrint('[AnnouncementCoordinator] Failed to dispatch announcement: $e');
      return false;
    }
  }

  /// Resets coordinator state (useful for tests and session teardown).
  void reset() {
    _lastAnnouncedMessage = null;
    _lastAnnouncedTimestamp = null;
    _activeRouteId = null;
    isAudioPlaying = false;
    isSpeechEnabled = true;
    visualStatusText.value = '';
  }
}
