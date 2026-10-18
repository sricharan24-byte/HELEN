/// Builds a natural-language route label for screen readers.
String routeSpeechLabel({
  required String origin,
  required String destination,
  String? busId,
}) {
  final from = origin.trim();
  final to = destination.trim();
  final route = switch ((from.isNotEmpty, to.isNotEmpty)) {
    (true, true) => 'from $from to $to',
    (true, false) => 'from $from',
    (false, true) => 'to $to',
    (false, false) => 'Route information unavailable',
  };
  final bus = busId?.trim();
  return [
    if (bus != null && bus.isNotEmpty) 'Bus $bus',
    if (route.isNotEmpty) route,
  ].join(', ');
}
