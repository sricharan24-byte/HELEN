import '../../core/failure.dart';
import '../../core/result.dart';
import 'stop_occurrence.dart';

/// Pure-Dart TransitRoute domain entity.
/// Uses TransitRoute instead of Route to eliminate conflicts with Flutter's Navigator `Route<T>`.
class TransitRoute {
  TransitRoute({
    required this.id,
    required this.displayName,
    required this.direction,
    required List<String> orderedStopIds,
    List<StopOccurrence>? stopOccurrences,
  })  : orderedStopIds = List.unmodifiable(orderedStopIds),
        occurrences = List.unmodifiable(
          stopOccurrences ??
              [
                for (int i = 0; i < orderedStopIds.length; i++)
                  StopOccurrence(
                    occurrenceId: '$id:occ-$i',
                    sequence: i,
                    stopId: orderedStopIds[i],
                  ),
              ],
        );

  final String id;
  final String displayName;
  final String direction;
  final List<String> orderedStopIds;
  final List<StopOccurrence> occurrences;

  int get stopCount => occurrences.length;

  bool containsStop(String stopId) =>
      occurrences.any((occ) => occ.stopId == stopId);

  int indexOfStop(String stopId) => orderedStopIds.indexOf(stopId);

  List<StopOccurrence> occurrencesOfStop(String stopId) =>
      occurrences.where((occ) => occ.stopId == stopId).toList();

  /// Resolves the trip segment between origin and destination occurrences per Astra BUS-P1-02.
  ///
  /// Correctly handles:
  /// - Repeated physical stops (e.g. A -> B -> C -> B -> D)
  /// - Circular routes (e.g. A -> B -> C -> A)
  /// - Disambiguation via explicit sequences [originSequence] / [destinationSequence]
  /// - Typed rejection for reverse travel, missing stops, and identical occurrences.
  Result<RouteSegment, SegmentResolutionFailure> resolveSegment({
    required String originStopId,
    required String destinationStopId,
    int? originSequence,
    int? destinationSequence,
  }) {
    final originCandidates = occurrencesOfStop(originStopId);
    if (originCandidates.isEmpty) {
      return Result.failure(SegmentResolutionFailure(
        'Origin stop "$originStopId" does not occur along route "$id".',
        originStopId: originStopId,
        destinationStopId: destinationStopId,
      ));
    }

    final destCandidates = occurrencesOfStop(destinationStopId);
    if (destCandidates.isEmpty) {
      return Result.failure(SegmentResolutionFailure(
        'Destination stop "$destinationStopId" does not occur along route "$id".',
        originStopId: originStopId,
        destinationStopId: destinationStopId,
      ));
    }

    // Filter by explicit sequences if provided
    final origins = originSequence != null
        ? originCandidates.where((o) => o.sequence == originSequence).toList()
        : originCandidates;
    final dests = destinationSequence != null
        ? destCandidates.where((d) => d.sequence == destinationSequence).toList()
        : destCandidates;

    if (origins.isEmpty) {
      return Result.failure(SegmentResolutionFailure(
        'Origin stop "$originStopId" has no occurrence at sequence $originSequence.',
        originStopId: originStopId,
        destinationStopId: destinationStopId,
      ));
    }
    if (dests.isEmpty) {
      return Result.failure(SegmentResolutionFailure(
        'Destination stop "$destinationStopId" has no occurrence at sequence $destinationSequence.',
        originStopId: originStopId,
        destinationStopId: destinationStopId,
      ));
    }

    // Find all valid forward pairs (orig.sequence < dest.sequence)
    final validPairs = <({StopOccurrence orig, StopOccurrence dest})>[];
    for (final orig in origins) {
      for (final dest in dests) {
        if (orig.sequence < dest.sequence) {
          validPairs.add((orig: orig, dest: dest));
        }
      }
    }

    if (validPairs.isEmpty) {
      // Check if this is the exact same occurrence (0 hops)
      if (originStopId == destinationStopId &&
          origins.any((o) => dests.any((d) => o.sequence == d.sequence))) {
        return Result.failure(SegmentResolutionFailure(
          'Origin and destination stops cannot be identical at the same occurrence (0 hops).',
          originStopId: originStopId,
          destinationStopId: destinationStopId,
        ));
      }

      // Check if reverse travel exists
      final hasReverse =
          origins.any((o) => dests.any((d) => d.sequence < o.sequence));
      if (hasReverse) {
        return Result.failure(SegmentResolutionFailure(
          'Reverse travel requested: destination "$destinationStopId" occurs only before origin "$originStopId" along route direction.',
          originStopId: originStopId,
          destinationStopId: destinationStopId,
          isReverseTravel: true,
        ));
      }

      return Result.failure(SegmentResolutionFailure(
        'No forward route segment found from "$originStopId" to "$destinationStopId".',
        originStopId: originStopId,
        destinationStopId: destinationStopId,
      ));
    }

    // Pick the most direct / shortest forward segment when ambiguous
    validPairs.sort((a, b) => (a.dest.sequence - a.orig.sequence)
        .compareTo(b.dest.sequence - b.orig.sequence));
    final chosen = validPairs.first;

    final segmentOccurrences = occurrences
        .where((occ) =>
            occ.sequence >= chosen.orig.sequence &&
            occ.sequence <= chosen.dest.sequence)
        .toList();

    return Result.success(RouteSegment(
      routeId: id,
      originOccurrence: chosen.orig,
      destinationOccurrence: chosen.dest,
      occurrences: segmentOccurrences,
    ));
  }

  /// Returns the ordered list of stop IDs along the resolved segment, or empty list if no valid segment.
  List<String> stopsBetween(String originStopId, String destinationStopId) {
    final res = resolveSegment(
      originStopId: originStopId,
      destinationStopId: destinationStopId,
    );
    if (res.isFailure) return const [];
    return res.valueOrNull!.stopIds;
  }

  bool isValidSequence(String originStopId, String destinationStopId) {
    return resolveSegment(
      originStopId: originStopId,
      destinationStopId: destinationStopId,
    ).isSuccess;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransitRoute &&
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
      'TransitRoute(id: $id, displayName: $displayName, direction: $direction, stops: ${occurrences.length})';
}
