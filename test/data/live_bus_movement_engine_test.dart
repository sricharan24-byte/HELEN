import 'dart:async';
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

      unawaited(engine.dispose());
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
      unawaited(engine.dispose());
    });

    test('terminates at the destination: terminal position then stream close, no loop', () async {
      final dataSource = LocalTransportDataSource();
      final route = dataSource.allRoutes.first;

      final engine = LiveBusMovementEngine(
        busId: 'TN-23-BUS-99',
        route: route,
        dataSource: dataSource,
        journeyTicks: 3,
        tickInterval: const Duration(milliseconds: 10),
      );

      final emissions = await engine.locationStream.toList();

      expect(emissions.length, greaterThanOrEqualTo(2));
      final terminal = emissions.last;
      expect(terminal.progressPercentage, 1.0);
      expect(terminal.etaMinutes, 0);
      expect(terminal.speedKmh, 0.0);
      // Never loops back: progress is monotonic.
      for (int i = 1; i < emissions.length; i++) {
        expect(
          emissions[i].progressPercentage,
          greaterThanOrEqualTo(emissions[i - 1].progressPercentage),
        );
      }
      expect(engine.isCompleted, isTrue);
      unawaited(engine.dispose());
    });

    test('starts at the boarding stop and ends at the alighting stop', () async {
      final dataSource = LocalTransportDataSource();
      final route = dataSource.allRoutes.firstWhere(
        (r) => r.orderedStopIds.length >= 3,
      );
      final boarding = dataSource.stopById(route.orderedStopIds[1])!;
      final alighting = dataSource.stopById(route.orderedStopIds.last)!;

      final engine = LiveBusMovementEngine(
        busId: 'TN-23-BUS-100',
        route: route,
        dataSource: dataSource,
        originStopId: boarding.id,
        destinationStopId: alighting.id,
        journeyTicks: 2,
        tickInterval: const Duration(milliseconds: 10),
      );

      final emissions = await engine.locationStream.toList();

      final first = emissions.first;
      expect(first.latitude, closeTo(boarding.latitude!, 0.005));
      expect(first.longitude, closeTo(boarding.longitude!, 0.005));

      final terminal = emissions.last;
      expect(terminal.nextStopId, alighting.id);
      expect(terminal.latitude, closeTo(alighting.latitude!, 0.005));
      expect(terminal.longitude, closeTo(alighting.longitude!, 0.005));
      expect(terminal.progressPercentage, 1.0);
      unawaited(engine.dispose());
    });
  });
}
