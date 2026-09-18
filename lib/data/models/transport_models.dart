/// Transport domain models for the BusBuddy corridor.
library;

/// A named stop along a transport corridor.
class Stop {
  const Stop({
    required this.id,
    required this.name,
    required this.area,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String area;
  final double? latitude;
  final double? longitude;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Stop &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          area == other.area;

  @override
  int get hashCode => Object.hash(id, name, area);

  @override
  String toString() => 'Stop(id: $id, name: $name, area: $area)';
}

/// An ordered list of stops that forms a rideable route.
class Route {
  const Route({
    required this.id,
    required this.displayName,
    required this.direction,
    required this.orderedStopIds,
  });

  final String id;
  final String displayName;
  final String direction;
  final List<String> orderedStopIds;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Route &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          displayName == other.displayName &&
          direction == other.direction &&
          _listEquals(orderedStopIds, other.orderedStopIds);

  @override
  int get hashCode =>
      Object.hashAll([id, displayName, direction, ...orderedStopIds]);

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'Route(id: $id, displayName: $displayName, direction: $direction)';
}

/// A real-time live location report of a bus.
class BusLocation {
  const BusLocation({
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
}

/// A user's chosen origin–destination–route triple.
class JourneySelection {
  const JourneySelection({
    required this.origin,
    required this.destination,
    required this.route,
  });

  final Stop origin;
  final Stop destination;
  final Route route;
}
