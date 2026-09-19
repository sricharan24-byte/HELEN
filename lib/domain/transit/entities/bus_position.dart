/// Pure-Dart BusPosition domain entity with explicit simulation tracking.
/// Mandates surfacing whether a bus position is simulated or live GTFS-RT.
class BusPosition {
  const BusPosition({
    required this.busId,
    required this.routeId,
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.nextStopId,
    required this.nextStopName,
    required this.etaMinutes,
    required this.timestamp,
    required this.progressPercentage,
    this.isSimulated = true,
  });

  final String busId;
  final String routeId;
  final double latitude;
  final double longitude;
  final double speedKmh;
  final String nextStopId;
  final String nextStopName;
  final int etaMinutes;
  final DateTime timestamp;
  final double progressPercentage;

  /// True when this coordinate originates from the local movement simulator
  /// rather than an authenticated external GTFS-RT vehicle feed.
  final bool isSimulated;

  BusPosition copyWith({
    String? busId,
    String? routeId,
    double? latitude,
    double? longitude,
    double? speedKmh,
    String? nextStopId,
    String? nextStopName,
    int? etaMinutes,
    DateTime? timestamp,
    double? progressPercentage,
    bool? isSimulated,
  }) {
    return BusPosition(
      busId: busId ?? this.busId,
      routeId: routeId ?? this.routeId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speedKmh: speedKmh ?? this.speedKmh,
      nextStopId: nextStopId ?? this.nextStopId,
      nextStopName: nextStopName ?? this.nextStopName,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      timestamp: timestamp ?? this.timestamp,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      isSimulated: isSimulated ?? this.isSimulated,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BusPosition &&
          runtimeType == other.runtimeType &&
          busId == other.busId &&
          routeId == other.routeId &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(busId, routeId, latitude, longitude, timestamp);

  @override
  String toString() =>
      'BusPosition($busId, route: $routeId, speed: ${speedKmh.toStringAsFixed(1)}km/h, next: $nextStopName, eta: ${etaMinutes}m, simulated: $isSimulated)';
}
