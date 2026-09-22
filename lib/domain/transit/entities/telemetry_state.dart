import '../../../data/models/transport_models.dart';

/// Freshness state of real-time telemetry per Astra BUS-P1-01.
enum TelemetryFreshness {
  loading,
  live,
  stale,
  offline,
  error,
}

/// Immutable state snapshot of live bus telemetry with deterministic freshness.
class TelemetrySnapshot {
  const TelemetrySnapshot({
    required this.freshness,
    this.location,
    this.lastReceivedAt,
    this.errorMessage,
    this.staleSince,
    this.generation = 0,
    this.lastSequence = -1,
  });

  final TelemetryFreshness freshness;
  final BusLocation? location;
  final DateTime? lastReceivedAt;
  final String? errorMessage;
  final DateTime? staleSince;
  final int generation;
  final int lastSequence;

  bool get isLive => freshness == TelemetryFreshness.live;
  bool get isStale => freshness == TelemetryFreshness.stale;
  bool get isOffline => freshness == TelemetryFreshness.offline;
  bool get isLoading => freshness == TelemetryFreshness.loading;

  factory TelemetrySnapshot.initial({int generation = 0}) => TelemetrySnapshot(
        freshness: TelemetryFreshness.loading,
        generation: generation,
        lastSequence: -1,
      );

  TelemetrySnapshot copyWith({
    TelemetryFreshness? freshness,
    BusLocation? location,
    DateTime? lastReceivedAt,
    String? errorMessage,
    DateTime? staleSince,
    int? generation,
    int? lastSequence,
  }) {
    return TelemetrySnapshot(
      freshness: freshness ?? this.freshness,
      location: location ?? this.location,
      lastReceivedAt: lastReceivedAt ?? this.lastReceivedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      staleSince: staleSince ?? this.staleSince,
      generation: generation ?? this.generation,
      lastSequence: lastSequence ?? this.lastSequence,
    );
  }

  @override
  String toString() =>
      'TelemetrySnapshot(freshness: $freshness, gen: $generation, seq: $lastSequence, loc: ${location?.busId})';
}

/// Reducer managing monotonic sequence ordering, generation resets, and time-based freshness.
class TelemetryReducer {
  static const Duration staleThreshold = Duration(seconds: 15);
  static const Duration offlineThreshold = Duration(seconds: 60);

  static TelemetrySnapshot reduceLocation({
    required TelemetrySnapshot current,
    required BusLocation incoming,
    required String expectedBusId,
    required String expectedRouteId,
    DateTime? nowUtc,
  }) {
    // 1. Rejection of mismatching route/bus
    if (incoming.busId != expectedBusId || incoming.routeId != expectedRouteId) {
      return current;
    }

    // 2. Generation ordering: reject older generation
    if (incoming.generation < current.generation) {
      return current;
    }

    // 3. Monotonic sequence ordering within the same generation
    if (incoming.generation == current.generation) {
      if (incoming.sequence <= current.lastSequence) {
        return current;
      }
    }

    final now = nowUtc ?? DateTime.now().toUtc();
    return TelemetrySnapshot(
      freshness: TelemetryFreshness.live,
      location: incoming,
      lastReceivedAt: now,
      generation: incoming.generation,
      lastSequence: incoming.sequence,
    );
  }

  static TelemetrySnapshot checkFreshness({
    required TelemetrySnapshot current,
    required DateTime nowUtc,
  }) {
    if (current.freshness == TelemetryFreshness.loading ||
        current.freshness == TelemetryFreshness.offline ||
        current.freshness == TelemetryFreshness.error ||
        current.lastReceivedAt == null) {
      return current;
    }

    final elapsed = nowUtc.difference(current.lastReceivedAt!);
    if (elapsed >= offlineThreshold) {
      return current.copyWith(freshness: TelemetryFreshness.offline);
    } else if (elapsed >= staleThreshold) {
      return current.copyWith(
        freshness: TelemetryFreshness.stale,
        staleSince: current.staleSince ?? nowUtc,
      );
    }

    return current;
  }
}
