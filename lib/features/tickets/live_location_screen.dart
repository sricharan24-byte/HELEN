import 'dart:async';
import 'package:flutter/material.dart' hide Route;

import '../../core/theme/app_theme.dart';
import '../../core/tokens/app_spacing.dart';
import '../../data/models/ticket_model.dart';
import '../../data/models/transport_models.dart';
import '../../data/repositories/transport_repository.dart';
import '../adaptive_ui/adaptive_ui_service.dart';
import '../../core/a11y/announcement_coordinator.dart';
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
  /// Bumped by the AppBar refresh action (and the error-card Retry button)
  /// to re-subscribe the live GPS stream.
  int _streamKey = 0;

  void _resubscribe() {
    setState(() => _streamKey++);
  }

  void _refreshLiveLocation() {
    _resubscribe();
    AnnouncementCoordinator.instance.announce(
      'Live location refresh requested. The latest bus position will appear below.',
    );
  }

  /// Formats a telemetry timestamp as HH:MM:SS for the "Updated" label.
  static String _formatUpdatedAt(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
  @override
  void initState() {
    super.initState();
    // Deferred past the first frame: recording notifies global listeners
    // (HomePage, AdaptiveShortcutsView), which must never run synchronously
    // inside initState while the pushed route is still mounting — that trips
    // setState-during-build when the navigator builds the new route in a
    // pass that is not an ancestor of the listeners.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AdaptiveUiService.instance.recordLiveTracking(
        busId: widget.ticket.busId,
        routeId: widget.ticket.routeId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    final repository = widget.repository;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colors = AppTheme.colors(context);

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
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('Live Location • Bus ${ticket.busId}'),
        centerTitle: true,
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh live location',
            onPressed: _refreshLiveLocation,
          ),
        ],
      ),
      body: StreamBuilder<BusLocation>(
        key: ValueKey<int>(_streamKey),
        stream: repository.streamBusLocation(
          ticket.busId,
          route.id,
          originStopId: ticket.origin.id,
          destinationStopId: ticket.destination.id,
        ),
        builder: (context, snapshot) {
          final live = snapshot.data;
          final routeDone =
              snapshot.connectionState == ConnectionState.done ||
              (live != null && live.progressPercentage >= 1.0);

          // Honest stream states: never invent telemetry. While the GPS
          // stream is still connecting (or has produced nothing yet) show a
          // muted waiting card; on a real stream error show the actual error
          // text with a Retry button that re-subscribes.
          if (snapshot.hasError) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRouteBanner(context, ticket),
                  const SizedBox(height: 16),
                  _buildErrorCard(context, snapshot.error!),
                ],
              ),
            );
          }
          final waiting = snapshot.connectionState == ConnectionState.waiting ||
              live == null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ticket & Route Banner
                _buildRouteBanner(context, ticket),
                const SizedBox(height: 16),

                // Interactive Live Vector Map
                LiveLocationMapWidget(
                  stops: stops,
                  currentLocation: live,
                  originStopId: ticket.origin.id,
                  destinationStopId: ticket.destination.id,
                ),
                const SizedBox(height: 16),

                // Route-complete state: the bus parked at the destination.
                // Shown instead of live telemetry once the stream terminates
                // so stale positions are never labeled live (BUS-P1-01).
                if (routeDone)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.statusSuccessBg,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusLg),
                      border: Border.all(color: colors.statusSuccess),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: colors.statusSuccess,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Route complete — Bus ${ticket.busId} has arrived at ${ticket.destination.name}.',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.statusSuccess,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (routeDone) const SizedBox(height: 16),

                // Waiting for the first GPS fix: honest placeholder, no
                // invented speed/ETA numbers.
                if (waiting)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusLg),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: colors.actionPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Waiting for live GPS…',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (waiting) const SizedBox(height: 16),

                // Metrics Grid (2+1: two compact cards on the top row, the
                // long station name full-width below so labels reflow).
                if (!waiting) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          context,
                          icon: Icons.speed,
                          iconColor: colors.actionPrimary,
                          label: 'SPEED',
                          value: '${live.speedKmh.toStringAsFixed(0)} km/h',
                          textTheme: textTheme,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          context,
                          icon: Icons.timer,
                          iconColor: colors.statusInfo,
                          label: 'ETA TO NEXT',
                          value: '${live.etaMinutes} mins',
                          textTheme: textTheme,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildMetricCard(
                    context,
                    icon: Icons.near_me,
                    iconColor: colors.statusSuccess,
                    label: 'NEXT STOP',
                    value: live.nextStopName,
                    textTheme: textTheme,
                  ),
                  const SizedBox(height: 16),
                ],

                // Last-updated timestamp from live telemetry (plain text, not
                // a live region: the stream ticks often and must not flood
                // TalkBack. Manual refresh announces politely on demand.)
                Semantics(
                  label: live != null
                      ? 'Live data updated at ${_formatUpdatedAt(live.receivedTimestamp ?? live.timestamp)}'
                      : 'Waiting for live data',
                  excludeSemantics: true,
                  child: Row(
                    children: [
                      Icon(
                        Icons.update,
                        size: 14,
                        color: colors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        live != null
                            ? 'Updated ${_formatUpdatedAt(live.receivedTimestamp ?? live.timestamp)}'
                            : 'Waiting for live data…',
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Driver & Safety Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: colors.statusInfoBg,
                        foregroundColor: colors.actionPrimary,
                        child: const Icon(Icons.person),
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
                                color: colors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Vellore Transit Route #23 • Verified Driver',
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Calling Driver M. Ramanathan...'),
                            ),
                          );
                        },
                        icon: Icon(Icons.phone, color: colors.actionPrimary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Share Location Button
                // BUS-P1-05: minimum height (not fixed) so the label can
                // reflow to two lines at 200-300% text scale.
                // Red is reserved exclusively for Emergency SOS — this is a
                // safety utility, so it uses the single accent instead.
                SizedBox(
                  width: double.infinity,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 52),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _showEmergencyShareDialog(context);
                      },
                      icon: Icon(
                        Icons.share_location,
                        color: colors.actionPrimary,
                      ),
                      label: Text(
                        'Share Live Location with Emergency Contacts',
                        style: textTheme.titleSmall?.copyWith(
                          color: colors.actionPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                      ),
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

  /// Ticket & route banner shown in every stream state.
  Widget _buildRouteBanner(BuildContext context, Ticket ticket) {
    final textTheme = Theme.of(context).textTheme;
    final colors = AppTheme.colors(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.statusSuccessBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.my_location,
              color: colors.statusSuccess,
              size: 24,
            ),
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
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Pass #${ticket.id} • ${ticket.origin.name} → ${ticket.destination.name}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Error card surfacing the real stream error with a Retry action that
  /// re-subscribes the GPS stream.
  Widget _buildErrorCard(BuildContext context, Object error) {
    final textTheme = Theme.of(context).textTheme;
    final colors = AppTheme.colors(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.statusAlertBg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: colors.statusError),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.satellite_alt, color: colors.statusError, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Live location unavailable',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: AppSpacing.minTouchTarget,
            child: OutlinedButton.icon(
              onPressed: _resubscribe,
              icon: Icon(Icons.refresh, color: colors.actionPrimary),
              label: Text(
                'Retry',
                style: textTheme.labelLarge?.copyWith(
                  color: colors.actionPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.actionPrimary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required TextTheme textTheme,
  }) {
    final colors = AppTheme.colors(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: colors.textMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
            // BUS-P1-05: metric values wrap instead of truncating
            // at large text scales.
            softWrap: true,
          ),
        ],
      ),
    );
  }

  void _showEmergencyShareDialog(BuildContext context) {
    final ticket = widget.ticket;
    final shareMessage =
        '🚨 BusBuddy Safety Alert: I am riding bus ${ticket.busId} from ${ticket.origin.name} to ${ticket.destination.name}.\nTrack my live trip: https://busbuddy.app/track/${ticket.id}';

    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) {
          final colors = AppTheme.colors(ctx);
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            title: Row(
              children: [
                Icon(Icons.security, color: colors.actionPrimary),
                const SizedBox(width: 10),
                const Text('Share Live Location'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trip safety status message to share with emergency contacts:',
                  style: TextStyle(fontSize: 13, color: colors.textMuted),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceSubtle,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: colors.border),
                  ),
                  child: Text(
                    shareMessage,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Monospace',
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
              // Red is reserved exclusively for Emergency SOS; this share
              // action uses the single action accent via the theme default.
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Opening WhatsApp / Messages to share safety link...',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Share Now'),
              ),
            ],
          );
        },
      ),
    );
  }
}
