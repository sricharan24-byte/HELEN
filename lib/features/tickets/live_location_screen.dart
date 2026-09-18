import 'package:flutter/material.dart' hide Route;

import '../../data/models/ticket_model.dart';
import '../../data/models/transport_models.dart';
import '../../data/repositories/transport_repository.dart';
import '../adaptive_ui/adaptive_ui_service.dart';
import '../journey/live_location_map_widget.dart';

class LiveLocationScreen extends StatefulWidget {
  const LiveLocationScreen({
    super.key,
    required this.ticket,
    required this.repository,
  });

  final Ticket ticket;
  final TransportRepository repository;

  @override
  State<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends State<LiveLocationScreen> {
  @override
  void initState() {
    super.initState();
    AdaptiveUiService.instance.recordLiveTracking(
      busId: widget.ticket.busId,
      routeId: widget.ticket.routeId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    final repository = widget.repository;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final routes = repository.findRoutes(
      originId: ticket.origin.id,
      destinationId: ticket.destination.id,
    );
    final route = routes.isNotEmpty ? routes.first : repository.allRoutes.first;

    final stops = <Stop>[
      for (final stopId in route.orderedStopIds)
        if (repository.getStop(stopId) != null) repository.getStop(stopId)!,
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: Text('Live Location • Bus ${ticket.busId}'),
        centerTitle: true,
        backgroundColor: const Color(0xFFF4F6F8),
        foregroundColor: const Color(0xFF002B7F),
        elevation: 0,
      ),
      body: StreamBuilder<BusLocation>(
        stream: repository.streamBusLocation(ticket.busId, route.id),
        builder: (context, snapshot) {
          final live = snapshot.data;
          final speed = live != null ? live.speedKmh.toStringAsFixed(0) : '32';
          final nextStop = live?.nextStopName ?? (stops.length > 1 ? stops[1].name : 'Next Stop');
          final eta = live != null ? '${live.etaMinutes} mins' : '4 mins';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ticket & Route Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.my_location, color: Color(0xFF059669), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ticket.routeName,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0A2540),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Pass #${ticket.id} • ${ticket.origin.name} → ${ticket.destination.name}',
                              style: textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Interactive Live Vector Map
                LiveLocationMapWidget(
                  stops: stops,
                  currentLocation: live,
                  originStopId: ticket.origin.id,
                  destinationStopId: ticket.destination.id,
                ),
                const SizedBox(height: 16),

                // Metrics Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        icon: Icons.speed,
                        iconColor: const Color(0xFF002B7F),
                        label: 'SPEED',
                        value: '$speed km/h',
                        textTheme: textTheme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        icon: Icons.timer,
                        iconColor: const Color(0xFF0284C7),
                        label: 'ETA TO NEXT',
                        value: eta,
                        textTheme: textTheme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        icon: Icons.near_me,
                        iconColor: const Color(0xFF059669),
                        label: 'NEXT STOP',
                        value: nextStop,
                        textTheme: textTheme,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Driver & Safety Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFE8EEFF),
                        foregroundColor: Color(0xFF002B7F),
                        child: Icon(Icons.person),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Driver: M. Ramanathan',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0A2540),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Vellore Transit Route #23 • Verified Driver',
                              style: textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Calling Driver M. Ramanathan...')),
                          );
                        },
                        icon: const Icon(Icons.phone, color: Color(0xFF002B7F)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Share Location Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showEmergencyShareDialog(context);
                    },
                    icon: const Icon(Icons.share_location, color: Color(0xFFE11D48)),
                    label: Text(
                      'Share Live Location with Emergency Contacts',
                      style: textTheme.titleSmall?.copyWith(
                        color: const Color(0xFFE11D48),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFECDD3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required TextTheme textTheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: const Color(0xFF64748B),
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0A2540),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showEmergencyShareDialog(BuildContext context) {
    final ticket = widget.ticket;
    final shareMessage =
        '🚨 BusBuddy Safety Alert: I am riding bus ${ticket.busId} from ${ticket.origin.name} to ${ticket.destination.name}.\nTrack my live trip: https://busbuddy.app/track/${ticket.id}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.security, color: Color(0xFFE11D48)),
            SizedBox(width: 10),
            Text('Share Live Location'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trip safety status message to share with emergency contacts:',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                shareMessage,
                style: const TextStyle(fontSize: 12, fontFamily: 'Monospace', color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening WhatsApp / Messages to share safety link...')),
              );
            },
            icon: const Icon(Icons.share, size: 16),
            label: const Text('Share Now'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE11D48)),
          ),
        ],
      ),
    );
  }
}
