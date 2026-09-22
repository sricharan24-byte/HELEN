import 'package:flutter_test/flutter_test.dart';
import 'package:busbuddy/data/models/transport_models.dart';
import 'package:busbuddy/domain/transit/entities/telemetry_state.dart';

void main() {
  group('Live Telemetry Ordering & Freshness Tests (BUS-P1-01)', () {
    const busId = 'BUS-18B';
    const routeId = 'route-18b';

    BusLocation makeTick({
      required int sequence,
      int generation = 0,
      String bus = busId,
      String route = routeId,
      DateTime? timestamp,
      double speed = 30.0,
      int eta = 5,
    }) {
      return BusLocation(
        busId: bus,
        routeId: route,
        latitude: 12.97,
        longitude: 79.16,
        speedKmh: speed,
        nextStopId: 'stop-katpadi',
        nextStopName: 'Katpadi Railway Station',
        etaMinutes: eta,
        timestamp: timestamp ?? DateTime.utc(2026, 9, 20, 10, 0, 0),
        progressPercentage: 0.5,
        sequence: sequence,
        generation: generation,
        accuracyMeters: 4.5,
        isSimulated: true,
        receivedTimestamp: timestamp ?? DateTime.utc(2026, 9, 20, 10, 0, 0),
      );
    }

    test('initial state begins at loading without fake live defaults', () {
      final state = TelemetrySnapshot.initial();
      expect(state.isLoading, isTrue);
      expect(state.isLive, isFalse);
      expect(state.location, isNull);
      expect(state.lastSequence, equals(-1));
    });

    test('accepts sequential forward ticks and transitions to live', () {
      var state = TelemetrySnapshot.initial();
      final tick10 = makeTick(sequence: 10);
      state = TelemetryReducer.reduceLocation(
        current: state,
        incoming: tick10,
        expectedBusId: busId,
        expectedRouteId: routeId,
      );

      expect(state.isLive, isTrue);
      expect(state.lastSequence, equals(10));
      expect(state.location?.speedKmh, equals(30.0));
    });

    test('rejects out-of-order tick 11 arriving after tick 12 and duplicate tick 12', () {
      var state = TelemetrySnapshot.initial();

      // Tick 10
      state = TelemetryReducer.reduceLocation(
        current: state,
        incoming: makeTick(sequence: 10, speed: 25.0),
        expectedBusId: busId,
        expectedRouteId: routeId,
      );
      expect(state.lastSequence, equals(10));

      // Tick 12 (delivered before 11 due to network race)
      state = TelemetryReducer.reduceLocation(
        current: state,
        incoming: makeTick(sequence: 12, speed: 35.0),
        expectedBusId: busId,
        expectedRouteId: routeId,
      );
      expect(state.lastSequence, equals(12));
      expect(state.location?.speedKmh, equals(35.0));

      // Out-of-order Tick 11 arrives late -> Must be rejected, state should NOT regress
      final stateBefore11 = state;
      state = TelemetryReducer.reduceLocation(
        current: state,
        incoming: makeTick(sequence: 11, speed: 28.0),
        expectedBusId: busId,
        expectedRouteId: routeId,
      );
      expect(state.lastSequence, equals(12));
      expect(state.location?.speedKmh, equals(35.0));
      expect(identical(state, stateBefore11), isTrue);

      // Duplicate Tick 12 arrives -> Must be rejected
      state = TelemetryReducer.reduceLocation(
        current: state,
        incoming: makeTick(sequence: 12, speed: 35.0),
        expectedBusId: busId,
        expectedRouteId: routeId,
      );
      expect(state.lastSequence, equals(12));
      expect(identical(state, stateBefore11), isTrue);
    });

    test('rejects alien route and bus telemetry packets', () {
      var state = TelemetrySnapshot.initial();
      state = TelemetryReducer.reduceLocation(
        current: state,
        incoming: makeTick(sequence: 1),
        expectedBusId: busId,
        expectedRouteId: routeId,
      );
      expect(state.lastSequence, equals(1));

      // Incoming packet from another bus
      final otherBusTick = makeTick(sequence: 50, bus: 'BUS-99X');
      state = TelemetryReducer.reduceLocation(
        current: state,
        incoming: otherBusTick,
        expectedBusId: busId,
        expectedRouteId: routeId,
      );
      expect(state.lastSequence, equals(1));

      // Incoming packet from another route
      final otherRouteTick = makeTick(sequence: 50, route: 'route-old');
      state = TelemetryReducer.reduceLocation(
        current: state,
        incoming: otherRouteTick,
        expectedBusId: busId,
        expectedRouteId: routeId,
      );
      expect(state.lastSequence, equals(1));
    });

    test('reconnect generation reset resets sequence bounds and accepts fresh generation packets', () {
      var state = TelemetrySnapshot.initial(generation: 0);

      state = TelemetryReducer.reduceLocation(
        current: state,
        incoming: makeTick(sequence: 99, generation: 0),
        expectedBusId: busId,
        expectedRouteId: routeId,
      );
      expect(state.generation, equals(0));
      expect(state.lastSequence, equals(99));

      // Reconnect increments generation to 1, starting sequence from 1
      final reconnectTick = makeTick(sequence: 1, generation: 1, speed: 32.0);
      state = TelemetryReducer.reduceLocation(
        current: state,
        incoming: reconnectTick,
        expectedBusId: busId,
        expectedRouteId: routeId,
      );

      expect(state.generation, equals(1));
      expect(state.lastSequence, equals(1));
      expect(state.location?.speedKmh, equals(32.0));

      // Stale generation 0 packets are now rejected even if sequence was high
      final oldGenTick = makeTick(sequence: 150, generation: 0);
      state = TelemetryReducer.reduceLocation(
        current: state,
        incoming: oldGenTick,
        expectedBusId: busId,
        expectedRouteId: routeId,
      );
      expect(state.generation, equals(1));
      expect(state.lastSequence, equals(1));
    });

    test('freshness transitions deterministically to stale at 15s and offline at 60s', () {
      final t0 = DateTime.utc(2026, 9, 20, 10, 0, 0);
      var state = TelemetrySnapshot.initial();

      state = TelemetryReducer.reduceLocation(
        current: state,
        incoming: makeTick(sequence: 1),
        expectedBusId: busId,
        expectedRouteId: routeId,
        nowUtc: t0,
      );
      expect(state.isLive, isTrue);

      // Check after 5 seconds: still live
      state = TelemetryReducer.checkFreshness(
        current: state,
        nowUtc: t0.add(const Duration(seconds: 5)),
      );
      expect(state.isLive, isTrue);

      // Check after 16 seconds: becomes stale
      state = TelemetryReducer.checkFreshness(
        current: state,
        nowUtc: t0.add(const Duration(seconds: 16)),
      );
      expect(state.isStale, isTrue);
      expect(state.staleSince, equals(t0.add(const Duration(seconds: 16))));

      // Check after 65 seconds: becomes offline
      state = TelemetryReducer.checkFreshness(
        current: state,
        nowUtc: t0.add(const Duration(seconds: 65)),
      );
      expect(state.isOffline, isTrue);

      // Recovery: fresh tick received brings it right back to live
      state = TelemetryReducer.reduceLocation(
        current: state,
        incoming: makeTick(sequence: 2),
        expectedBusId: busId,
        expectedRouteId: routeId,
        nowUtc: t0.add(const Duration(seconds: 70)),
      );
      expect(state.isLive, isTrue);
      expect(state.lastSequence, equals(2));
    });
  });
}
