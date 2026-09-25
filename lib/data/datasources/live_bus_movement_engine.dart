import 'dart:async';
import 'dart:math';

import 'package:latlong2/latlong.dart';

import '../../core/di/async_disposable.dart';
import '../models/transport_models.dart';
import '../services/corridor_road_paths.dart';
import '../services/osrm_routing_service.dart';
import 'local_transport_data_source.dart';

/// Simulated live bus movement that drives along the real street path of the
/// route (OSRM geometry when online, pre-fetched corridor geometry offline)
/// instead of hopping in straight lines between stops.
///
/// The engine simulates one passenger journey: it starts at [originStopId]
/// (default: the route's first stop) and terminates at [destinationStopId]
/// (default: the route's last stop). On arrival it emits a terminal position
/// (progress 1.0, ETA 0) and closes the stream — it never loops.
class LiveBusMovementEngine implements AsyncDisposable {
  LiveBusMovementEngine({
    required this.busId,
    required this.route,
    LocalTransportDataSource? dataSource,
    this.originStopId,
    this.destinationStopId,
    int journeyTicks = _defaultJourneyTicks,
    this._tickInterval = _defaultTickInterval,
  })  : _dataSource = dataSource ?? LocalTransportDataSource(),
        _journeyTicks = journeyTicks > 0 ? journeyTicks : _defaultJourneyTicks;

  final String busId;
  final Route route;

  /// Boarding stop: the journey starts here. Defaults to route start.
  final String? originStopId;

  /// Alighting stop: the journey terminates here. Defaults to route end.
  final String? destinationStopId;

  final LocalTransportDataSource _dataSource;
  final OsrmRoutingService _routingService = const OsrmRoutingService();

  // Sink ownership: created lazily in [locationStream], closed in [dispose()]
  // and _stopSimulation; lint cannot model the onListen/onCancel lifetime.
  // ignore: close_sinks
  StreamController<BusLocation>? _controller;
  Timer? _timer;
  bool _refreshingPath = false;
  int _generation = 0;
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;
  int get generation => _generation;

  /// Journey length: the passenger segment is traversed in ~2 minutes so the
  /// prototype shows a complete start-to-destination journey quickly.
  /// Tests may inject a smaller count to observe termination.
  static const int _defaultJourneyTicks = 60;
  static const Duration _defaultTickInterval = Duration(seconds: 2);

  final int _journeyTicks;
  final Duration _tickInterval;

  int _tick = 0;
  int _sequence = 0;
  bool _journeyFinished = false;

  /// True once the bus reached the destination and the stream was closed.
  bool get isCompleted => _journeyFinished;

  List<LatLng> _roadPath = const [];
  List<double> _cumulativeDistances = const [];
  double _totalPathLength = 0;
  List<({Stop stop, double distanceAlongPath})> _stopAnchors = const [];

  /// Passenger segment: boarding stop through alighting stop, in travel
  /// order. Falls back to the full corridor when the ids are absent.
  List<Stop> _journeyStops = const [];

  List<Stop> get _routeStops {
    final list = <Stop>[];
    for (final id in route.orderedStopIds) {
      final s = _dataSource.stopById(id);
      if (s != null) list.add(s);
    }
    return list;
  }

  /// Clips the full corridor to the passenger's boarding→alighting segment.
  static List<Stop> _clipToJourney(
    List<Stop> stops,
    String? originId,
    String? destinationId,
  ) {
    final startIndex = originId == null
        ? 0
        : stops.indexWhere((s) => s.id == originId);
    final endIndex = destinationId == null
        ? stops.length - 1
        : stops.indexWhere((s) => s.id == destinationId);
    if (startIndex == -1 || endIndex == -1 || startIndex >= endIndex) {
      return stops;
    }
    return stops.sublist(startIndex, endIndex + 1);
  }

  Stream<BusLocation> get locationStream {
    _controller ??= StreamController<BusLocation>.broadcast(
      onListen: _startSimulation,
      onCancel: _stopSimulation,
    );
    return _controller!.stream;
  }

  void _startSimulation() {
    if (_journeyFinished || _isDisposed) return;
    final stops = _routeStops;
    if (stops.length < 2) return;
    _journeyStops = _clipToJourney(stops, originStopId, destinationStopId);
    if (_journeyStops.length < 2) return;

    // Seed with the pre-fetched real street geometry immediately so the bus
    // never travels in straight lines, even with no network. Falls back to
    // straight lines between the journey stops when no baked corridor path
    // matches this exact boarding→alighting pair (OSRM refines it below).
    _applyPath(
      CorridorRoadPaths.pathForEndpoints(
            _journeyStops.first.id,
            _journeyStops.last.id,
          ) ??
          _journeyStops
              .where((s) => s.latitude != null && s.longitude != null)
              .map((s) => LatLng(s.latitude!, s.longitude!))
              .toList(),
    );
    _emitCurrentPosition();

    _timer?.cancel();
    _timer = Timer.periodic(_tickInterval, (_) => _emitNextStep());

    // Refine with a live OSRM street route when the network allows it.
    unawaited(_refreshPathFromOsrm(_journeyStops));
  }

  Future<void> _refreshPathFromOsrm(List<Stop> stops) async {
    if (_refreshingPath || _isDisposed) return;
    _refreshingPath = true;
    final token = _generation;
    try {
      final fresh = await _routingService.fetchRoutePolyline(stops);
      if (_isDisposed || token != _generation) return;
      if (fresh.length > 2) _applyPath(fresh);
    } catch (_) {
      // Keep the baked corridor path.
    } finally {
      _refreshingPath = false;
    }
  }

  void _stopSimulation() {
    _timer?.cancel();
    _timer = null;
  }

  void _applyPath(List<LatLng> path) {
    if (path.length < 2) return;
    _roadPath = path;
    _cumulativeDistances = [0];
    for (int i = 1; i < path.length; i++) {
      _cumulativeDistances.add(
        _cumulativeDistances.last + _distanceMeters(path[i - 1], path[i]),
      );
    }
    _totalPathLength = _cumulativeDistances.last;
    _projectStopsOntoPath();
  }

  /// Anchors each journey stop to its distance along the road path so
  /// progress, next stop, and ETA all derive from the actual street geometry.
  /// Only the passenger's own segment is anchored: unrelated corridor stops
  /// never influence the journey.
  void _projectStopsOntoPath() {
    final anchors = <({Stop stop, double distanceAlongPath})>[];
    var lastIndex = 0;
    for (final stop in _journeyStops) {
      if (stop.latitude == null || stop.longitude == null) continue;
      final point = LatLng(stop.latitude!, stop.longitude!);
      var bestIndex = lastIndex;
      var bestDistance = double.infinity;
      // Search monotonically along the road polyline to ensure stops never invert order
      for (int i = lastIndex; i < _roadPath.length; i++) {
        final d = _distanceMeters(point, _roadPath[i]);
        if (d < bestDistance) {
          bestDistance = d;
          bestIndex = i;
        }
      }
      lastIndex = bestIndex;
      anchors.add((
        stop: stop,
        distanceAlongPath: _cumulativeDistances[bestIndex],
      ));
    }
    _stopAnchors = anchors;
  }

  void _emitNextStep() {
    if (_journeyFinished) return;
    if (_tick + 1 >= _journeyTicks) {
      _finishJourney();
      return;
    }
    _tick++;
    _emitCurrentPosition();
  }

  /// Emits the arrival position (progress 1.0, ETA 0, bus parked at the
  /// destination) and terminates the journey: the timer stops and the stream
  /// closes so every listener observes the end of the ride.
  void _finishJourney() {
    _journeyFinished = true;
    _timer?.cancel();
    _timer = null;
    _emitAt(fraction: 1.0, travelled: _journeyEndDistance, isTerminal: true);
    final controller = _controller;
    if (controller != null && !controller.isClosed) {
      unawaited(controller.close());
    }
  }

  /// Distance along the road path where the passenger boards.
  double get _journeyStartDistance => _stopAnchors.isEmpty
      ? 0.0
      : _stopAnchors.first.distanceAlongPath.clamp(0.0, _totalPathLength);

  /// Distance along the road path where the passenger alights.
  double get _journeyEndDistance => _stopAnchors.isEmpty
      ? _totalPathLength
      : _stopAnchors.last.distanceAlongPath.clamp(0.0, _totalPathLength);

  void _emitCurrentPosition() {
    if (_roadPath.length < 2 || _totalPathLength <= 0) return;
    if (_controller == null || _controller!.isClosed) return;

    final start = _journeyStartDistance;
    final end = _journeyEndDistance;
    final span = (end - start) <= 0 ? _totalPathLength : (end - start);
    final fraction = _tick / _journeyTicks;
    final travelled = start + fraction * span;
    _emitAt(fraction: fraction, travelled: travelled, isTerminal: false);
  }

  void _emitAt({
    required double fraction,
    required double travelled,
    required bool isTerminal,
  }) {
    if (_roadPath.length < 2 || _totalPathLength <= 0) return;
    if (_controller == null || _controller!.isClosed) return;

    final position = _pointAtDistance(travelled);

    Stop nextStop;
    if (_stopAnchors.isEmpty) {
      if (_journeyStops.isNotEmpty) {
        nextStop = _journeyStops.last;
      } else if (_routeStops.isNotEmpty) {
        nextStop = _routeStops.last;
      } else {
        return;
      }
    } else {
      nextStop = _stopAnchors.last.stop;
      for (final anchor in _stopAnchors) {
        if (anchor.distanceAlongPath > travelled + 1) {
          nextStop = anchor.stop;
          break;
        }
      }
    }

    final remainingFraction = (1 - fraction).clamp(0.0, 1.0);
    const avgSpeedKmh = 28.0;
    final totalRouteMinutes = (_totalPathLength / 1000 / avgSpeedKmh * 60) + 2;
    final etaMinutes = isTerminal
        ? 0
        : (remainingFraction * totalRouteMinutes).clamp(1.0, 60.0).round();
    // Smoothly varying simulated speed within the 22-36 km/h town-bus range;
    // zero once parked at the destination.
    final speed = isTerminal ? 0.0 : 28 + 6 * sin(_tick * 0.7);

    _sequence++;
    final location = BusLocation(
      busId: busId,
      routeId: route.id,
      latitude: position.latitude,
      longitude: position.longitude,
      speedKmh: speed,
      nextStopId: nextStop.id,
      nextStopName: nextStop.name,
      etaMinutes: etaMinutes,
      timestamp: DateTime.now(),
      progressPercentage: fraction.clamp(0.0, 1.0),
      sequence: _sequence,
      generation: _generation,
      accuracyMeters: 4.5,
      isSimulated: true,
      receivedTimestamp: DateTime.now().toUtc(),
    );

    _controller!.add(location);
  }

  LatLng _pointAtDistance(double distanceMeters) {
    if (distanceMeters <= 0) return _roadPath.first;
    if (distanceMeters >= _totalPathLength) return _roadPath.last;
    int low = 0;
    int high = _cumulativeDistances.length - 1;
    while (low + 1 < high) {
      final mid = (low + high) ~/ 2;
      if (_cumulativeDistances[mid] <= distanceMeters) {
        low = mid;
      } else {
        high = mid;
      }
    }
    final segmentStart = _roadPath[low];
    final segmentEnd = _roadPath[low + 1];
    final segmentLength =
        _cumulativeDistances[low + 1] - _cumulativeDistances[low];
    final t = segmentLength <= 0
        ? 0.0
        : (distanceMeters - _cumulativeDistances[low]) / segmentLength;
    return LatLng(
      segmentStart.latitude + (segmentEnd.latitude - segmentStart.latitude) * t,
      segmentStart.longitude +
          (segmentEnd.longitude - segmentStart.longitude) * t,
    );
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLng = (b.longitude - a.longitude) * pi / 180;
    final h =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    return earthRadius * 2 * atan2(sqrt(h), sqrt(1 - h));
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    _generation++;
    _stopSimulation();
    final controller = _controller;
    _controller = null;
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
  }
}
