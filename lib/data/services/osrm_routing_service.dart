import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/transport_models.dart';
import 'corridor_road_paths.dart';

enum RoutingOutcomeType {
  liveRoadRoute,
  bakedCorridorFallback,
  straightLineFallback,
}

enum RoutingFailureReason {
  timeout,
  offline,
  rateLimited,
  serverError,
  invalidResponse,
  noStops,
}

class RoutingOutcome {
  const RoutingOutcome({
    required this.points,
    required this.type,
    this.failureReason,
    this.errorMessage,
    required this.timestamp,
  });

  final List<LatLng> points;
  final RoutingOutcomeType type;
  final RoutingFailureReason? failureReason;
  final String? errorMessage;
  final DateTime timestamp;

  bool get isLiveRoadRoute => type == RoutingOutcomeType.liveRoadRoute;
  bool get isFallback => type != RoutingOutcomeType.liveRoadRoute;

  String get userStatusMessage {
    switch (type) {
      case RoutingOutcomeType.liveRoadRoute:
        return 'Live road network navigation active';
      case RoutingOutcomeType.bakedCorridorFallback:
        switch (failureReason) {
          case RoutingFailureReason.timeout:
            return 'Routing timed out — using offline corridor map';
          case RoutingFailureReason.rateLimited:
            return 'Routing rate-limited (429) — using offline corridor map';
          case RoutingFailureReason.serverError:
            return 'Routing server error — using offline corridor map';
          case RoutingFailureReason.invalidResponse:
            return 'Invalid route response — using offline corridor map';
          case RoutingFailureReason.offline:
          default:
            return 'Offline mode active — using offline corridor map';
        }
      case RoutingOutcomeType.straightLineFallback:
        return 'Geometric waypoint fallback active';
    }
  }
}

/// Service to fetch turn-by-turn real street road polyline geometry from
/// Open Source Routing Machine (OSRM) driving API with offline fallback to
/// pre-fetched corridor geometry (real OSM road paths baked at build time).
class OsrmRoutingService {
  const OsrmRoutingService({this.httpClient});

  final http.Client? httpClient;

  /// Fetches typed routing outcome with geometry and failure semantics.
  Future<RoutingOutcome> fetchRouteOutcome(
    List<Stop> stops, {
    http.Client? client,
  }) async {
    final validStops = stops
        .where((s) => s.latitude != null && s.longitude != null)
        .toList();

    if (validStops.length < 2) {
      final points = validStops.map((s) => LatLng(s.latitude!, s.longitude!)).toList();
      return RoutingOutcome(
        points: points,
        type: RoutingOutcomeType.straightLineFallback,
        failureReason: RoutingFailureReason.noStops,
        errorMessage: 'Insufficient valid stops to compute road route.',
        timestamp: DateTime.now(),
      );
    }

    final effectiveClient = client ?? httpClient ?? http.Client();
    final bool shouldCloseClient = client == null && httpClient == null;

    try {
      final coordsString = validStops
          .map((s) => '${s.longitude},${s.latitude}')
          .join(';');

      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coordsString?overview=full&geometries=geojson',
      );

      final response = await effectiveClient
          .get(url, headers: {'User-Agent': 'BusBuddy/1.0 (com.busbuddy.app)'})
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        if (response.body.length > 512 * 1024) {
          throw const FormatException('OSRM response payload exceeded 512KB safe limit.');
        }

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
            if (points.isNotEmpty) {
              return RoutingOutcome(
                points: points,
                type: RoutingOutcomeType.liveRoadRoute,
                timestamp: DateTime.now(),
              );
            }
          }
        }
        return RoutingOutcome(
          points: getFallbackRoadPolyline(validStops),
          type: RoutingOutcomeType.bakedCorridorFallback,
          failureReason: RoutingFailureReason.invalidResponse,
          errorMessage: 'OSRM 200 returned empty geometry.',
          timestamp: DateTime.now(),
        );
      } else if (response.statusCode == 429) {
        return RoutingOutcome(
          points: getFallbackRoadPolyline(validStops),
          type: RoutingOutcomeType.bakedCorridorFallback,
          failureReason: RoutingFailureReason.rateLimited,
          errorMessage: 'OSRM rate limit reached (HTTP 429).',
          timestamp: DateTime.now(),
        );
      } else if (response.statusCode >= 500) {
        return RoutingOutcome(
          points: getFallbackRoadPolyline(validStops),
          type: RoutingOutcomeType.bakedCorridorFallback,
          failureReason: RoutingFailureReason.serverError,
          errorMessage: 'OSRM server error (HTTP ${response.statusCode}).',
          timestamp: DateTime.now(),
        );
      } else {
        return RoutingOutcome(
          points: getFallbackRoadPolyline(validStops),
          type: RoutingOutcomeType.bakedCorridorFallback,
          failureReason: RoutingFailureReason.invalidResponse,
          errorMessage: 'OSRM HTTP error ${response.statusCode}.',
          timestamp: DateTime.now(),
        );
      }
    } on TimeoutException {
      return RoutingOutcome(
        points: getFallbackRoadPolyline(validStops),
        type: RoutingOutcomeType.bakedCorridorFallback,
        failureReason: RoutingFailureReason.timeout,
        errorMessage: 'OSRM network request timed out (4s).',
        timestamp: DateTime.now(),
      );
    } on SocketException {
      return RoutingOutcome(
        points: getFallbackRoadPolyline(validStops),
        type: RoutingOutcomeType.bakedCorridorFallback,
        failureReason: RoutingFailureReason.offline,
        errorMessage: 'Device is offline or socket unreachable.',
        timestamp: DateTime.now(),
      );
    } catch (e) {
      final isOffline = e.toString().contains('SocketException') ||
          e.toString().contains('ClientException') ||
          e.toString().contains('Failed host lookup');
      return RoutingOutcome(
        points: getFallbackRoadPolyline(validStops),
        type: RoutingOutcomeType.bakedCorridorFallback,
        failureReason: isOffline
            ? RoutingFailureReason.offline
            : RoutingFailureReason.invalidResponse,
        errorMessage: e.toString(),
        timestamp: DateTime.now(),
      );
    } finally {
      if (shouldCloseClient) {
        effectiveClient.close();
      }
    }
  }

  /// Fetches street-snapped polyline coordinates for a given list of bus stops.
  Future<List<LatLng>> fetchRoutePolyline(List<Stop> stops) async {
    final outcome = await fetchRouteOutcome(stops);
    return outcome.points;
  }

  /// Pre-fetched real street geometry for the known demonstration corridors
  /// (matched by the first and last stop), so offline sessions still draw and
  /// drive along the actual Katpadi / Vellore road network.
  List<LatLng> getFallbackRoadPolyline(List<Stop> stops) {
    if (stops.isEmpty) return const [];
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
