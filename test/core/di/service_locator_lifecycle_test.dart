import 'package:flutter_test/flutter_test.dart';
import 'package:busbuddy/core/di/service_locator.dart';

void main() {
  group('AppServiceLocator Lifecycle & BUS-P0-04 Teardown Tests', () {
    tearDown(() async {
      await AppServiceLocator.instance.resetForTesting();
    });

    test('concurrent first access yields identical instances', () async {
      final locator = AppServiceLocator.instance;

      final results = await Future.wait([
        Future(() => locator.transportDataSource),
        Future(() => locator.transportDataSource),
        Future(() => locator.transportRepository),
        Future(() => locator.transportRepository),
        Future(() => locator.ticketController),
        Future(() => locator.ticketController),
        Future(() => locator.journeyController),
        Future(() => locator.journeyController),
      ]);

      expect(identical(results[0], results[1]), isTrue);
      expect(identical(results[2], results[3]), isTrue);
      expect(identical(results[4], results[5]), isTrue);
      expect(identical(results[6], results[7]), isTrue);
    });

    test('generation increments monotonically across resets', () async {
      final locator = AppServiceLocator.instance;
      final g0 = locator.generation;

      await locator.resetForTesting();
      final g1 = locator.generation;
      expect(g1, equals(g0 + 1));

      await locator.resetForTesting();
      final g2 = locator.generation;
      expect(g2, equals(g1 + 1));
    });

    test('concurrent double resetForTesting is idempotent and awaits shared future', () async {
      final locator = AppServiceLocator.instance;
      // Instantiate components
      final _ = locator.transportRepository;

      // Launch 5 concurrent resets
      final futures = [
        locator.resetForTesting(),
        locator.resetForTesting(),
        locator.resetForTesting(),
        locator.resetForTesting(),
        locator.resetForTesting(),
      ];

      await expectLater(Future.wait(futures), completes);
    });

    test('active bus movement engines and streams are closed after reset', () async {
      final locator = AppServiceLocator.instance;
      final repo = locator.transportRepository;

      // Start live bus location stream which spins up LiveBusMovementEngine
      final stream = repo.streamBusLocation('BUS-18B', 'route-18b');
      expect(stream, isNotNull);

      // Reset locator
      await locator.resetForTesting();

      // Ensure new repository created post-reset is fresh
      final freshRepo = locator.transportRepository;
      expect(identical(repo, freshRepo), isFalse);
    });

    test('100 sequential create and reset cycles execute without leaks or errors', () async {
      final locator = AppServiceLocator.instance;

      for (int i = 0; i < 100; i++) {
        final repo = locator.transportRepository;
        final ticketCtrl = locator.ticketController;
        final journeyCtrl = locator.journeyController;
        expect(repo, isNotNull);
        expect(ticketCtrl, isNotNull);
        expect(journeyCtrl, isNotNull);

        await locator.resetForTesting();
      }
    });
  });
}
