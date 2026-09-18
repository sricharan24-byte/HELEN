import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/data/datasources/live_bus_movement_engine.dart';
import 'package:busbuddy/data/datasources/local_transport_data_source.dart';
import 'package:busbuddy/data/models/transport_models.dart';

void main() {
  group('LiveBusMovementEngine', () {
    test('emits valid BusLocation updates with GPS coordinates, speed, and ETA', () async {
      final dataSource = LocalTransportDataSource();
      final route = dataSource.allRoutes.first;

      final engine = LiveBusMovementEngine(
        busId: 'TN-23-BUS-42',
        route: route,
        dataSource: dataSource,
      );

      final location = await engine.locationStream.first;

      expect(location.busId, 'TN-23-BUS-42');
      expect(location.routeId, route.id);
      expect(location.latitude, greaterThan(12.0));
      expect(location.longitude, greaterThan(78.0));
      expect(location.speedKmh, greaterThanOrEqualTo(20.0));
      expect(location.etaMinutes, greaterThan(0));
      expect(location.nextStopName.isNotEmpty, isTrue);

      engine.dispose();
    });

    test('handles empty stops or empty stop anchors gracefully without crashing', () async {
      final dataSource = LocalTransportDataSource();
      const emptyRoute = Route(
        id: 'empty-route',
        displayName: 'Empty Route',
        direction: 'North',
        orderedStopIds: [],
      );

      final engine = LiveBusMovementEngine(
        busId: 'TN-23-EMPTY',
        route: emptyRoute,
        dataSource: dataSource,
      );

      expect(engine.locationStream, isNotNull);
      engine.dispose();
    });
  });
}
