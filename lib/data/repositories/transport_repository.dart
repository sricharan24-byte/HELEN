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
}

/// Concrete [TransportRepository] backed by [LocalTransportDataSource].
class LocalTransportRepository implements TransportRepository {
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
      final originIdx = route.orderedStopIds.indexOf(originId);
      final destIdx = route.orderedStopIds.indexOf(destinationId);
      if (originIdx != -1 && destIdx != -1 && originIdx < destIdx) {
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

  /// Closes and cleans up all active movement simulation engines per Astra P0.2.
  Future<void> dispose() async {
    for (final engine in _activeEngines.values) {
      engine.dispose();
    }
    _activeEngines.clear();
  }
}
