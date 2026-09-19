import '../entities/bus_position.dart';
import '../entities/stop.dart';
import '../entities/transit_route.dart';
import '../../core/result.dart';
import '../../core/failure.dart';

/// Pure-Dart abstract contract for transit data queries and live GPS streams.
/// Domain consumers depend solely on this abstraction, never concrete data sources.
abstract interface class ITransitRepository {
  /// Searches stops matching [query]. An empty query returns all corridor stops.
  Future<Result<List<Stop>, Failure>> searchStops(String query);

  /// Synchronous stop search for instant UI auto-complete filters.
  List<Stop> findStops(String query);

  /// Finds routes where [originStopId] precedes [destinationStopId].
  Future<Result<List<TransitRoute>, Failure>> findRoutes({
    required String originStopId,
    required String destinationStopId,
  });

  /// Looks up a single stop by its unique identifier.
  Stop? getStop(String stopId);

  /// Returns all defined transit routes.
  List<TransitRoute> get allRoutes;

  /// Continuous stream of live bus movement updates for [busId] along [routeId].
  Stream<BusPosition> streamBusLocation(String busId, String routeId);
}
