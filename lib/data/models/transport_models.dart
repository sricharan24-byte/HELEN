import '../../domain/transit/entities/stop.dart';
import '../../domain/transit/entities/transit_route.dart';
export '../../domain/transit/entities/stop.dart';

/// Transport domain models for the BusBuddy corridor.

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

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'direction': direction,
    'orderedStopIds': orderedStopIds,
  };

  factory Route.fromJson(Map<String, dynamic> json) => Route(
    id: json['id'] as String,
    displayName: json['displayName'] as String,
    direction: json['direction'] as String? ?? '',
    orderedStopIds: (json['orderedStopIds'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList() ??
        const [],
  );

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

  /// Returns the ordered list of stop IDs along the resolved segment between [originStopId] and [destinationStopId].
  /// Accurately handles circular loops and repeated stops per Astra BUS-P1-02.
  List<String> stopsBetween(String originStopId, String destinationStopId) {
    final transit = TransitRoute(
      id: id,
      displayName: displayName,
      direction: direction,
      orderedStopIds: orderedStopIds,
    );
    return transit.stopsBetween(originStopId, destinationStopId);
  }

  @override
  String toString() =>
      'Route(id: $id, displayName: $displayName, direction: $direction)';
}

/// A real-time live location report of a bus with telemetry ordering per BUS-P1-01.
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
    this.sequence = 0,
    this.generation = 0,
    this.accuracyMeters = 5.0,
    this.isSimulated = true,
    this.receivedTimestamp,
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
  final int sequence;
  final int generation;
  final double accuracyMeters;
  final bool isSimulated;
  final DateTime? receivedTimestamp;
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

/// Represents an active or completed passenger journey along the corridor.
class JourneySession {
  const JourneySession({
    required this.id,
    required this.routeId,
    required this.routeName,
    required this.origin,
    required this.destination,
    this.busId,
    required this.startTime,
    this.isCompleted = false,
  });

  final String id;
  final String routeId;
  final String routeName;
  final Stop origin;
  final Stop destination;
  final String? busId;
  final DateTime startTime;
  final bool isCompleted;

  JourneySession copyWith({
    String? id,
    String? routeId,
    String? routeName,
    Stop? origin,
    Stop? destination,
    String? busId,
    DateTime? startTime,
    bool? isCompleted,
  }) {
    return JourneySession(
      id: id ?? this.id,
      routeId: routeId ?? this.routeId,
      routeName: routeName ?? this.routeName,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      busId: busId ?? this.busId,
      startTime: startTime ?? this.startTime,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'routeId': routeId,
    'routeName': routeName,
    'origin': origin.toJson(),
    'destination': destination.toJson(),
    if (busId != null) 'busId': busId,
    'startTime': startTime.toIso8601String(),
    'isCompleted': isCompleted,
  };

  factory JourneySession.fromJson(Map<String, dynamic> json) => JourneySession(
    id: json['id'] as String,
    routeId: json['routeId'] as String,
    routeName: json['routeName'] as String,
    origin: Stop.fromJson(json['origin'] as Map<String, dynamic>),
    destination: Stop.fromJson(json['destination'] as Map<String, dynamic>),
    busId: json['busId'] as String?,
    startTime: DateTime.parse(json['startTime'] as String),
    isCompleted: json['isCompleted'] == true,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JourneySession &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          routeId == other.routeId &&
          routeName == other.routeName &&
          origin == other.origin &&
          destination == other.destination &&
          busId == other.busId &&
          startTime == other.startTime &&
          isCompleted == other.isCompleted;

  @override
  int get hashCode => Object.hash(
        id,
        routeId,
        routeName,
        origin,
        destination,
        busId,
        startTime,
        isCompleted,
      );
}

