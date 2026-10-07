import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models/transport_models.dart';
import '../../data/services/osrm_routing_service.dart';

/// Real interactive OpenStreetMap tile map displaying Vellore & Katpadi corridors,
/// real turn-by-turn street road polylines (OSRM API), stop markers, and live bus position.
class LiveLocationMapWidget extends StatefulWidget {
  const LiveLocationMapWidget({
    super.key,
    required this.stops,
    this.currentLocation,
    this.originStopId,
    this.destinationStopId,
    this.height,
    this.isFullScreen = false,
    this.onToggleFullScreen,
  });

  final List<Stop> stops;
  final BusLocation? currentLocation;
  final String? originStopId;
  final String? destinationStopId;
  final double? height;
  final bool isFullScreen;
  final VoidCallback? onToggleFullScreen;

  /// Test seam: widget tests replace the network tile provider so pumpAndSettle
  /// never races against tile HTTP responses (the test binding answers every
  /// tile request with a 400, and the resulting image exceptions are flaky).
  static TileProvider Function()? debugTileProviderFactory;

  @override
  State<LiveLocationMapWidget> createState() => _LiveLocationMapWidgetState();
}

class _LiveLocationMapWidgetState extends State<LiveLocationMapWidget> {
  final MapController _mapController = MapController();
  final OsrmRoutingService _routingService = const OsrmRoutingService();

  List<LatLng> _roadPolylinePoints = [];

  /// Only the stops on the passenger's own journey segment (boarding stop →
  /// alighting stop) are shown, so the map never draws unrelated corridor
  /// stops or detours beyond the user's start and end point.
  List<Stop> get _journeyStops {
    final stops = widget.stops;
    if (stops.isEmpty) return stops;

    var startIndex = 0;
    var endIndex = stops.length - 1;
    if (widget.originStopId != null) {
      final i = stops.indexWhere((s) => s.id == widget.originStopId);
      if (i != -1) startIndex = i;
    }
    if (widget.destinationStopId != null) {
      final i = stops.indexWhere((s) => s.id == widget.destinationStopId);
      if (i != -1) endIndex = i;
    }
    if (startIndex > endIndex) return stops;
    return stops.sublist(startIndex, endIndex + 1);
  }

  RoutingOutcome? _routingOutcome;
  bool _isLoadingRoute = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRoadPolyline());
  }

  @override
  void didUpdateWidget(covariant LiveLocationMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stops != widget.stops ||
        oldWidget.originStopId != widget.originStopId ||
        oldWidget.destinationStopId != widget.destinationStopId) {
      unawaited(_loadRoadPolyline());
    }
  }

  Future<void> _loadRoadPolyline() async {
    setState(() => _isLoadingRoute = true);
    final outcome = await _routingService.fetchRouteOutcome(_journeyStops);
    if (mounted) {
      setState(() {
        _routingOutcome = outcome;
        _roadPolylinePoints = outcome.points;
        _isLoadingRoute = false;
      });
    }
  }

  LatLng get _initialCenter {
    if (widget.currentLocation != null) {
      return LatLng(
        widget.currentLocation!.latitude,
        widget.currentLocation!.longitude,
      );
    }
    final journeyStops = _journeyStops;
    if (journeyStops.isNotEmpty && journeyStops.first.latitude != null) {
      return LatLng(
        journeyStops.first.latitude!,
        journeyStops.first.longitude!,
      );
    }
    // Default Vellore VIT Main Gate
    return const LatLng(12.96813, 79.15553);
  }

  void _recenterMap() {
    _mapController.move(_initialCenter, 14.5);
  }

  @override
  Widget build(BuildContext context) {
    // Direct stop points fallback
    final journeyStops = _journeyStops;
    final progress = widget.currentLocation?.progressPercentage ?? 0.3;
    final nextStopName = widget.currentLocation?.nextStopName ??
        (journeyStops.length > 1 ? journeyStops[1].name : 'Next Stop');
    final speed = widget.currentLocation != null
        ? widget.currentLocation!.speedKmh.toStringAsFixed(0)
        : '32';

    final fallbackStopPoints = journeyStops
        .where((s) => s.latitude != null && s.longitude != null)
        .map((s) => LatLng(s.latitude!, s.longitude!))
        .toList();

    final polylinePoints = _roadPolylinePoints.isNotEmpty
        ? _roadPolylinePoints
        : fallbackStopPoints;

    // Build stop markers for the passenger's journey segment only
    final markers = <Marker>[];
    for (int i = 0; i < journeyStops.length; i++) {
      final stop = journeyStops[i];
      if (stop.latitude == null || stop.longitude == null) continue;

      final isOrigin = stop.id == widget.originStopId || i == 0;
      final isDestination =
          stop.id == widget.destinationStopId || i == journeyStops.length - 1;

      markers.add(
        Marker(
          point: LatLng(stop.latitude!, stop.longitude!),
          width: 32,
          height: 32,
          child: Tooltip(
            message: '${stop.name} (${stop.area})',
            child: Container(
              decoration: BoxDecoration(
                color: isOrigin
                    ? const Color(0xFF16A34A)
                    : isDestination
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF1E293B),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: Icon(
                isOrigin
                    ? Icons.location_on
                    : isDestination
                        ? Icons.flag
                        : Icons.directions_bus_outlined,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      );
    }

    // Add Live Bus Marker
    if (widget.currentLocation != null) {
      markers.add(
        Marker(
          point: LatLng(
            widget.currentLocation!.latitude,
            widget.currentLocation!.longitude,
          ),
          width: 44,
          height: 44,
          child: Tooltip(
            message: 'Bus ${widget.currentLocation!.busId} • $speed km/h',
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF007AFF).withValues(alpha: 0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
                border: Border.all(color: Colors.white, width: 2.5),
              ),
              child: const Icon(
                Icons.directions_bus,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      );
    }

    final mapHeight =
        widget.isFullScreen ? double.infinity : (widget.height ?? 260.0);
    final borderRadius =
        widget.isFullScreen ? BorderRadius.zero : BorderRadius.circular(20);

    return Container(
      height: mapHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: borderRadius,
        boxShadow: widget.isFullScreen
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          children: [
            // Real Interactive OpenStreetMap Engine Canvas
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                // Frame the passenger's own start → end segment on first show;
                // the camera fit takes precedence over the default center.
                initialCameraFit: fallbackStopPoints.length >= 2
                    ? CameraFit.coordinates(
                        coordinates: fallbackStopPoints,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 44,
                        ),
                        maxZoom: 15.5,
                      )
                    : null,
                initialCenter: fallbackStopPoints.length >= 2
                    ? fallbackStopPoints.first
                    : _initialCenter,
                initialZoom: fallbackStopPoints.length >= 2 ? 13.5 : 14.2,
                minZoom: 10.0,
                maxZoom: 18.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                // OpenStreetMap Tile Layer
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.busbuddy.app',
                  tileProvider: LiveLocationMapWidget
                          .debugTileProviderFactory
                          ?.call() ??
                      NetworkTileProvider(
                        headers: {
                          'User-Agent': 'BusBuddy/1.0 (com.busbuddy.app)'
                        },
                      ),
                  errorTileCallback: (tile, error, stackTrace) {
                    // Handled gracefully without crash
                  },
                ),

                // Real Turn-by-Turn Street Polyline Layer
                if (polylinePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: polylinePoints,
                        strokeWidth: 5.5,
                        color: const Color(0xFF007AFF),
                      ),
                    ],
                  ),

                // Stop & Live Bus Marker Layer
                MarkerLayer(markers: markers),
              ],
            ),

            // Top Status Bar Overlay
            Positioned(
              top: 14,
              left: 14,
              right: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'LIVE GPS • $speed km/h',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Next: $nextStopName',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (widget.onToggleFullScreen != null) ...[
                        const SizedBox(width: 8),
                        Tooltip(
                          message: widget.isFullScreen
                              ? 'Exit full screen map'
                              : 'Expand map to full screen',
                          child: Material(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: widget.onToggleFullScreen,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                constraints: const BoxConstraints(minWidth: 44, minHeight: 32),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white30),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      widget.isFullScreen
                                          ? Icons.fullscreen_exit
                                          : Icons.fullscreen,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.isFullScreen ? 'Exit' : 'Expand',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Persistent Offline / Fallback Route Status Banner
            if (_routingOutcome != null && _routingOutcome!.isFallback)
              Positioned(
                top: 52,
                left: 14,
                right: 14,
                child: Semantics(
                  liveRegion: true,
                  label: _routingOutcome!.userStatusMessage,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF59E0B), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_off_outlined, color: Color(0xFFF59E0B), size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _routingOutcome!.userStatusMessage,
                            style: const TextStyle(
                              color: Color(0xFFFDE68A),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: _isLoadingRoute ? null : _loadRoadPolyline,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _isLoadingRoute
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFF59E0B)),
                                  )
                                : const Text(
                                    'Retry',
                                    style: TextStyle(
                                      color: Color(0xFF38BDF8),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Recenter Action Button (Bottom Right)
            Positioned(
              bottom: 54,
              right: 14,
              child: Material(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: _recenterMap,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Route Polyline Progress Bar
            Positioned(
              bottom: 14,
              left: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.gps_fixed, color: Color(0xFF38BDF8), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.flag_outlined, color: Color(0xFFF43F5E), size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}
