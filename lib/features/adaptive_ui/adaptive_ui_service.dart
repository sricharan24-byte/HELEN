import 'package:flutter/material.dart';

import '../../core/settings/app_settings_controller.dart';
import '../../data/datasources/local_json_store.dart';
import '../../data/models/adaptive_shortcut.dart';

/// Service engine that observes non-sensitive commuter transit patterns
/// and generates user-governed adaptive shortcuts.
class AdaptiveUiService extends ChangeNotifier {
  static final AdaptiveUiService instance = AdaptiveUiService._();
  AdaptiveUiService._() {
    seedDemonstrationHabits();
  }

  factory AdaptiveUiService() => instance;

  /// Creates an isolated instance for unit and widget testing.
  AdaptiveUiService.local() {
    seedDemonstrationHabits();
  }

  static const String storageKey = 'busbuddy.adaptive_ui.v1';
  LocalJsonStore? _store;

  /// Minimum frequency required to trigger an automatic adaptive suggestion.
  int suggestionThreshold = 2;

  /// Frequency counter for pattern keys (e.g. 'route:vit-main-gate:katpadi-railway-station').
  final Map<String, int> _usageFrequencies = {};

  /// List of generated adaptive shortcuts.
  final List<AdaptiveShortcut> _shortcuts = [];

  // ── Getters ─────────────────────────────────────────────────────────────────

  /// All tracked shortcuts regardless of status.
  List<AdaptiveShortcut> get allShortcuts => List.unmodifiable(_shortcuts);

  /// Shortcuts visible on the Home Screen (suggested and accepted).
  /// Respects AppSettingsController.instance.adaptiveUi master toggle.
  List<AdaptiveShortcut> get visibleShortcuts {
    if (!AppSettingsController.instance.adaptiveUi) return const [];
    return _shortcuts
        .where((s) => s.status == AdaptiveShortcutStatus.suggested || s.status == AdaptiveShortcutStatus.accepted)
        .toList();
  }

  /// Only shortcuts that the commuter explicitly accepted/pinned.
  List<AdaptiveShortcut> get acceptedShortcuts =>
      _shortcuts.where((s) => s.status == AdaptiveShortcutStatus.accepted).toList();

  /// Only shortcuts that are currently pending commuter review (accept or dismiss).
  List<AdaptiveShortcut> get pendingSuggestions =>
      _shortcuts.where((s) => s.status == AdaptiveShortcutStatus.suggested).toList();

  /// Total number of unique habit patterns tracked.
  int get trackedPatternsCount => _usageFrequencies.length;

  /// True if there are any active shortcuts visible to the user.
  bool get hasVisibleShortcuts => visibleShortcuts.isNotEmpty;

  // ── Persistence ─────────────────────────────────────────────────────────────

  Future<void> hydrate(LocalJsonStore store) async {
    await store.flush();
    _store = store;
    final stored = store.read(storageKey);
    final value = stored.value;

    if (value is Map<String, dynamic>) {
      // Hydrate usage frequencies
      final freqs = value['frequencies'];
      if (freqs is Map) {
        _usageFrequencies.clear();
        for (final entry in freqs.entries) {
          if (entry.value is num) {
            _usageFrequencies[entry.key.toString()] = (entry.value as num).toInt();
          }
        }
      }

      // Hydrate shortcuts
      final rawList = value['shortcuts'];
      if (rawList is List) {
        _shortcuts.clear();
        for (final item in rawList) {
          if (item is Map<String, dynamic>) {
            _shortcuts.add(AdaptiveShortcut.fromJson(item));
          } else if (item is Map) {
            _shortcuts.add(AdaptiveShortcut.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }
    }

    if (stored.absent && _shortcuts.isNotEmpty) {
      await store.write(storageKey, _snapshot());
    }
    notifyListeners();
  }

  Map<String, Object> _snapshot() => {
        'frequencies': _usageFrequencies,
        'shortcuts': _shortcuts.map((s) => s.toJson()).toList(),
      };

  @override
  void notifyListeners() {
    _store?.write(storageKey, _snapshot());
    super.notifyListeners();
  }

  // ── Usage Tracking & Shortcut Generation ───────────────────────────────────

  /// Records a route search event between two corridor stops.
  void recordRouteSearch({
    required String originId,
    required String destinationId,
    required String originName,
    required String destinationName,
  }) {
    if (!AppSettingsController.instance.adaptiveUi) return;

    final key = 'route:$originId:$destinationId';
    final count = (_usageFrequencies[key] ?? 0) + 1;
    _usageFrequencies[key] = count;

    final shortcutId = 'shortcut_$key';
    final existingIndex = _shortcuts.indexWhere((s) => s.id == shortcutId);

    if (existingIndex != -1) {
      // Update existing shortcut usage count
      final existing = _shortcuts[existingIndex];
      _shortcuts[existingIndex] = existing.copyWith(
        usageCount: count,
        lastUsed: DateTime.now(),
        subtitle: 'Used $count times • ${existing.isAccepted ? "Pinned" : "Suggested"}',
      );
      notifyListeners();
    } else if (count >= suggestionThreshold) {
      // Create new suggested shortcut
      _shortcuts.insert(
        0,
        AdaptiveShortcut(
          id: shortcutId,
          type: AdaptiveShortcutType.route,
          title: '$originName → $destinationName',
          subtitle: 'Used $count times • Suggested',
          actionType: 'route_search',
          actionData: {
            'originId': originId,
            'destinationId': destinationId,
            'originName': originName,
            'destinationName': destinationName,
          },
          usageCount: count,
          lastUsed: DateTime.now(),
          status: AdaptiveShortcutStatus.suggested,
        ),
      );
      notifyListeners();
    }
  }

  /// Records a digital ticket booking event.
  void recordTicketBooking({
    required String originName,
    required String destinationName,
    required String busId,
    required String routeId,
  }) {
    if (!AppSettingsController.instance.adaptiveUi) return;

    final key = 'booking:$routeId:$busId';
    final count = (_usageFrequencies[key] ?? 0) + 1;
    _usageFrequencies[key] = count;

    final shortcutId = 'shortcut_$key';
    final existingIndex = _shortcuts.indexWhere((s) => s.id == shortcutId);

    if (existingIndex != -1) {
      final existing = _shortcuts[existingIndex];
      _shortcuts[existingIndex] = existing.copyWith(
        usageCount: count,
        lastUsed: DateTime.now(),
        subtitle: 'Booked $count times • ${existing.isAccepted ? "Pinned" : "Suggested"}',
      );
      notifyListeners();
    } else if (count >= suggestionThreshold) {
      _shortcuts.insert(
        0,
        AdaptiveShortcut(
          id: shortcutId,
          type: AdaptiveShortcutType.ticketBooking,
          title: 'Quick Book • $originName → $destinationName',
          subtitle: 'Booked $count times • Suggested',
          actionType: 'book_ticket',
          actionData: {
            'originName': originName,
            'destinationName': destinationName,
            'busId': busId,
            'routeId': routeId,
          },
          usageCount: count,
          lastUsed: DateTime.now(),
          status: AdaptiveShortcutStatus.suggested,
        ),
      );
      notifyListeners();
    }
  }

  /// Records a live bus map lookup event.
  void recordLiveTracking({
    required String busId,
    required String routeId,
  }) {
    if (!AppSettingsController.instance.adaptiveUi) return;

    final key = 'tracking:$busId';
    final count = (_usageFrequencies[key] ?? 0) + 1;
    _usageFrequencies[key] = count;

    final shortcutId = 'shortcut_$key';
    final existingIndex = _shortcuts.indexWhere((s) => s.id == shortcutId);

    if (existingIndex != -1) {
      final existing = _shortcuts[existingIndex];
      _shortcuts[existingIndex] = existing.copyWith(
        usageCount: count,
        lastUsed: DateTime.now(),
        subtitle: 'Tracked $count times • ${existing.isAccepted ? "Pinned" : "Suggested"}',
      );
      notifyListeners();
    } else if (count >= suggestionThreshold) {
      _shortcuts.insert(
        0,
        AdaptiveShortcut(
          id: shortcutId,
          type: AdaptiveShortcutType.liveTracking,
          title: 'Live Tracker • Bus $busId',
          subtitle: 'Tracked $count times • Suggested',
          actionType: 'track_bus',
          actionData: {
            'busId': busId,
            'routeId': routeId,
          },
          usageCount: count,
          lastUsed: DateTime.now(),
          status: AdaptiveShortcutStatus.suggested,
        ),
      );
      notifyListeners();
    }
  }

  /// Generic event recorder for any arbitrary transit feature.
  void recordGenericEvent({
    required String actionType,
    required String title,
    required String subtitle,
    AdaptiveShortcutType type = AdaptiveShortcutType.feature,
    Map<String, dynamic> actionData = const {},
  }) {
    if (!AppSettingsController.instance.adaptiveUi) return;

    final key = 'action:$actionType';
    final count = (_usageFrequencies[key] ?? 0) + 1;
    _usageFrequencies[key] = count;

    final shortcutId = 'shortcut_$key';
    final existingIndex = _shortcuts.indexWhere((s) => s.id == shortcutId);

    if (existingIndex != -1) {
      final existing = _shortcuts[existingIndex];
      _shortcuts[existingIndex] = existing.copyWith(
        usageCount: count,
        lastUsed: DateTime.now(),
      );
      notifyListeners();
    } else if (count >= suggestionThreshold) {
      _shortcuts.insert(
        0,
        AdaptiveShortcut(
          id: shortcutId,
          type: type,
          title: title,
          subtitle: '$subtitle • Suggested',
          actionType: actionType,
          actionData: actionData,
          usageCount: count,
          lastUsed: DateTime.now(),
          status: AdaptiveShortcutStatus.suggested,
        ),
      );
      notifyListeners();
    }
  }

  // ── Commuter Governance Controls ───────────────────────────────────────────

  /// Commuter accepts a suggested shortcut and pins it to their Home Screen.
  void acceptShortcut(String id) {
    final index = _shortcuts.indexWhere((s) => s.id == id);
    if (index != -1) {
      final s = _shortcuts[index];
      _shortcuts[index] = s.copyWith(
        status: AdaptiveShortcutStatus.accepted,
        subtitle: 'Pinned Shortcut',
      );
      notifyListeners();
    }
  }

  /// Commuter dismisses a suggested shortcut, removing it from suggestions.
  void dismissShortcut(String id) {
    final index = _shortcuts.indexWhere((s) => s.id == id);
    if (index != -1) {
      final s = _shortcuts[index];
      _shortcuts[index] = s.copyWith(
        status: AdaptiveShortcutStatus.dismissed,
      );
      notifyListeners();
    }
  }

  /// Completely removes a shortcut.
  void removeShortcut(String id) {
    _shortcuts.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  /// Clears all learning history, tracked counts, and shortcuts.
  void resetAllLearningData() {
    _usageFrequencies.clear();
    _shortcuts.clear();
    notifyListeners();
  }

  /// Pre-populates sample Vellore demonstration habits.
  void seedDemonstrationHabits() {
    _usageFrequencies.clear();
    _shortcuts.clear();

    _usageFrequencies['route:vit-main-gate:katpadi-railway-station'] = 4;
    _usageFrequencies['tracking:18B'] = 3;
    _usageFrequencies['booking:vit-to-katpadi:18B'] = 3;

    _shortcuts.addAll([
      AdaptiveShortcut(
        id: 'shortcut_vit_katpadi',
        type: AdaptiveShortcutType.route,
        title: 'VIT → Katpadi Express',
        subtitle: 'Used 4 times • Suggested',
        actionType: 'route_search',
        actionData: const {
          'originId': 'vit-main-gate',
          'destinationId': 'katpadi-railway-station',
          'originName': 'VIT Main Gate',
          'destinationName': 'Katpadi Railway Station',
        },
        usageCount: 4,
        lastUsed: DateTime.now(),
        status: AdaptiveShortcutStatus.suggested,
      ),
      AdaptiveShortcut(
        id: 'shortcut_bus_18b_live',
        type: AdaptiveShortcutType.liveTracking,
        title: 'Track Bus 18B Live',
        subtitle: 'Used 3 times • Suggested',
        actionType: 'track_bus',
        actionData: const {
          'busId': '18B',
          'routeId': 'vit-to-katpadi',
        },
        usageCount: 3,
        lastUsed: DateTime.now(),
        status: AdaptiveShortcutStatus.suggested,
      ),
      AdaptiveShortcut(
        id: 'shortcut_student_pass',
        type: AdaptiveShortcutType.ticketBooking,
        title: 'Student Pass to Katpadi',
        subtitle: 'Pinned Shortcut',
        actionType: 'book_ticket',
        actionData: const {
          'originName': 'VIT Main Gate',
          'destinationName': 'Katpadi Railway Station',
          'busId': '18B',
        },
        usageCount: 3,
        lastUsed: DateTime.now(),
        status: AdaptiveShortcutStatus.accepted,
      ),
    ]);
  }
}
