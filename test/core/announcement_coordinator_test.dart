import 'package:flutter_test/flutter_test.dart';
import 'package:busbuddy/core/a11y/announcement_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final coordinator = AnnouncementCoordinator.instance;

  setUp(coordinator.reset);

  tearDown(coordinator.reset);

  group('AnnouncementCoordinator (Astra Step 2.2)', () {
    test('updates visualStatusText and returns true for valid message', () {
      final announced = coordinator.announce('Bus 18B arriving in 4 minutes');
      expect(announced, isTrue);
      expect(coordinator.visualStatusText.value, 'Bus 18B arriving in 4 minutes');
    });

    test('deduplicates identical message within debounce window', () {
      final first = coordinator.announce('Next stop Green Circle');
      expect(first, isTrue);

      final second = coordinator.announce('Next stop Green Circle');
      expect(second, isFalse); // Suppressed within 3s window
    });

    test('urgent priority bypasses debounce window', () {
      final first = coordinator.announce(
        'Emergency alert triggered',
        priority: AnnouncementPriority.urgent,
      );
      expect(first, isTrue);

      final second = coordinator.announce(
        'Emergency alert triggered',
        priority: AnnouncementPriority.urgent,
      );
      expect(second, isTrue); // Urgent bypasses deduplication
    });

    test('suppresses announcements when audio assistant is actively speaking', () {
      coordinator.isAudioPlaying = true;

      final normal = coordinator.announce('Arriving at Katpadi Station');
      expect(normal, isFalse);

      final urgent = coordinator.announce(
        'Emergency alert triggered',
        priority: AnnouncementPriority.urgent,
      );
      expect(urgent, isTrue); // Urgent still breaks through
    });

    test('suppresses announcements from non-active routes', () {
      coordinator.setActiveRoute('route-18b');

      final wrongRoute = coordinator.announce(
        'Bus 12A arriving',
        routeId: 'route-12a',
      );
      expect(wrongRoute, isFalse);

      final rightRoute = coordinator.announce(
        'Bus 18B approaching',
        routeId: 'route-18b',
      );
      expect(rightRoute, isTrue);
    });

    test('suppresses spoken announcement when speech is disabled, but still updates visual text', () {
      coordinator.isSpeechEnabled = false;

      final announced = coordinator.announce('Approaching stop');
      expect(announced, isFalse);
      expect(coordinator.visualStatusText.value, 'Approaching stop'); // Visual accessible fallback preserved
    });

    test('vocalizes announcement via speechSpeaker when speech is enabled', () {
      final spoken = <String>[];
      coordinator.speechSpeaker = spoken.add;

      final success = coordinator.announce('Next stop: Katpadi Station');
      expect(success, isTrue);
      expect(spoken, ['Next stop: Katpadi Station']);
    });

    test('announceEtaUpdate announces stop transitions and arrival', () {
      final spoken = <String>[];
      coordinator.speechSpeaker = spoken.add;

      // Stop transition with 5 minutes ETA
      final first = coordinator.announceEtaUpdate(
        routeId: 'route-1',
        stopName: 'Green Circle',
        etaMinutes: 5,
      );
      expect(first, isTrue);
      expect(spoken.last, 'Next stop Green Circle in 5 minutes.');

      // Approaching with 1 min ETA
      final second = coordinator.announceEtaUpdate(
        routeId: 'route-1',
        stopName: 'Green Circle',
        etaMinutes: 1,
      );
      expect(second, isTrue);
      expect(spoken.last, 'Bus arriving at Green Circle now.');
    });
  });
}
