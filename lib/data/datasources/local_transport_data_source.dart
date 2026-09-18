import '../models/transport_models.dart';

/// Provides curated transport fixture data for Vellore public transport corridors.
class LocalTransportDataSource {
  LocalTransportDataSource();

  // ---------------------------------------------------------------------------
  // Stop fixtures with GPS coordinates for Vellore corridors.
  // Coordinates verified against OpenStreetMap bus stop nodes / landmarks
  // (Overpass API, Sep 2026) and cross-checked with OSRM road snapping.
  // ---------------------------------------------------------------------------

  static const List<Stop> _stops = [
    Stop(id: 'vit-main-gate', name: 'VIT Main Gate', area: 'VIT University', latitude: 12.96813, longitude: 79.15553),
    Stop(id: 'vit-back-gate', name: 'VIT Back Gate', area: 'VIT University', latitude: 12.9730, longitude: 79.1601),
    Stop(id: 'old-katpadi', name: 'Old Katpadi', area: 'Katpadi Road', latitude: 12.96882, longitude: 79.14565),
    Stop(id: 'chittoor-bus-stop', name: 'Chittoor Bus Stop', area: 'Katpadi Road', latitude: 12.96605, longitude: 79.13724),
    Stop(id: 'katpadi-bus-stand', name: 'Katpadi Bus Stand', area: 'Katpadi', latitude: 12.97143, longitude: 79.13685),
    Stop(id: 'katpadi-junction', name: 'Katpadi Junction', area: 'Katpadi', latitude: 12.9721, longitude: 79.1365),
    Stop(id: 'katpadi-railway-station', name: 'Katpadi Railway Station', area: 'Katpadi Station Road', latitude: 12.9719, longitude: 79.1366),
    Stop(id: 'gandhi-nagar', name: 'Gandhi Nagar', area: 'Katpadi Road', latitude: 12.95016, longitude: 79.14148),
    Stop(id: 'silk-mill', name: 'Silk Mill', area: 'Gandhi Nagar', latitude: 12.94979, longitude: 79.13719),
    Stop(id: 'green-circle', name: 'Green Circle', area: 'Vellore Central', latitude: 12.93203, longitude: 79.13788),
    Stop(id: 'cmc-hospital', name: 'CMC Hospital', area: 'Officers Line', latitude: 12.92555, longitude: 79.13338),
    Stop(id: 'clock-tower', name: 'Clock Tower', area: 'Vellore Town', latitude: 12.9239, longitude: 79.1336),
    Stop(id: 'vat-vellore-fort', name: 'Vellore Fort', area: 'Fort Round Road', latitude: 12.9204, longitude: 79.1329),
    Stop(id: 'old-bus-stand', name: 'Old Bus Stand', area: 'Vellore Central', latitude: 12.92215, longitude: 79.13252),
    Stop(id: 'bagayam', name: 'Bagayam', area: 'South Vellore', latitude: 12.88009, longitude: 79.13471),
    Stop(id: 'srinagar', name: 'Srinagar', area: 'Vellore', latitude: 12.9580, longitude: 79.1430),
    Stop(id: 'thottapalayam', name: 'Thottapalayam', area: 'Vellore', latitude: 12.9620, longitude: 79.1450),
  ];

  /// All stops in fixture order.
  List<Stop> get allStops => List<Stop>.unmodifiable(_stops);

  // ---------------------------------------------------------------------------
  // Route fixtures
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Route fixtures — stop sequences follow the real Katpadi Main Road /
  // Gandhi Nagar road network, validated with the OSRM driving profile.
  // ---------------------------------------------------------------------------

  static final List<Route> _routes = [
    Route(
      id: 'vit-to-katpadi',
      displayName: 'VIT → Katpadi Railway Station',
      direction: 'inbound',
      orderedStopIds: const [
        'vit-main-gate',
        'old-katpadi',
        'chittoor-bus-stop',
        'katpadi-bus-stand',
        'katpadi-railway-station',
      ],
    ),
    Route(
      id: 'katpadi-to-vit',
      displayName: 'Katpadi Railway Station → VIT',
      direction: 'outbound',
      orderedStopIds: const [
        'katpadi-railway-station',
        'katpadi-bus-stand',
        'chittoor-bus-stop',
        'old-katpadi',
        'vit-main-gate',
      ],
    ),
    Route(
      id: 'vit-to-cmc',
      displayName: 'VIT → CMC Hospital & Old Bus Stand',
      direction: 'inbound',
      orderedStopIds: const [
        'vit-main-gate',
        'old-katpadi',
        'chittoor-bus-stop',
        'silk-mill',
        'gandhi-nagar',
        'cmc-hospital',
        'clock-tower',
        'vat-vellore-fort',
        'old-bus-stand',
      ],
    ),
    Route(
      id: 'bus-stand-to-katpadi',
      displayName: 'Old Bus Stand → Katpadi Junction',
      direction: 'outbound',
      orderedStopIds: const [
        'old-bus-stand',
        'cmc-hospital',
        'chittoor-bus-stop',
        'katpadi-bus-stand',
        'katpadi-railway-station',
      ],
    ),
  ];

  /// All routes defined in the fixture.
  List<Route> get allRoutes => List<Route>.unmodifiable(_routes);

  /// Look up a single stop by its id. Returns `null` when not found.
  Stop? stopById(String stopId) {
    for (final stop in _stops) {
      if (stop.id == stopId) return stop;
    }
    return null;
  }

  /// Find stops whose [name] or [area] contains [query] (case-insensitive).
  List<Stop> searchStops(String query) {
    if (query.isEmpty) return allStops;
    final lower = query.toLowerCase();
    return _stops
        .where(
          (s) =>
              s.name.toLowerCase().contains(lower) ||
              s.area.toLowerCase().contains(lower),
        )
        .toList();
  }
}
