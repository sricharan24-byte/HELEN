import 'dart:async';
import 'package:flutter/material.dart' hide Route;

import '../../core/theme/app_theme.dart';
import '../../core/tokens/app_spacing.dart';
import '../../core/widgets/bus_buddy_logo.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/ticket_model.dart';
import '../../data/models/transport_models.dart';
import '../../data/repositories/transport_repository.dart';
import '../adaptive_ui/adaptive_ui_service.dart';
import '../../core/a11y/announcement_coordinator.dart';
import '../../features/ai_assistant/audio_speech_engine.dart';
import '../journey/live_location_map_widget.dart';
import 'ticket_controller.dart';

class LiveLocationScreen extends StatefulWidget {
  const LiveLocationScreen({
    super.key,
    required this.ticket,
    required this.repository,
    this.ticketController,
  });

  final Ticket ticket;
  final TransportRepository repository;

  /// Expires the ticket on arrival. Falls back to the shared instance so
  /// callers that only have a ticket snapshot still complete the trip.
  final TicketController? ticketController;

  @override
  State<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends State<LiveLocationScreen> {
  /// Bumped by the AppBar refresh action (and the error-card Retry button)
  /// to re-subscribe the live GPS stream.
  int _streamKey = 0;

  /// Route scope token for AnnouncementCoordinator lifecycle.
  AnnouncementScopeToken? _scopeToken;

  /// Tracks the last announced next stop name so we announce once per stop transition.
  String? _lastAnnouncedStop;

  /// Tracks if we already announced arrival for the current next stop.
  bool _hasAnnouncedCurrentStopArrival = false;

  /// Controls whether voice announcements are muted for this session.
  bool _isVoiceMuted = false;

  /// When true, the map expands to fill the entire screen.
  bool _isMapExpanded = false;

  void _toggleMapExpanded([bool? forceState]) {
    setState(() {
      _isMapExpanded = forceState ?? !_isMapExpanded;
    });
    AnnouncementCoordinator.instance.announce(
      _isMapExpanded
          ? 'Map expanded to full screen'
          : 'Returned to map window view',
      routeId: widget.ticket.routeId,
    );
  }

  /// Arrival is a one-shot: the dialog, countdown and expiry run exactly once
  /// even though the StreamBuilder rebuilds on every tick.
  bool _arrivalHandled = false;

  /// 10-second countdown that auto-returns to the home page after arrival.
  /// Cancelled in dispose so it can never fire on a popped route.
  Timer? _countdownTimer;
  int _countdownSeconds = 0;

  /// Refresh for the arrival dialog's countdown line, captured by the
  /// dialog's StatefulBuilder and cleared when the dialog closes.
  StateSetter? _dialogRefresh;

  TicketController get _tickets =>
      widget.ticketController ?? AppServiceLocator.instance.ticketController;

  @override
  void dispose() {
    _scopeToken?.dispose();
    _scopeToken = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    super.dispose();
  }

  /// Fires once when the stream reports the destination reached: expires the
  /// ticket, announces it, and opens the arrival dialog with its 10-second
  /// return-home countdown.
  void _onArrival() {
    if (_arrivalHandled || !mounted) return;
    _arrivalHandled = true;

    final ticket = widget.ticket;
    _tickets.completeTicket(ticket.id, reason: 'Reached destination');
    _tickets.completeActiveTrip(reason: 'Reached destination');
    AnnouncementCoordinator.instance.announce(
      'Destination reached: ${ticket.destination.name}. Your ticket has expired.',
      priority: AnnouncementPriority.urgent,
      routeId: widget.ticket.routeId,
    );
    _showArrivalDialog();
  }

  /// Dispatches accessible and spoken announcements for intermediate stop transitions
  /// and approaching stop notifications.
  void _handleStopAnnouncements(BusLocation live, String routeId) {
    if (_isVoiceMuted || _arrivalHandled) return;

    final nextStop = live.nextStopName.trim();
    if (nextStop.isEmpty) return;

    // 1. Stop transition: bus advances to a new next stop
    if (nextStop != _lastAnnouncedStop) {
      _lastAnnouncedStop = nextStop;
      _hasAnnouncedCurrentStopArrival = false;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isVoiceMuted || _arrivalHandled) return;
        final eta = live.etaMinutes;
        final message = eta <= 1
            ? 'Arriving at $nextStop now.'
            : 'Next stop: $nextStop. Estimated arrival in $eta minutes.';
        AnnouncementCoordinator.instance.announce(
          message,
          priority: AnnouncementPriority.high,
          routeId: routeId,
        );
      });
      return;
    }

    // 2. Approaching/Arriving alert: when ETA drops to 1 min or less and hasn't been announced yet
    if (live.etaMinutes <= 1 && !_hasAnnouncedCurrentStopArrival) {
      _hasAnnouncedCurrentStopArrival = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isVoiceMuted || _arrivalHandled) return;
        AnnouncementCoordinator.instance.announce(
          'Arriving at $nextStop now.',
          priority: AnnouncementPriority.high,
          routeId: routeId,
        );
      });
    }
  }

  void _showArrivalDialog() {
    final ticket = widget.ticket;
    _countdownSeconds = 10;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownSeconds <= 1) {
        timer.cancel();
        _returnHome();
        return;
      }
      _countdownSeconds--;
      // Repaint the dialog countdown without rebuilding the screen below.
      _dialogRefresh?.call(() {});
    });
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final colors = AppTheme.colors(ctx);
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              _dialogRefresh = setDialogState;
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                ),
                title: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: colors.statusSuccess,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Destination Reached')),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bus ${ticket.busId} has arrived at ${ticket.destination.name}. Your ticket has expired.',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Live map closing in $_countdownSeconds sec…',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: _returnHome,
                    child: const Text('Back to Home now'),
                  ),
                ],
              );
            },
          );
        },
      ).then((_) {
        _dialogRefresh = null;
      }),
    );
  }

  /// Dismisses the arrival dialog (if open) and returns to the home page.
  void _returnHome() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (!mounted) return;
    _tickets.completeTicket(widget.ticket.id, reason: 'Reached destination');
    _tickets.completeActiveTrip(reason: 'Reached destination');
    final navigator = Navigator.of(context);
    // The dialog is a route above this screen: close it first, then pop
    // everything back to the first (home) route.
    navigator.popUntil((route) => route.isFirst);
  }

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
    _scopeToken = AnnouncementCoordinator.instance.registerScope(widget.ticket.routeId);
    AudioSpeechEngine().unlockAudio();
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
        title: BusBuddyLogo(
          fontSize: 20,
          subtitle: _isMapExpanded
              ? 'Full Screen Map • Bus ${ticket.busId}'
              : 'Live Location • Bus ${ticket.busId}',
        ),
        centerTitle: true,
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isVoiceMuted ? Icons.volume_off : Icons.volume_up,
              color: _isVoiceMuted ? colors.textMuted : colors.actionPrimary,
            ),
            tooltip: _isVoiceMuted
                ? 'Unmute voice announcements'
                : 'Mute voice announcements',
            onPressed: () {
              setState(() {
                _isVoiceMuted = !_isVoiceMuted;
                AnnouncementCoordinator.instance.isSpeechEnabled = !_isVoiceMuted;
              });
              if (!_isVoiceMuted) {
                AnnouncementCoordinator.instance.announce(
                  'Voice announcements unmuted',
                  priority: AnnouncementPriority.high,
                  routeId: widget.ticket.routeId,
                );
              }
            },
          ),
          IconButton(
            icon: Icon(
              _isMapExpanded ? Icons.fullscreen_exit : Icons.fullscreen,
            ),
            tooltip: _isMapExpanded
                ? 'Exit full screen map'
                : 'Expand map to full screen',
            onPressed: () => _toggleMapExpanded(),
          ),
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

          // Arrival is stream completion (or 100% progress), never an error:
          // the dialog, expiry and countdown run exactly once, post-frame.
          if (routeDone && !_arrivalHandled && !snapshot.hasError) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _onArrival());
          } else if (live != null && !routeDone) {
            _handleStopAnnouncements(live, route.id);
          }

          // Full-screen map mode: map fills the entire viewport with floating
          // collapse button and telemetry badge.
          if (_isMapExpanded) {
            return Stack(
              children: [
                Positioned.fill(
                  child: LiveLocationMapWidget(
                    stops: stops,
                    currentLocation: live,
                    originStopId: ticket.origin.id,
                    destinationStopId: ticket.destination.id,
                    height: double.infinity,
                    isFullScreen: true,
                    onToggleFullScreen: () => _toggleMapExpanded(false),
                  ),
                ),
                // Floating Exit Full Screen pill button
                Positioned(
                  top: 16,
                  left: 16,
                  child: SafeArea(
                    child: Material(
                      elevation: 6,
                      color: colors.surface.withValues(alpha: 0.95),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusPill),
                      child: InkWell(
                        onTap: () => _toggleMapExpanded(false),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusPill),
                        child: Container(
                          constraints: const BoxConstraints(
                            minHeight: 48,
                            minWidth: 48,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusPill),
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.fullscreen_exit,
                                color: colors.actionPrimary,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Exit Full Screen',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Floating live telemetry card at bottom
                if (live != null)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 80,
                    child: SafeArea(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.82),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.speed,
                              color: colors.actionPrimary,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${live.speedKmh.toStringAsFixed(0)} km/h',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Icon(
                              Icons.near_me,
                              color: colors.statusSuccess,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Next: ${live.nextStopName}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }

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
                  const SizedBox(height: 16),
                  _buildSeatDetailsCard(context, ticket),
                  const SizedBox(height: 16),
                  _buildStopsTimeline(context, stops, live, ticket),
                  const SizedBox(height: 16),
                  _buildFeaturesAndActions(context, ticket),
                ],
              ),
            );
          }
          final waiting =
              snapshot.connectionState == ConnectionState.waiting ||
              live == null;

          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 800) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRouteBanner(context, ticket),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildMapWindow(
                                  context,
                                  stops,
                                  live,
                                  ticket,
                                  height: 320,
                                ),
                                const SizedBox(height: 16),
                                if (routeDone) ...[
                                  _buildRouteDoneCard(context, ticket),
                                  const SizedBox(height: 16),
                                ],
                                if (waiting) ...[
                                  _buildWaitingCard(context),
                                  const SizedBox(height: 16),
                                ],
                                if (!waiting) ...[
                                  _buildTelemetryCards(context, live),
                                  const SizedBox(height: 16),
                                ],
                                _buildUpdatedTimestamp(context, live),
                                const SizedBox(height: 16),
                                _buildDriverCard(context),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSeatDetailsCard(context, ticket),
                                const SizedBox(height: 16),
                                _buildStopsTimeline(
                                  context,
                                  stops,
                                  live,
                                  ticket,
                                ),
                                const SizedBox(height: 16),
                                _buildFeaturesAndActions(context, ticket),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }

              // Single-column layout for standard mobile / narrow viewport (< 800)
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ticket & Route Banner
                    _buildRouteBanner(context, ticket),
                    const SizedBox(height: 16),

                    // Small Map Window
                    _buildMapWindow(
                      context,
                      stops,
                      live,
                      ticket,
                      height: 260,
                    ),
                    const SizedBox(height: 16),

                    // Route-complete state: the bus parked at the destination.
                    if (routeDone) ...[
                      _buildRouteDoneCard(context, ticket),
                      const SizedBox(height: 16),
                    ],

                    // Waiting for the first GPS fix
                    if (waiting) ...[
                      _buildWaitingCard(context),
                      const SizedBox(height: 16),
                    ],

                    // Seat Details Card
                    _buildSeatDetailsCard(context, ticket),
                    const SizedBox(height: 16),

                    // Stops Details & Progress Timeline
                    _buildStopsTimeline(context, stops, live, ticket),
                    const SizedBox(height: 16),

                    // Telemetry Metrics Grid
                    if (!waiting) ...[
                      _buildTelemetryCards(context, live),
                      const SizedBox(height: 16),
                    ],

                    // Last-updated timestamp
                    _buildUpdatedTimestamp(context, live),
                    const SizedBox(height: 16),

                    // Trip Features & Controls (End Trip, Share Location)
                    _buildFeaturesAndActions(context, ticket),
                    const SizedBox(height: 16),

                    // Driver & Safety Card
                    _buildDriverCard(context),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
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
                  style: textTheme.bodySmall?.copyWith(color: colors.textMuted),
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
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final colors = AppTheme.colors(context);
    final cardContent = Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: iconColor, size: 20),
              if (trailing != null) trailing,
            ],
          ),
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

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: cardContent,
        ),
      );
    }
    return cardContent;
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
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
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

  Widget _buildMapWindow(
    BuildContext context,
    List<Stop> stops,
    BusLocation? live,
    Ticket ticket, {
    double height = 260.0,
  }) {
    final colors = AppTheme.colors(context);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.map, size: 18, color: colors.actionPrimary),
                const SizedBox(width: 8),
                Text(
                  'LIVE MAP WINDOW',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () => _toggleMapExpanded(true),
              icon: Icon(
                Icons.fullscreen,
                size: 20,
                color: colors.actionPrimary,
              ),
              label: Text(
                'Expand Map',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: colors.actionPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LiveLocationMapWidget(
          stops: stops,
          currentLocation: live,
          originStopId: ticket.origin.id,
          destinationStopId: ticket.destination.id,
          height: height,
          isFullScreen: false,
          onToggleFullScreen: () => _toggleMapExpanded(true),
        ),
      ],
    );
  }

  Widget _buildRouteDoneCard(BuildContext context, Ticket ticket) {
    final textTheme = Theme.of(context).textTheme;
    final colors = AppTheme.colors(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.statusSuccessBg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
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
    );
  }

  Widget _buildWaitingCard(BuildContext context) {
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
    );
  }

  Widget _buildSeatDetailsCard(BuildContext context, Ticket ticket) {
    final textTheme = Theme.of(context).textTheme;
    final colors = AppTheme.colors(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.event_seat,
                    color: colors.actionPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'SEAT DETAILS',
                    style: textTheme.labelLarge?.copyWith(
                      color: colors.actionPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.actionPrimary,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.airline_seat_recline_normal,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Seat ${ticket.seatAllocation}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: colors.border),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PASSENGER',
                      style: textTheme.labelSmall?.copyWith(
                        color: colors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ticket.passengerName,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ticket.passengerType.name.toUpperCase(),
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SEAT TYPE',
                      style: textTheme.labelSmall?.copyWith(
                        color: colors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ticket.seatType,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bus ${ticket.busId}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStopsTimeline(
    BuildContext context,
    List<Stop> stops,
    BusLocation? live,
    Ticket ticket,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final colors = AppTheme.colors(context);

    var startIndex = 0;
    var endIndex = stops.length - 1;
    final origIdx = stops.indexWhere((s) => s.id == ticket.origin.id);
    if (origIdx != -1) startIndex = origIdx;
    final destIdx = stops.indexWhere((s) => s.id == ticket.destination.id);
    if (destIdx != -1) endIndex = destIdx;
    final journeyStops = (startIndex <= endIndex)
        ? stops.sublist(startIndex, endIndex + 1)
        : stops;

    final nextStopName = live?.nextStopName.toLowerCase().trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.alt_route,
                    color: colors.actionPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'CORRIDOR STOPS',
                    style: textTheme.labelLarge?.copyWith(
                      color: colors.actionPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Text(
                '${journeyStops.length} stops',
                style: textTheme.labelSmall?.copyWith(
                  color: colors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: colors.border),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: journeyStops.length,
            separatorBuilder: (_, __) => Padding(
              padding: const EdgeInsets.only(left: 15),
              child: Container(
                width: 2,
                height: 14,
                color: colors.border,
              ),
            ),
            itemBuilder: (context, index) {
              final stop = journeyStops[index];
              final isOrigin = index == 0 || stop.id == ticket.origin.id;
              final isDestination = index == journeyStops.length - 1 ||
                  stop.id == ticket.destination.id;
              final isNext = nextStopName.isNotEmpty &&
                  (stop.name.toLowerCase().trim() == nextStopName ||
                      stop.name.toLowerCase().contains(nextStopName) ||
                      nextStopName.contains(stop.name.toLowerCase()));

              final Color nodeColor = isNext
                  ? colors.actionPrimary
                  : isOrigin
                      ? colors.statusSuccess
                      : isDestination
                          ? const Color(0xFFE11D48)
                          : colors.textMuted;

              final IconData nodeIcon = isNext
                  ? Icons.directions_bus
                  : isOrigin
                      ? Icons.location_on
                      : isDestination
                          ? Icons.flag
                          : Icons.radio_button_checked;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isNext
                          ? colors.statusInfoBg
                          : isOrigin
                              ? colors.statusSuccessBg
                              : isDestination
                                  ? colors.statusAlertBg
                                  : colors.surfaceSubtle,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: nodeColor,
                        width: isNext ? 2 : 1.5,
                      ),
                    ),
                    child: Icon(nodeIcon, size: 16, color: nodeColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                stop.name,
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight:
                                      (isNext || isOrigin || isDestination)
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                  color: isNext
                                      ? colors.actionPrimary
                                      : colors.textPrimary,
                                ),
                              ),
                            ),
                            if (isNext)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.actionPrimary,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusPill,
                                  ),
                                ),
                                child: const Text(
                                  'NEXT STOP',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              )
                            else if (isOrigin)
                              Text(
                                'Origin',
                                style: TextStyle(
                                  color: colors.statusSuccess,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            else if (isDestination)
                              const Text(
                                'Destination',
                                style: TextStyle(
                                  color: Color(0xFFE11D48),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                        if (stop.area.isNotEmpty)
                          Text(
                            stop.area,
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryCards(BuildContext context, BusLocation live) {
    final textTheme = Theme.of(context).textTheme;
    final colors = AppTheme.colors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          trailing: IconButton(
            icon: Icon(Icons.volume_up, color: colors.actionPrimary, size: 20),
            tooltip: 'Announce stop aloud',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: EdgeInsets.zero,
            onPressed: () {
              final eta = live.etaMinutes;
              final msg = eta <= 1
                  ? 'Arriving at ${live.nextStopName} now.'
                  : 'Next stop: ${live.nextStopName}. Estimated arrival in $eta minutes.';
              AnnouncementCoordinator.instance.announce(
                msg,
                priority: AnnouncementPriority.high,
                routeId: widget.ticket.routeId,
              );
            },
          ),
          onTap: () {
            final eta = live.etaMinutes;
            final msg = eta <= 1
                ? 'Arriving at ${live.nextStopName} now.'
                : 'Next stop: ${live.nextStopName}. Estimated arrival in $eta minutes.';
            AnnouncementCoordinator.instance.announce(
              msg,
              priority: AnnouncementPriority.high,
              routeId: widget.ticket.routeId,
            );
          },
        ),
      ],
    );
  }

  Widget _buildUpdatedTimestamp(BuildContext context, BusLocation? live) {
    final textTheme = Theme.of(context).textTheme;
    final colors = AppTheme.colors(context);
    return Semantics(
      label: live != null
          ? 'Live data updated at ${_formatUpdatedAt(live.receivedTimestamp ?? live.timestamp)}'
          : 'Waiting for live data',
      excludeSemantics: true,
      child: Row(
        children: [
          Icon(Icons.update, size: 14, color: colors.textMuted),
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
    );
  }

  Widget _buildDriverCard(BuildContext context) {
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
    );
  }

  Widget _buildFeaturesAndActions(BuildContext context, Ticket ticket) {
    final textTheme = Theme.of(context).textTheme;
    final colors = AppTheme.colors(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TRIP ACTIONS & CONTROLS',
          style: textTheme.labelLarge?.copyWith(
            color: colors.textMuted,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),

        // End Trip Button
        SizedBox(
          width: double.infinity,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: OutlinedButton.icon(
              onPressed: () => _confirmEndTrip(context, ticket),
              icon: Icon(
                Icons.stop_circle_outlined,
                color: colors.statusError,
              ),
              label: Text(
                'End Trip Now',
                style: textTheme.titleSmall?.copyWith(
                  color: colors.statusError,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.statusError),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Share Live Location Button
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
                  borderRadius: BorderRadius.circular(
                    AppSpacing.radiusMd,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmEndTrip(BuildContext context, Ticket ticket) {
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
                Icon(
                  Icons.exit_to_app,
                  color: colors.statusError,
                  size: 26,
                ),
                const SizedBox(width: 10),
                const Text('End Current Trip?'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to end your trip on Bus ${ticket.busId}? '
                  'Your active ticket #${ticket.id} will be completed and live tracking will stop.',
                ),
                const SizedBox(height: 10),
                Text(
                  'Seat ${ticket.seatAllocation} • ${ticket.origin.name} → ${ticket.destination.name}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Continue Trip'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.statusError,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _executeEndTrip(ticket);
                },
                child: const Text('End Trip'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _executeEndTrip(Ticket ticket) {
    _tickets.completeTicket(ticket.id, reason: 'Trip ended by passenger');
    _tickets.completeActiveTrip(reason: 'Trip ended by passenger');
    AnnouncementCoordinator.instance.announce(
      'Trip ended. Your ticket has expired.',
      priority: AnnouncementPriority.high,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Trip ended for Ticket #${ticket.id}.'),
      ),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
