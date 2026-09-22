import 'dart:async';

import '../../core/di/async_disposable.dart';
import '../../domain/transit/entities/telemetry_state.dart';
import '../datasources/live_bus_movement_engine.dart';
import '../datasources/local_transport_data_source.dart';
import '../models/transport_models.dart';

/// Abstraction for the transport data layer.
abstract class TransportRepository {
  /// Search stops by name or area. An empty query returns all stops.
  List<Stop> findStops(String query);

  /// Find routes where [originId] appears before [destinationId].
  List<Route> findRoutes({
    required String originId,
    required String destinationId,
  });

  /// Look up a single stop by id; returns `null` if unknown.
  Stop? getStop(String stopId);

  /// List all available routes.
  List<Route> get allRoutes;

  /// Stream live GPS bus location updates for a specific bus & route.
  Stream<BusLocation> streamBusLocation(String busId, String routeId);

  /// Stream ordered, freshness-aware telemetry snapshots per Astra BUS-P1-01.
  Stream<TelemetrySnapshot> streamTelemetry(String busId, String routeId);
}

/// Concrete [TransportRepository] backed by [LocalTransportDataSource].
class LocalTransportRepository implements TransportRepository, AsyncDisposable {
  LocalTransportRepository({required this._dataSource});

  final LocalTransportDataSource _dataSource;
  final Map<String, LiveBusMovementEngine> _activeEngines = {};

  @override
  List<Stop> findStops(String query) {
    final trimmed = query.trim();
    return _dataSource.searchStops(trimmed);
  }

  @override
  List<Route> findRoutes({
    required String originId,
    required String destinationId,
  }) {
    final results = <Route>[];
    for (final route in _dataSource.allRoutes) {
      if (route.stopsBetween(originId, destinationId).isNotEmpty) {
        results.add(route);
      }
    }
    return results;
  }

  @override
  Stop? getStop(String stopId) => _dataSource.stopById(stopId);

  @override
  List<Route> get allRoutes => _dataSource.allRoutes;

  @override
  Stream<BusLocation> streamBusLocation(String busId, String routeId) {
    final key = '$busId::$routeId';
    if (!_activeEngines.containsKey(key)) {
      final all = _dataSource.allRoutes;
      final targetRoute = all.firstWhere(
        (r) => r.id == routeId,
        orElse: () => all.isNotEmpty
            ? all.first
            : const Route(
                id: 'default',
                displayName: 'VIT Katpadi Corridor',
                direction: 'Outbound',
                orderedStopIds: [],
              ),
      );
      _activeEngines[key] = LiveBusMovementEngine(
        busId: busId,
        route: targetRoute,
        dataSource: _dataSource,
      );
    }
    return _activeEngines[key]!.locationStream;
  }

  @override
  Stream<TelemetrySnapshot> streamTelemetry(String busId, String routeId) {
    // Sink lifetime is tied to the returned stream's subscription: resources
    // are torn down in onCancel below (BUS-P0.2 disposal contract).
    // ignore: close_sinks
    late StreamController<TelemetrySnapshot> controller;
    StreamSubscription<BusLocation>? locationSub;
    Timer? freshnessTimer;
    var state = TelemetrySnapshot.initial();

    void checkFreshness() {
      final updated = TelemetryReducer.checkFreshness(
        current: state,
        nowUtc: DateTime.now().toUtc(),
      );
      if (updated.freshness != state.freshness) {
        state = updated;
        if (!controller.isClosed) {
          controller.add(state);
        }
      }
    }

    controller = StreamController<TelemetrySnapshot>.broadcast(
      onListen: () {
        controller.add(state);
        locationSub = streamBusLocation(busId, routeId).listen(
          (loc) {
            final next = TelemetryReducer.reduceLocation(
              current: state,
              incoming: loc,
              expectedBusId: busId,
              expectedRouteId: routeId,
            );
            if (next != state) {
              state = next;
              if (!controller.isClosed) {
                controller.add(state);
              }
            }
          },
          onError: (Object err) {
            state = state.copyWith(
              freshness: TelemetryFreshness.error,
              errorMessage: err.toString(),
            );
            if (!controller.isClosed) {
              controller.add(state);
            }
          },
        );

        freshnessTimer = Timer.periodic(
          const Duration(seconds: 2),
          (_) => checkFreshness(),
        );
      },
      onCancel: () {
        unawaited(locationSub?.cancel());
        freshnessTimer?.cancel();
      },
    );

    return controller.stream;
  }

  /// Closes and cleans up all active movement simulation engines per Astra P0.2.
  @override
  Future<void> dispose() async {
    for (final engine in _activeEngines.values) {
      await engine.dispose();
    }
    _activeEngines.clear();
  }
}
