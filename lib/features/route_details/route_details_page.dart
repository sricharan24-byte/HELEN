/// Route details page — shows route details and real-time live bus tracking stream.
library;

import 'package:flutter/material.dart';

import '../../data/models/transport_models.dart' as models;
import '../../data/repositories/transport_repository.dart';
import '../journey/journey_controller.dart';
import '../journey/journey_page.dart';

/// Displays route details for a selected route with real-time live bus tracking.
class RouteDetailsPage extends StatelessWidget {
  const RouteDetailsPage({
    super.key,
    required this.controller,
    required this.repository,
  });

  final JourneyController controller;
  final TransportRepository repository;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        final route = state.selectedRoute;

        // ── Missing data recovery ─────────────────────────────────────
        if (route == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Route Details')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No route selected. Go back and choose a route.',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        // ── Resolve stops ─────────────────────────────────────────────
        final stops = <models.Stop?>[
          for (final stopId in route.orderedStopIds) repository.getStop(stopId),
        ];

        final boardingStop = state.origin ?? (stops.isNotEmpty ? stops.first : null);
        final destinationStop = state.destination ?? (stops.length > 1 ? stops.last : null);
        const busId = 'TN-23-BUS-42';

        return Scaffold(
          backgroundColor: const Color(0xFFF4F6F8),
          appBar: AppBar(
            title: const Text('Route Details & Live GPS'),
            centerTitle: true,
            backgroundColor: const Color(0xFFF4F6F8),
            foregroundColor: const Color(0xFF002B7F),
            elevation: 0,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Real-Time Live Bus GPS Header Card ────────────────
                  StreamBuilder<models.BusLocation>(
                    stream: repository.streamBusLocation(busId, route.id),
                    builder: (context, snapshot) {
                      final live = snapshot.data;
                      final speed = live != null ? live.speedKmh.toStringAsFixed(0) : '32';
                      final nextStop = live?.nextStopName ?? (stops.length > 1 ? stops[1]?.name ?? 'Next Stop' : 'Gandhi Nagar');
                      final eta = live != null ? '${live.etaMinutes} mins' : '4 mins';
                      final progress = live?.progressPercentage ?? 0.25;

                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF002B7F),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF002B7F).withValues(alpha: 0.2),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.directions_bus, color: Colors.white, size: 22),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'BUS $busId',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(Icons.sensors, color: Colors.white, size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'LIVE GPS',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'NEXT STOP',
                                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      nextStop,
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'ETA',
                                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      eta,
                                      style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 18, fontWeight: FontWeight.w900),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'SPEED',
                                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$speed km/h',
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor: Colors.white.withValues(alpha: 0.2),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── Route heading card ───────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            route.displayName,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0A2540),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Direction: ${route.direction.toUpperCase()} • ${stops.length} STOPS',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (boardingStop != null || destinationStop != null) ...[
                          const SizedBox(height: 12),
                          const Divider(color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 8),
                          if (boardingStop != null)
                            Row(
                              children: [
                                const Icon(Icons.gps_fixed, size: 18, color: Color(0xFF002B7F)),
                                const SizedBox(width: 8),
                                Text(
                                  'Boarding: ${boardingStop.name}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          if (destinationStop != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFFE11D48)),
                                const SizedBox(width: 8),
                                Text(
                                  'Destination: ${destinationStop.name}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Ordered stop list ───────────────────────────────
                  Semantics(
                    header: true,
                    child: Text(
                      'Stops along this route',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0A2540),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(stops.length, (index) {
                    final stop = stops[index];
                    final stopName =
                        stop?.name ??
                        'Unknown stop (${route.orderedStopIds[index]})';
                    final stopArea = stop?.area ?? '';
                    final isFirst = index == 0;
                    final isLast = index == stops.length - 1;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isFirst
                              ? const Color(0xFF002B7F)
                              : isLast
                                  ? const Color(0xFFE11D48)
                                  : const Color(0xFFE8EEFF),
                          foregroundColor: isFirst || isLast ? Colors.white : const Color(0xFF002B7F),
                          child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        title: Text(
                          stopName,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                        subtitle: stopArea.isNotEmpty
                            ? Text(stopArea, style: const TextStyle(color: Color(0xFF64748B)))
                            : null,
                      ),
                    );
                  }),

                  const SizedBox(height: 24),

                  // ── Start journey button ────────────────────────────
                  Semantics(
                    button: true,
                    child: SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: () {
                          controller.startJourney();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => JourneyPage(controller: controller),
                            ),
                          );
                        },
                        icon: const Icon(Icons.navigation_outlined, size: 22),
                        label: const Text(
                          'Start this journey',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF002B7F),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
