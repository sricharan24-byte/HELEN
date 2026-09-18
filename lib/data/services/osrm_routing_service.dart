import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/transport_models.dart';
import 'corridor_road_paths.dart';

/// Service to fetch turn-by-turn real street road polyline geometry from
/// Open Source Routing Machine (OSRM) driving API with offline fallback to
/// pre-fetched corridor geometry (real OSM road paths baked at build time).
class OsrmRoutingService {
  const OsrmRoutingService();

  /// Fetches street-snapped polyline coordinates for a given list of bus stops.
  Future<List<LatLng>> fetchRoutePolyline(List<Stop> stops) async {
    final validStops = stops
        .where((s) => s.latitude != null && s.longitude != null)
        .toList();

    if (validStops.length < 2) {
      return validStops.map((s) => LatLng(s.latitude!, s.longitude!)).toList();
    }

    try {
      // OSRM expects coordinates formatted as: lon1,lat1;lon2,lat2;...
      final coordsString = validStops
          .map((s) => '${s.longitude},${s.latitude}')
          .join(';');

      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coordsString?overview=full&geometries=geojson',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final geometry = routes[0]['geometry'] as Map<String, dynamic>?;
          final coordinates = geometry?['coordinates'] as List<dynamic>?;

          if (coordinates != null && coordinates.isNotEmpty) {
            final points = <LatLng>[];
            for (final coord in coordinates) {
              final list = coord as List<dynamic>;
              final lng = (list[0] as num).toDouble();
              final lat = (list[1] as num).toDouble();
              points.add(LatLng(lat, lng));
            }
            if (points.isNotEmpty) return points;
          }
        }
      }
    } catch (_) {
      // Fall through to the baked corridor geometry below.
    }

    return getFallbackRoadPolyline(validStops);
  }

  /// Pre-fetched real street geometry for the known demonstration corridors
  /// (matched by the first and last stop), so offline sessions still draw and
  /// drive along the actual Katpadi / Vellore road network.
  List<LatLng> getFallbackRoadPolyline(List<Stop> stops) {
    final baked = CorridorRoadPaths.pathForEndpoints(
      stops.first.id,
      stops.last.id,
    );
    if (baked != null) return baked;

    final points = <LatLng>[];
    for (final stop in stops) {
      if (stop.latitude != null && stop.longitude != null) {
        points.add(LatLng(stop.latitude!, stop.longitude!));
      }
    }
    if (points.length < 2) {
      return CorridorRoadPaths.pathForEndpoints(
        'vit-main-gate',
        'katpadi-railway-station',
      )!;
    }
    return points;
  }
}
