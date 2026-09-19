import 'package:flutter_test/flutter_test.dart';
import 'package:busbuddy/core/di/service_locator.dart';
import 'package:busbuddy/data/datasources/local_transport_data_source.dart';
import 'package:busbuddy/data/repositories/transport_repository.dart';

void main() {
  group('AppServiceLocator', () {
    tearDown(() async {
      await AppServiceLocator.instance.resetForTesting();
    });

    test('returns consistent singleton instances', () {
      final locator = AppServiceLocator.instance;

      final ds1 = locator.transportDataSource;
      final ds2 = locator.transportDataSource;
      expect(identical(ds1, ds2), isTrue);

      final repo1 = locator.transportRepository;
      final repo2 = locator.transportRepository;
      expect(identical(repo1, repo2), isTrue);

      final ticketCtrl1 = locator.ticketController;
      final ticketCtrl2 = locator.ticketController;
      expect(identical(ticketCtrl1, ticketCtrl2), isTrue);

      final journeyCtrl1 = locator.journeyController;
      final journeyCtrl2 = locator.journeyController;
      expect(identical(journeyCtrl1, journeyCtrl2), isTrue);
    });

    test('supports overriding and resetting for test isolation with engine disposal', () async {
      final locator = AppServiceLocator.instance;
      final customDs = LocalTransportDataSource();
      final customRepo = LocalTransportRepository(dataSource: customDs);

      locator.overrideForTesting(
        dataSource: customDs,
        transportRepo: customRepo,
      );

      expect(identical(locator.transportDataSource, customDs), isTrue);
      expect(identical(locator.transportRepository, customRepo), isTrue);

      // Start a stream engine
      final stream = customRepo.streamBusLocation('BUS-18B', 'route-18b');
      expect(stream, isNotNull);

      // Async teardown closes all engines cleanly per Astra P0.2
      await locator.resetForTesting();

      expect(identical(locator.transportDataSource, customDs), isFalse);
      expect(identical(locator.transportRepository, customRepo), isFalse);
    });
  });
}
