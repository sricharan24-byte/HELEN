import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busbuddy/data/models/home_screen_item.dart';

void main() {
  group('HomeScreenItem Model', () {
    test('defaultItems contains all 9 required core home screen components', () {
      final items = HomeScreenItem.defaultItems;
      expect(items.length, 9);

      final ids = items.map((e) => e.id).toList();
      expect(ids, contains(HomeScreenItem.idRouteSearch));
      expect(ids, contains(HomeScreenItem.idMyJourney));
      expect(ids, contains(HomeScreenItem.idMyTickets));
      expect(ids, contains(HomeScreenItem.idSavedPlaces));
      expect(ids, contains(HomeScreenItem.idVoiceAssistant));
      expect(ids, contains(HomeScreenItem.idLiveTracking));
      expect(ids, contains(HomeScreenItem.idAlerts));
      expect(ids, contains(HomeScreenItem.idSafety));
      expect(ids, contains(HomeScreenItem.idSettings));
    });

    test('all default items have valid non-empty titles, subtitles, icons, and colors', () {
      for (final item in HomeScreenItem.defaultItems) {
        expect(item.id.isNotEmpty, isTrue);
        expect(item.title.isNotEmpty, isTrue);
        expect(item.subtitle.isNotEmpty, isTrue);
        expect(item.isVisible, isTrue);
        expect(item.icon, isNotNull);
        expect(item.color, isNotNull);
      }
    });

    test('toJson and fromJson serialize and deserialize accurately', () {
      const original = HomeScreenItem(
        id: HomeScreenItem.idRouteSearch,
        title: 'Find a Place',
        subtitle: 'Search destination, find buses and book tickets',
        isVisible: false,
      );

      final json = original.toJson();
      expect(json['id'], HomeScreenItem.idRouteSearch);
      expect(json['title'], 'Find a Place');
      expect(json['subtitle'], 'Search destination, find buses and book tickets');
      expect(json['isVisible'], false);

      final restored = HomeScreenItem.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.subtitle, original.subtitle);
      expect(restored.isVisible, original.isVisible);
    });

    test('fromJson falls back to defaults when title or subtitle are missing', () {
      final item = HomeScreenItem.fromJson({'id': HomeScreenItem.idLiveTracking});
      expect(item.id, HomeScreenItem.idLiveTracking);
      expect(item.title, 'Live Bus Map');
      expect(item.subtitle, 'Real-time bus location & speed');
      expect(item.isVisible, isTrue);
    });

    test('copyWith updates specified fields only', () {
      const original = HomeScreenItem(
        id: HomeScreenItem.idSafety,
        title: 'Emergency SOS',
        subtitle: 'Share location with contacts',
        isVisible: true,
      );

      final updated = original.copyWith(isVisible: false, title: 'Emergency Assistance');
      expect(updated.id, original.id);
      expect(updated.title, 'Emergency Assistance');
      expect(updated.subtitle, original.subtitle);
      expect(updated.isVisible, false);
    });

    test('equality and hashCode evaluate properly', () {
      const a = HomeScreenItem(
        id: 'test',
        title: 'Test',
        subtitle: 'Sub',
        isVisible: true,
      );
      const b = HomeScreenItem(
        id: 'test',
        title: 'Test',
        subtitle: 'Sub',
        isVisible: true,
      );
      const c = HomeScreenItem(
        id: 'test',
        title: 'Test',
        subtitle: 'Sub',
        isVisible: false,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });
}
