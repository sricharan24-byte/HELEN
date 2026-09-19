/// Pure-Dart TransitRoute domain entity.
/// Uses TransitRoute instead of Route to eliminate conflicts with Flutter's Navigator Route<T>.
class TransitRoute {
  const TransitRoute({
    required this.id,
    required this.displayName,
    required this.direction,
    required this.orderedStopIds,
  });

  final String id;
  final String displayName;
  final String direction;
  final List<String> orderedStopIds;

  int get stopCount => orderedStopIds.length;

  bool containsStop(String stopId) => orderedStopIds.contains(stopId);

  int indexOfStop(String stopId) => orderedStopIds.indexOf(stopId);

  bool isValidSequence(String originStopId, String destinationStopId) {
    final origIdx = indexOfStop(originStopId);
    final destIdx = indexOfStop(destinationStopId);
    return origIdx != -1 && destIdx != -1 && origIdx < destIdx;
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
      'TransitRoute(id: $id, displayName: $displayName, direction: $direction, stops: ${orderedStopIds.length})';
}
