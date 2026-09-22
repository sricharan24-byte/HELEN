
/// Represents a distinct occurrence of a physical stop along an ordered route pattern.
///
/// Models repeated physical stops (e.g. A-B-C-B-D), circular loops (A-B-C-A),
/// and pattern sequences per Astra BUS-P1-02.
class StopOccurrence {
  const StopOccurrence({
    required this.occurrenceId,
    required this.sequence,
    required this.stopId,
    this.patternId,
    this.stopName,
  });

  /// Unique identifier for this occurrence (e.g. "route-18b:occ-0")
  final String occurrenceId;

  /// Monotonic position index along the route pattern (0, 1, 2, ...)
  final int sequence;

  /// Underlying physical stop identifier (e.g. "stop-vit")
  final String stopId;

  /// Route trip pattern or branch identifier (optional)
  final String? patternId;

  /// Stop display name (optional)
  final String? stopName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StopOccurrence &&
          runtimeType == other.runtimeType &&
          occurrenceId == other.occurrenceId &&
          sequence == other.sequence &&
          stopId == other.stopId;

  @override
  int get hashCode => Object.hash(occurrenceId, sequence, stopId);

  @override
  String toString() =>
      'StopOccurrence(id: $occurrenceId, seq: $sequence, stopId: $stopId)';
}

/// A resolved contiguous segment of stop occurrences between an origin and destination.
class RouteSegment {
  const RouteSegment({
    required this.routeId,
    required this.originOccurrence,
    required this.destinationOccurrence,
    required this.occurrences,
  });

  final String routeId;
  final StopOccurrence originOccurrence;
  final StopOccurrence destinationOccurrence;
  final List<StopOccurrence> occurrences;

  /// The number of hops (edges) between stops: hopCount == occurrences.length - 1
  int get hopCount => occurrences.length > 1 ? occurrences.length - 1 : 0;

  /// The ordered physical stop IDs traversing this segment
  List<String> get stopIds => occurrences.map((o) => o.stopId).toList();

  @override
  String toString() =>
      'RouteSegment(routeId: $routeId, hops: $hopCount, stops: ${stopIds.join(" -> ")})';
}
