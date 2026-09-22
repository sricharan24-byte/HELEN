import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busbuddy/core/a11y/announcement_coordinator.dart';

void main() {
  group('AnnouncementCoordinator Audio Arbiter Tests (BUS-P1-03)', () {
    late AnnouncementCoordinator coordinator;
    final deliveredAnnouncements = <({String message, TextDirection direction})>[];

    setUp(() {
      coordinator = AnnouncementCoordinator.instance;
      coordinator.reset();
      deliveredAnnouncements.clear();
      coordinator.semanticsAnnounceHandler = (msg, dir) {
        deliveredAnnouncements.add((message: msg, direction: dir));
        return true;
      };
    });

    tearDown(() {
      coordinator.reset();
    });

    test('inactive route announcements do not update visual text or announce', () {
      final scope = coordinator.registerScope('route-active');

      final announced = coordinator.announce(
        'Bus 12A arriving at Green Circle',
        routeId: 'route-inactive',
      );

      expect(announced, isFalse);
      expect(coordinator.visualStatusText.value, isEmpty);
      expect(deliveredAnnouncements, isEmpty);

      scope.dispose();
    });

    test('active route announcements update visual text and announce immediately', () {
      final scope = coordinator.registerScope('route-active');

      final announced = coordinator.announce(
        'Bus 18B arriving at VIT Main Gate',
        routeId: 'route-active',
      );

      expect(announced, isTrue);
      expect(coordinator.visualStatusText.value, equals('Bus 18B arriving at VIT Main Gate'));
      expect(deliveredAnnouncements.length, equals(1));
      expect(deliveredAnnouncements.first.message, equals('Bus 18B arriving at VIT Main Gate'));

      scope.dispose();
    });

    test('scope disposal clears active route scope and prevents further leaks', () {
      final scope = coordinator.registerScope('route-temp');
      expect(scope.isDisposed, isFalse);

      scope.dispose();
      expect(scope.isDisposed, isTrue);

      // Now route-temp is no longer the active registered scope
      final token2 = coordinator.registerScope('route-fresh');
      final announced = coordinator.announce('Old route update', routeId: 'route-temp');
      expect(announced, isFalse);

      token2.dispose();
    });

    test('semantic ETA debounces rapid 2-second ticks with same stop and minutes', () {
      coordinator.registerScope('route-18b');

      // First tick: announces
      final t1 = coordinator.announceEtaUpdate(
        routeId: 'route-18b',
        stopName: 'Green Circle',
        etaMinutes: 4,
      );
      expect(t1, isTrue);
      expect(deliveredAnnouncements.length, equals(1));

      // Rapid tick 2 seconds later with same ETA: suppressed
      final t2 = coordinator.announceEtaUpdate(
        routeId: 'route-18b',
        stopName: 'Green Circle',
        etaMinutes: 4,
      );
      expect(t2, isFalse);
      expect(deliveredAnnouncements.length, equals(1));

      // Meaningful update (ETA changed to 3 min): announces
      final t3 = coordinator.announceEtaUpdate(
        routeId: 'route-18b',
        stopName: 'Green Circle',
        etaMinutes: 3,
      );
      expect(t3, isTrue);
      expect(deliveredAnnouncements.length, equals(2));
    });

    test('queues normal/high announcements during assistant audio playback and drains when audio ends', () {
      coordinator.setAudioPlaying(true);

      final announced = coordinator.announce(
        'Approaching Katpadi Station',
        priority: AnnouncementPriority.high,
      );
      // Suppressed from immediate speech to avoid collision, placed in bounded queue
      expect(announced, isFalse);
      expect(deliveredAnnouncements, isEmpty);
      expect(coordinator.queuedAnnouncements.length, equals(1));

      // Assistant finishes speaking: queue drains and dispatches high-priority message
      coordinator.setAudioPlaying(false);
      expect(deliveredAnnouncements.length, equals(1));
      expect(deliveredAnnouncements.first.message, equals('Approaching Katpadi Station'));
      expect(coordinator.queuedAnnouncements, isEmpty);
    });

    test('urgent announcements interrupt assistant audio and fire immediately', () {
      coordinator.setAudioPlaying(true);
      bool urgentTriggered = false;
      coordinator.onUrgentAlertTriggered = () {
        urgentTriggered = true;
      };

      final announced = coordinator.announce(
        'EMERGENCY: SOS broadcast triggered',
        priority: AnnouncementPriority.urgent,
      );

      expect(announced, isTrue);
      expect(urgentTriggered, isTrue);
      expect(deliveredAnnouncements.length, equals(1));
      expect(deliveredAnnouncements.first.message, contains('EMERGENCY'));
    });

    test('respects configurable text direction including RTL', () {
      coordinator.announce(
        'Notice in RTL',
        textDirection: TextDirection.rtl,
      );

      expect(deliveredAnnouncements.length, equals(1));
      expect(deliveredAnnouncements.first.direction, equals(TextDirection.rtl));
    });
  });
}
