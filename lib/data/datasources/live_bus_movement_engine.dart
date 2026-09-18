import 'dart:async';
import 'dart:math';

import 'package:latlong2/latlong.dart';

import '../models/transport_models.dart';
import '../services/corridor_road_paths.dart';
import '../services/osrm_routing_service.dart';
import 'local_transport_data_source.dart';

/// Simulated live bus movement that drives along the real street path of the
/// route (OSRM geometry when online, pre-fetched corridor geometry offline)
/// instead of hopping in straight lines between stops.
class LiveBusMovementEngine {
  LiveBusMovementEngine({
    required this.busId,
    required this.route,
    LocalTransportDataSource? dataSource,
  }) : _dataSource = dataSource ?? LocalTransportDataSource();

  final String busId;
  final Route route;
  final LocalTransportDataSource _dataSource;
  final OsrmRoutingService _routingService = const OsrmRoutingService();

  StreamController<BusLocation>? _controller;
  Timer? _timer;
  bool _refreshingPath = false;

  /// Demo loop length: the full corridor is traversed in ~2 minutes so the
  /// prototype shows a complete end-to-end journey quickly.
  static const int _loopTicks = 60;
  static const Duration _tickInterval = Duration(seconds: 2);

  int _tick = 0;

  List<LatLng> _roadPath = const [];
  List<double> _cumulativeDistances = const [];
  double _totalPathLength = 0;
  List<({Stop stop, double distanceAlongPath})> _stopAnchors = const [];

  List<Stop> get _routeStops {
    final list = <Stop>[];
    for (final id in route.orderedStopIds) {
      final s = _dataSource.stopById(id);
      if (s != null) list.add(s);
    }
    return list;
  }

  Stream<BusLocation> get locationStream {
    _controller ??= StreamController<BusLocation>.broadcast(
      onListen: _startSimulation,
      onCancel: _stopSimulation,
    );
    return _controller!.stream;
  }

  void _startSimulation() {
    final stops = _routeStops;
    if (stops.length < 2) return;

    // Seed with the pre-fetched real street geometry immediately so the bus
    // never travels in straight lines, even with no network.
    _applyPath(
      CorridorRoadPaths.pathForEndpoints(stops.first.id, stops.last.id) ??
          stops
              .where((s) => s.latitude != null && s.longitude != null)
              .map((s) => LatLng(s.latitude!, s.longitude!))
              .toList(),
    );
    _emitCurrentPosition();

    _timer?.cancel();
    _timer = Timer.periodic(_tickInterval, (_) => _emitNextStep());

    // Refine with a live OSRM street route when the network allows it.
    _refreshPathFromOsrm(stops);
  }

  Future<void> _refreshPathFromOsrm(List<Stop> stops) async {
    if (_refreshingPath) return;
    _refreshingPath = true;
    try {
      final fresh = await _routingService.fetchRoutePolyline(stops);
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

  /// Anchors each stop to its distance along the road path so progress, next
  /// stop, and ETA all derive from the actual street geometry.
  void _projectStopsOntoPath() {
    final anchors = <({Stop stop, double distanceAlongPath})>[];
    var lastIndex = 0;
    for (final stop in _routeStops) {
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
      anchors.add(
        (stop: stop, distanceAlongPath: _cumulativeDistances[bestIndex]),
      );
    }
    _stopAnchors = anchors;
  }

  void _emitNextStep() {
    _tick = (_tick + 1) % _loopTicks;
    _emitCurrentPosition();
  }

  void _emitCurrentPosition() {
    if (_roadPath.length < 2 || _totalPathLength <= 0) return;
    if (_controller == null || _controller!.isClosed) return;

    final fraction = _tick / _loopTicks;
    final travelled = fraction * _totalPathLength;
    final position = _pointAtDistance(travelled);

    Stop nextStop;
    if (_stopAnchors.isEmpty) {
      if (_routeStops.isNotEmpty) {
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

    final remainingFraction = 1 - fraction;
    const avgSpeedKmh = 28.0;
    final totalRouteMinutes = (_totalPathLength / 1000 / avgSpeedKmh * 60) + 2;
    final etaMinutes =
        (remainingFraction * totalRouteMinutes).clamp(1.0, 60.0).round();
    // Smoothly varying simulated speed within the 22-36 km/h town-bus range.
    final speed = 28 + 6 * sin(_tick * 0.7);

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
      segmentStart.latitude +
          (segmentEnd.latitude - segmentStart.latitude) * t,
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
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    return earthRadius * 2 * atan2(sqrt(h), sqrt(1 - h));
  }

  void dispose() {
    _stopSimulation();
    _controller?.close();
  }
}
