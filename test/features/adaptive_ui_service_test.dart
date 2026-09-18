import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/core/settings/app_settings_controller.dart';
import 'package:busbuddy/data/datasources/local_json_store.dart';
import 'package:busbuddy/data/models/adaptive_shortcut.dart';
import 'package:busbuddy/features/adaptive_ui/adaptive_ui_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AdaptiveShortcut Model', () {
    test('constructs with valid default values', () {
      final shortcut = AdaptiveShortcut(
        id: 'test_1',
        type: AdaptiveShortcutType.route,
        title: 'VIT to Katpadi',
        subtitle: 'Used 3 times',
        actionType: 'route_search',
        lastUsed: DateTime(2026, 9, 17),
      );

      expect(shortcut.id, 'test_1');
      expect(shortcut.type, AdaptiveShortcutType.route);
      expect(shortcut.title, 'VIT to Katpadi');
      expect(shortcut.status, AdaptiveShortcutStatus.suggested);
      expect(shortcut.isSuggested, isTrue);
      expect(shortcut.isAccepted, isFalse);
      expect(shortcut.isDismissed, isFalse);
      expect(shortcut.icon, Icons.alt_route_rounded);
      expect(shortcut.color, const Color(0xFF0284C7));
    });

    test('icon and color reflect shortcut type accurately', () {
      final types = {
        AdaptiveShortcutType.route: Icons.alt_route_rounded,
        AdaptiveShortcutType.liveTracking: Icons.my_location_rounded,
        AdaptiveShortcutType.ticketBooking: Icons.confirmation_number_outlined,
        AdaptiveShortcutType.savedPlace: Icons.star_rounded,
        AdaptiveShortcutType.corridorAlerts: Icons.notifications_active_outlined,
        AdaptiveShortcutType.safety: Icons.health_and_safety_outlined,
        AdaptiveShortcutType.feature: Icons.bolt_rounded,
      };

      for (final entry in types.entries) {
        final s = AdaptiveShortcut(
          id: 'test_${entry.key.name}',
          type: entry.key,
          title: 'Test',
          subtitle: 'Sub',
          actionType: 'action',
          lastUsed: DateTime.now(),
        );
        expect(s.icon, entry.value);
        expect(s.color, isNotNull);
      }
    });

    test('toJson and fromJson serialize and deserialize properly', () {
      final original = AdaptiveShortcut(
        id: 'shortcut_123',
        type: AdaptiveShortcutType.liveTracking,
        title: 'Track Bus 18B',
        subtitle: 'Tracked 5 times',
        actionType: 'track_bus',
        actionData: {'busId': '18B', 'routeId': 'vit-to-katpadi'},
        usageCount: 5,
        lastUsed: DateTime(2026, 9, 17, 12, 0),
        status: AdaptiveShortcutStatus.accepted,
      );

      final json = original.toJson();
      expect(json['id'], 'shortcut_123');
      expect(json['type'], 'liveTracking');
      expect(json['title'], 'Track Bus 18B');
      expect(json['actionType'], 'track_bus');
      expect(json['usageCount'], 5);
      expect(json['status'], 'accepted');

      final restored = AdaptiveShortcut.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.type, original.type);
      expect(restored.title, original.title);
      expect(restored.actionType, original.actionType);
      expect(restored.actionData['busId'], '18B');
      expect(restored.usageCount, original.usageCount);
      expect(restored.status, AdaptiveShortcutStatus.accepted);
      expect(restored.isAccepted, isTrue);
    });

    test('copyWith updates specified fields only', () {
      final s = AdaptiveShortcut(
        id: 's1',
        type: AdaptiveShortcutType.route,
        title: 'Original Title',
        subtitle: 'Original Subtitle',
        actionType: 'route_search',
        lastUsed: DateTime.now(),
      );

      final updated = s.copyWith(
        title: 'Updated Title',
        status: AdaptiveShortcutStatus.accepted,
      );

      expect(updated.id, 's1');
      expect(updated.title, 'Updated Title');
      expect(updated.subtitle, 'Original Subtitle');
      expect(updated.status, AdaptiveShortcutStatus.accepted);
    });
  });

  group('AdaptiveUiService Habit Engine & Governance', () {
    late AdaptiveUiService service;

    setUp(() {
      AppSettingsController.instance.updateAdaptiveUi(true);
      service = AdaptiveUiService.local();
    });

    tearDown(() {
      AppSettingsController.instance.updateAdaptiveUi(true);
    });

    test('initializes with default demonstration habits', () {
      expect(service.allShortcuts.isNotEmpty, isTrue);
      expect(service.visibleShortcuts.isNotEmpty, isTrue);
      expect(service.trackedPatternsCount, greaterThanOrEqualTo(3));

      final vitKatpadi = service.allShortcuts.firstWhere((s) => s.id == 'shortcut_vit_katpadi');
      expect(vitKatpadi.title, 'VIT → Katpadi Express');
      expect(vitKatpadi.type, AdaptiveShortcutType.route);
    });

    test('recordRouteSearch creates new shortcut upon reaching suggestionThreshold', () {
      service.resetAllLearningData();
      expect(service.visibleShortcuts.isEmpty, isTrue);

      // Threshold is 2
      service.suggestionThreshold = 2;

      // 1st search - should not trigger shortcut yet
      service.recordRouteSearch(
        originId: 'bagayam',
        destinationId: 'vellore-bus-stand',
        originName: 'Bagayam',
        destinationName: 'Old Bus Stand',
      );
      expect(service.visibleShortcuts.isEmpty, isTrue);

      // 2nd search - triggers suggestion
      service.recordRouteSearch(
        originId: 'bagayam',
        destinationId: 'vellore-bus-stand',
        originName: 'Bagayam',
        destinationName: 'Old Bus Stand',
      );
      expect(service.visibleShortcuts.length, 1);
      final shortcut = service.visibleShortcuts.first;
      expect(shortcut.title, 'Bagayam → Old Bus Stand');
      expect(shortcut.type, AdaptiveShortcutType.route);
      expect(shortcut.usageCount, 2);
      expect(shortcut.isSuggested, isTrue);
    });

    test('recordTicketBooking creates booking shortcut and updates frequency', () {
      service.resetAllLearningData();
      service.suggestionThreshold = 2;

      service.recordTicketBooking(
        originName: 'VIT Main Gate',
        destinationName: 'CMC Hospital',
        busId: '21A',
        routeId: 'vit-to-cmc',
      );
      expect(service.visibleShortcuts.isEmpty, isTrue);

      service.recordTicketBooking(
        originName: 'VIT Main Gate',
        destinationName: 'CMC Hospital',
        busId: '21A',
        routeId: 'vit-to-cmc',
      );
      expect(service.visibleShortcuts.length, 1);
      final shortcut = service.visibleShortcuts.first;
      expect(shortcut.type, AdaptiveShortcutType.ticketBooking);
      expect(shortcut.title, contains('Quick Book'));
      expect(shortcut.actionData['busId'], '21A');
    });

    test('recordLiveTracking creates live tracking shortcut', () {
      service.resetAllLearningData();
      service.suggestionThreshold = 2;

      service.recordLiveTracking(busId: '10A', routeId: 'katpadi-circular');
      service.recordLiveTracking(busId: '10A', routeId: 'katpadi-circular');

      expect(service.visibleShortcuts.length, 1);
      final shortcut = service.visibleShortcuts.first;
      expect(shortcut.type, AdaptiveShortcutType.liveTracking);
      expect(shortcut.title, 'Live Tracker • Bus 10A');
      expect(shortcut.actionData['busId'], '10A');
    });

    test('recordGenericEvent creates feature shortcut', () {
      service.resetAllLearningData();
      service.suggestionThreshold = 2;

      service.recordGenericEvent(
        actionType: 'voice_assistant',
        title: 'Voice Copilot',
        subtitle: 'Hands-free navigation',
        type: AdaptiveShortcutType.feature,
      );
      service.recordGenericEvent(
        actionType: 'voice_assistant',
        title: 'Voice Copilot',
        subtitle: 'Hands-free navigation',
        type: AdaptiveShortcutType.feature,
      );

      expect(service.visibleShortcuts.length, 1);
      final shortcut = service.visibleShortcuts.first;
      expect(shortcut.type, AdaptiveShortcutType.feature);
      expect(shortcut.title, 'Voice Copilot');
    });

    test('acceptShortcut pins the shortcut and updates status', () {
      final suggested = service.pendingSuggestions.first;
      service.acceptShortcut(suggested.id);

      final accepted = service.allShortcuts.firstWhere((s) => s.id == suggested.id);
      expect(accepted.isAccepted, isTrue);
      expect(accepted.subtitle, 'Pinned Shortcut');
      expect(service.acceptedShortcuts.map((s) => s.id), contains(suggested.id));
    });

    test('dismissShortcut removes shortcut from visible list and marks dismissed', () {
      final suggested = service.pendingSuggestions.first;
      service.dismissShortcut(suggested.id);

      final dismissed = service.allShortcuts.firstWhere((s) => s.id == suggested.id);
      expect(dismissed.isDismissed, isTrue);
      expect(service.visibleShortcuts.map((s) => s.id), isNot(contains(suggested.id)));
    });

    test('removeShortcut completely deletes shortcut', () {
      final first = service.allShortcuts.first;
      final initialCount = service.allShortcuts.length;
      service.removeShortcut(first.id);

      expect(service.allShortcuts.length, initialCount - 1);
      expect(service.allShortcuts.map((s) => s.id), isNot(contains(first.id)));
    });

    test('resetAllLearningData wipes all frequencies and shortcuts', () {
      expect(service.allShortcuts.isNotEmpty, isTrue);
      service.resetAllLearningData();

      expect(service.allShortcuts.isEmpty, isTrue);
      expect(service.visibleShortcuts.isEmpty, isTrue);
      expect(service.trackedPatternsCount, 0);
    });

    test('master toggle in AppSettingsController suppresses visible shortcuts and tracking', () {
      expect(service.visibleShortcuts.isNotEmpty, isTrue);

      // Disable Adaptive UI
      AppSettingsController.instance.updateAdaptiveUi(false);
      expect(service.visibleShortcuts.isEmpty, isTrue);

      // Further events ignored while disabled
      service.recordRouteSearch(
        originId: 'stop_a',
        destinationId: 'stop_b',
        originName: 'Stop A',
        destinationName: 'Stop B',
      );
      expect(service.allShortcuts.any((s) => s.id.contains('stop_a')), isFalse);

      // Re-enable
      AppSettingsController.instance.updateAdaptiveUi(true);
      expect(service.visibleShortcuts.isNotEmpty, isTrue);
    });

    test('hydrate and snapshot round-trip with LocalJsonStore', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await LocalJsonStore.openScoped(
        namespace: 'test_adaptive_${DateTime.now().millisecondsSinceEpoch}',
      );

      final testService = AdaptiveUiService.local();
      testService.seedDemonstrationHabits();
      await testService.hydrate(store);

      expect(testService.visibleShortcuts.isNotEmpty, isTrue);

      // Add a custom route and check persistence
      testService.recordRouteSearch(
        originId: 'custom1',
        destinationId: 'custom2',
        originName: 'Custom 1',
        destinationName: 'Custom 2',
      );
      testService.recordRouteSearch(
        originId: 'custom1',
        destinationId: 'custom2',
        originName: 'Custom 1',
        destinationName: 'Custom 2',
      );

      final secondService = AdaptiveUiService.local();
      await secondService.hydrate(store);
      expect(secondService.allShortcuts.any((s) => s.title == 'Custom 1 → Custom 2'), isTrue);
    });
  });
}
