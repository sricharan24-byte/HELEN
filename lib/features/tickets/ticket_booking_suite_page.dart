import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/a11y/announcement_coordinator.dart';
import '../../core/settings/app_settings_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/tokens/app_spacing.dart';
import '../../core/widgets/bus_buddy_logo.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/ticket_model.dart';
import '../../data/models/transport_models.dart';
import '../../data/repositories/transport_repository.dart';
import '../../domain/ticketing/entities/fare_engine.dart';
import '../adaptive_ui/adaptive_ui_service.dart';
import '../ai_assistant/gemini_live_screen.dart';
import '../journey/journey_controller.dart';
import '../journey/live_location_map_widget.dart';
import '../safety/safety_sharing_page.dart';
import '../saved/saved_place_chips.dart';
import 'booking_checkout_dialog.dart';
import 'live_location_screen.dart';
import 'ticket_controller.dart';

/// Unified 3-Step Ticket Booking & Active Trip Suite page matching the master UI screenshots.
class TicketBookingSuitePage extends StatefulWidget {
  const TicketBookingSuitePage({
    super.key,
    required this.ticketController,
    this.journeyController,
    this.initialStepIndex = 0,
    this.showTopPrototypeTabs = false,
    this.initialOrigin,
    this.initialDestination,
    this.initialBusId,
    this.initialPassengerType = PassengerType.general,
    this.initialPaymentMethod = PaymentMethod.upi,
    this.initialPassengerName,
    this.autoOpenCheckout = false,
  });

  final TicketController ticketController;
  final JourneyController? journeyController;
  final int initialStepIndex;
  final bool showTopPrototypeTabs;
  final Stop? initialOrigin;
  final Stop? initialDestination;
  final String? initialBusId;
  final PassengerType initialPassengerType;
  final PaymentMethod initialPaymentMethod;
  final String? initialPassengerName;
  final bool autoOpenCheckout;

  @override
  State<TicketBookingSuitePage> createState() => _TicketBookingSuitePageState();
}

class _TicketBookingSuitePageState extends State<TicketBookingSuitePage> {
  late int _activeStepIndex;

  late final TransportRepository _repository;
  late List<Stop> _allStops;
  late Stop _origin;
  late Stop _destination;
  late DateTime _selectedDate;
  late String _selectedDateText;
  bool _isAnnouncementsOn = true;
  String _selectedBusId = '18B';
  bool _isCurrentLocation = true;
  String? _lastAnnouncedStop;
  bool _hasAnnouncedCurrentStopArrival = false;
  AnnouncementScopeToken? _scopeToken;

  /// Saved places resolved against the loaded stops, in the passenger's saved
  /// order. Unknown IDs (e.g. a stop removed from fixtures) are skipped so a
  /// stale entry can never break the pickers.
  List<Stop> _savedPlaceStops() {
    final byId = {for (final s in _allStops) s.id: s};
    return [
      for (final id in AppSettingsController.instance.savedPlaceStopIds)
        if (byId.containsKey(id)) byId[id]!,
    ];
  }

  /// Star toggle shared by the origin and destination picker rows. The sheets
  /// rebuild through a ListenableBuilder on the settings controller, so the
  /// toggle needs no local setState.
  Widget _saveStarToggle(Stop stop) {
    final colors = AppTheme.colors(context);
    final saved = AppSettingsController.instance.isPlaceSaved(stop.id);
    return IconButton(
      icon: Icon(
        saved ? Icons.star : Icons.star_outline,
        color: saved ? colors.actionPrimary : colors.textSecondary,
      ),
      tooltip: saved
          ? 'Remove ${stop.name} from saved places'
          : 'Save ${stop.name} to saved places',
      onPressed: () => AppSettingsController.instance.toggleSavedPlace(
        stop.id,
        save: !saved,
      ),
    );
  }

  bool _hasArrived = false;
  bool _tripActionInFlight = false;

  static String _formatSelectedDate(DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final prefix = isToday ? 'Today' : 'Selected';
    return '$prefix, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  void initState() {
    super.initState();
    _activeStepIndex = widget.initialStepIndex;

    _repository = AppServiceLocator.instance.transportRepository;
    _allStops = AppServiceLocator.instance.transportDataSource.allStops;
    _selectedDate = DateTime.now();
    _selectedDateText = _formatSelectedDate(_selectedDate);

    const fallbackOrigin = Stop(
      id: 'vit-main-gate',
      name: 'VIT Main Gate',
      area: 'Vellore',
    );
    const fallbackDestination = Stop(
      id: 'katpadi-railway-station',
      name: 'Katpadi Railway Station',
      area: 'Katpadi',
    );

    if (widget.initialOrigin != null) {
      _origin = widget.initialOrigin!;
      _isCurrentLocation = _origin.name.contains('VIT');
    } else {
      _origin = _allStops.firstWhere(
        (s) => s.name.contains('VIT'),
        orElse: () => _allStops.isNotEmpty ? _allStops.first : fallbackOrigin,
      );
      _isCurrentLocation = true;
    }

    if (widget.initialDestination != null) {
      _destination = widget.initialDestination!;
    } else {
      // Default to the corridor terminus (Katpadi Railway Station), not an
      // intermediate Katpadi stop. firstWhere(name.contains('Katpadi')) would
      // match 'Katpadi Bus Stand' first since it appears earlier in fixtures.
      _destination = _allStops.firstWhere(
        (s) => s.name == 'Katpadi Railway Station',
        orElse: () => _allStops.firstWhere(
          (s) => s.name.contains('Katpadi'),
          orElse: () => _allStops.length > 1
              ? _allStops[1]
              : (_allStops.isNotEmpty ? _allStops.first : fallbackDestination),
        ),
      );
    }

    if (widget.initialBusId != null && widget.initialBusId!.isNotEmpty) {
      _selectedBusId = widget.initialBusId!;
    }
    if (widget.autoOpenCheckout) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openCheckoutDialog(
          busId: _selectedBusId,
          routeName: _resolveRouteDisplayName(),
          routeId: _resolveRouteId(),
        );
      });
    }
  }

  String _resolveRouteDisplayName() {
    try {
      final dataSource = AppServiceLocator.instance.transportDataSource;
      final route = dataSource.allRoutes.firstWhere(
        (r) => r.id == _resolveRouteId(),
      );
      return route.displayName;
    } catch (_) {
      return 'VIT → Katpadi';
    }
  }

  void _openOriginPicker() {
    final colors = AppTheme.colors(context);
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: colors.background,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusLg),
          ),
        ),
        builder: (context) {
          // Reactive to the settings controller so the star toggles repaint
          // without local setState (the sheet is a separate route).
          return ListenableBuilder(
            listenable: AppSettingsController.instance,
            builder: (context, _) {
              return Material(
                color: colors.background,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.7,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Origin Stop',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          leading: Icon(
                            Icons.my_location,
                            color: colors.actionPrimary,
                          ),
                          title: Text(
                            'Current Location (VIT Main Gate)',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onTap: () {
                            setState(() {
                              _isCurrentLocation = true;
                              _origin = _allStops.firstWhere(
                                (s) => s.name.contains('VIT'),
                                orElse: () => _allStops.isNotEmpty
                                    ? _allStops.first
                                    : const Stop(
                                        id: 'vit-main-gate',
                                        name: 'VIT Main Gate',
                                        area: 'Vellore',
                                      ),
                              );
                            });
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                      Divider(color: colors.border),
                      Expanded(
                        child: ListView(
                          children: _allStops.map((stop) {
                            final isSelected =
                                !_isCurrentLocation && stop.id == _origin.id;
                            return Material(
                              color: Colors.transparent,
                              child: ListTile(
                                leading: Icon(
                                  Icons.location_on,
                                  color: isSelected
                                      ? colors.actionPrimary
                                      : colors.textSecondary,
                                ),
                                title: Text(
                                  stop.name,
                                  style: TextStyle(
                                    color: isSelected
                                        ? colors.actionPrimary
                                        : colors.textPrimary,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  stop.area,
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                // Star/unstar without leaving the picker.
                                trailing: _saveStarToggle(stop),
                                onTap: () {
                                  setState(() {
                                    _isCurrentLocation = false;
                                    _origin = stop;
                                  });
                                  Navigator.of(context).pop();
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openDestinationPicker() {
    final colors = AppTheme.colors(context);
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: colors.background,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusLg),
          ),
        ),
        builder: (context) {
          return ListenableBuilder(
            listenable: AppSettingsController.instance,
            builder: (context, _) {
              return Material(
                color: colors.background,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.7,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Destination Stop',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView(
                          children: _allStops.map((stop) {
                            final isSelected = stop.id == _destination.id;
                            return Material(
                              color: Colors.transparent,
                              child: ListTile(
                                leading: Icon(
                                  Icons.location_on,
                                  color: isSelected
                                      ? colors.actionPrimary
                                      : colors.textSecondary,
                                ),
                                title: Text(
                                  stop.name,
                                  style: TextStyle(
                                    color: isSelected
                                        ? colors.actionPrimary
                                        : colors.textPrimary,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  stop.area,
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                // Star/unstar without leaving the picker.
                                trailing: _saveStarToggle(stop),
                                onTap: () {
                                  setState(() {
                                    _destination = stop;
                                  });
                                  Navigator.of(context).pop();
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openDatePicker() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(today) ? today : _selectedDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedDateText = _formatSelectedDate(picked);
      });
    }
  }

  void _openAiAssistant() {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GeminiLiveScreen(
            ticketController: widget.ticketController,
            repository: AppServiceLocator.instance.transportRepository,
            journeyController: widget.journeyController,
          ),
        ),
      ),
    );
  }

  FareQuote _calculateCurrentFareQuote() {
    final routeId = _resolveRouteId();
    final dataSource = AppServiceLocator.instance.transportDataSource;
    final route = dataSource.allRoutes.firstWhere(
      (r) => r.id == routeId,
      orElse: () => dataSource.allRoutes.first,
    );
    final o = route.orderedStopIds.indexOf(_origin.id);
    final d = route.orderedStopIds.indexOf(_destination.id);
    final hops = (o != -1 && d != -1 && d > o)
        ? (d - o)
        : (o != -1 && d != -1)
        ? (d - o).abs()
        : 4;
    return FareEngine.calculateByStopCount(
      stopCount: hops > 0 ? hops : 1,
      passengerType: PassengerType.general,
    );
  }

  void _openCheckoutDialog({
    required String busId,
    required String routeName,
    FareQuote? fareQuote,
    String? routeId,
  }) {
    final quote = fareQuote ?? _calculateCurrentFareQuote();
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return BookingCheckoutDialog(
            busId: busId,
            routeName: routeName,
            origin: _origin,
            destination: _destination,
            initialFareQuote: quote,
            routeId: routeId ?? _resolveRouteId(),
            travelDate: _selectedDate,
            initialPassengerType: widget.initialPassengerType,
            initialPaymentMethod: widget.initialPaymentMethod,
            initialPassengerName: widget.initialPassengerName,
            onTicketBooked: (ticket) {
              AdaptiveUiService.instance.recordTicketBooking(
                originName: ticket.origin.name,
                destinationName: ticket.destination.name,
                busId: ticket.busId,
                routeId: ticket.routeId,
              );
              widget.ticketController.addTicket(ticket);
              _startTripForTicket(ticket);
              setState(() {
                _selectedBusId = ticket.busId;
                _activeStepIndex = 2;
                _hasArrived = false;
                _lastAnnouncedStop = null;
              });
            },
          );
        },
      ),
    );
  }

  String _resolveRouteId() {
    final routes = AppServiceLocator.instance.transportDataSource.allRoutes;
    for (final route in routes) {
      final o = route.orderedStopIds.indexOf(_origin.id);
      final d = route.orderedStopIds.indexOf(_destination.id);
      if (o != -1 && d != -1 && o < d) {
        return route.id;
      }
    }
    return 'vit-to-katpadi';
  }

  /// Starts the journey session the moment a ticket is issued so the trip,
  /// the live bus, and the ticket lifecycle stay in lockstep.
  void _startTripForTicket(Ticket ticket) {
    final journey = widget.journeyController;
    if (journey == null) return;
    journey.selectOrigin(ticket.origin);
    journey.selectDestination(ticket.destination);
    final dataSource = AppServiceLocator.instance.transportDataSource;
    final route = dataSource.allRoutes.firstWhere(
      (r) => r.id == ticket.routeId,
      orElse: () => dataSource.allRoutes.first,
    );
    journey.selectRoute(route);
    journey.startJourney(busId: ticket.busId);
    AnnouncementCoordinator.instance.announce(
      'Trip started. Bus ${ticket.busId} is on its way from ${ticket.origin.name} to ${ticket.destination.name}.',
      routeId: ticket.routeId,
    );
  }

  /// Completes the ride: the ticket expires, the journey session closes,
  /// and the movement engine is torn down. [arrived] distinguishes destination
  /// arrival from an early End Trip (e.g. alighting mid-route).
  Future<void> _endTrip({required bool arrived}) async {
    if (_tripActionInFlight || !mounted) return;
    setState(() => _tripActionInFlight = true);
    try {
      widget.ticketController.completeActiveTrip(
        reason: arrived ? 'Reached destination' : 'Trip ended early by rider',
      );
      final journey = widget.journeyController;
      if (journey != null) {
        await journey.completeJourney();
      }
      await _repository.stopJourney(_selectedBusId, _resolveRouteId());
      AnnouncementCoordinator.instance.announce(
        'Reached ${_destination.name}. Your ticket has expired.',
        routeId: _resolveRouteId(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reached destination. Ticket expired.')),
      );
      setState(() {
        _activeStepIndex = 0;
        _hasArrived = false;
        _lastAnnouncedStop = null;
      });
    } finally {
      if (mounted) {
        setState(() => _tripActionInFlight = false);
      }
    }
  }

  /// Cancels the active ticket with explicit confirmation. The journey
  /// session resets and the movement engine is torn down.
  Future<void> _cancelActiveTicket() async {
    if (_tripActionInFlight || !mounted) return;
    final dialogColors = AppTheme.colors(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this ticket?'),
        content: const Text(
          'Your active ticket will be cancelled and the trip will end. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Ticket'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: dialogColors.actionPrimary,
            ),
            child: Text(
              'Cancel Ticket',
              style: TextStyle(color: dialogColors.onActionPrimary),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _tripActionInFlight = true);
    try {
      widget.ticketController.cancelActiveTicket();
      final journey = widget.journeyController;
      if (journey != null) {
        await journey.reset();
      }
      await _repository.stopJourney(_selectedBusId, _resolveRouteId());
      AnnouncementCoordinator.instance.announce(
        'Ticket cancelled. The trip has ended.',
        routeId: _resolveRouteId(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ticket cancelled.')));
      setState(() {
        _activeStepIndex = 0;
        _hasArrived = false;
        _lastAnnouncedStop = null;
      });
    } finally {
      if (mounted) {
        setState(() => _tripActionInFlight = false);
      }
    }
  }

  void _confirmEndTrip({required bool arrived}) {
    if (_tripActionInFlight) return;
    final dialogColors = AppTheme.colors(context);
    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(arrived ? 'Complete your journey?' : 'End trip early?'),
          content: Text(
            arrived
                ? 'You have reached ${_destination.name}. Your ticket will expire.'
                : 'The bus has not reached ${_destination.name} yet. Your ticket will expire and the trip will end now.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep Riding'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                unawaited(_endTrip(arrived: arrived));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: dialogColors.actionPrimary,
              ),
              child: Text(
                'End Trip',
                style: TextStyle(color: dialogColors.onActionPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Stops on the passenger's own journey segment of the active route
  /// (boarding stop through alighting stop), in travel order.
  List<Stop> get _activeRouteStops {
    final dataSource = AppServiceLocator.instance.transportDataSource;
    final route = dataSource.allRoutes.firstWhere(
      (r) => r.id == _resolveRouteId(),
      orElse: () => dataSource.allRoutes.first,
    );
    final ordered = <Stop>[];
    for (final id in route.orderedStopIds) {
      final stop = dataSource.stopById(id);
      if (stop != null) ordered.add(stop);
    }
    final startIndex = ordered.indexWhere((s) => s.id == _origin.id);
    final endIndex = ordered.indexWhere((s) => s.id == _destination.id);
    if (startIndex == -1 || endIndex == -1 || startIndex > endIndex) {
      return ordered;
    }
    return ordered.sublist(startIndex, endIndex + 1);
  }

  /// Next real stop the bus reaches after the boarding stop.
  String _upcomingStopName() {
    final stops = _activeRouteStops;
    if (stops.length > 1) return stops[1].name;
    return _destination.name;
  }

  int _calculateRemainingStops([BusLocation? live]) {
    if (live != null && live.nextStopId.isNotEmpty) {
      final idx = _activeRouteStops.indexWhere((s) => s.id == live.nextStopId);
      if (idx != -1) {
        return (_activeRouteStops.length - idx).clamp(0, 50);
      }
    }
    final routes = AppServiceLocator.instance.transportDataSource.allRoutes;
    for (final route in routes) {
      final o = route.orderedStopIds.indexOf(_origin.id);
      final d = route.orderedStopIds.indexOf(_destination.id);
      if (o != -1 && d != -1 && o < d) {
        final totalStops = d - o;
        return (totalStops > 3 ? 3 : totalStops).clamp(1, 10);
      }
    }
    return (_activeRouteStops.length > 1 ? _activeRouteStops.length - 1 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: PreferredSize(
        // 48dp step tabs + the 56dp sub app bar need 120dp; a little slack
        // keeps the taller accessible tabs from clipping in the app bar.
        preferredSize: Size.fromHeight(widget.showTopPrototypeTabs ? 124 : 56),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Prototype Header Tabs (1. Booking | 2. Results | 3. Active Trip)
              if (widget.showTopPrototypeTabs)
                Container(
                  color: colors.background,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStepTab(0, '1. Booking'),
                      _buildStepTab(1, '2. Results'),
                      _buildStepTab(2, '3. Active Trip'),
                    ],
                  ),
                ),

              // Sub App Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                      onPressed: () {
                        unawaited(Navigator.of(context).maybePop());
                      },
                    ),
                    const SizedBox(width: 8),
                    const BusBuddyLogo(fontSize: 20),
                    const Spacer(),
                    Text(
                      _activeStepIndex == 0
                          ? 'Book a Ticket'
                          : _activeStepIndex == 1
                          ? 'Available Buses'
                          : 'My Journey',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: IndexedStack(
        index: _activeStepIndex,
        children: [
          _buildBookingStepView(),
          _buildResultsStepView(),
          _buildActiveTripStepView(),
        ],
      ),
      bottomNavigationBar: _buildStickyAskBusBuddyBar(),
    );
  }

  Widget _buildStepTab(int index, String label) {
    final colors = AppTheme.colors(context);
    final isActive = _activeStepIndex == index;
    return Expanded(
      child: Semantics(
        button: true,
        selected: isActive,
        label: label,
        child: GestureDetector(
          onTap: () => setState(() => _activeStepIndex = index),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget,
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? colors.actionPrimary : colors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isActive ? colors.onActionPrimary : colors.textPrimary,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Step 1: Booking Form (Image 1) ─────────────────────────────────────────
  Widget _buildBookingStepView() {
    final colors = AppTheme.colors(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Where would you like to go?',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Select your starting point and destination to find buses and book a ticket.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // FROM Card
          InkWell(
            onTap: _openOriginPicker,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceSubtle,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Icon(
                      Icons.location_on,
                      color: colors.textPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FROM',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isCurrentLocation
                              ? 'Current Location'
                              : _origin.name,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (_isCurrentLocation)
                          Text(
                            _origin.name,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.my_location,
                    color: colors.textSecondary,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // TO Card
          InkWell(
            onTap: _openDestinationPicker,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceSubtle,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Icon(
                      Icons.location_on_outlined,
                      color: colors.textPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TO',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _destination.name,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: colors.textSecondary,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Saved places — one tap sets the destination. Star any stop in the
          // pickers above to add it here; unstar to remove it.
          ListenableBuilder(
            listenable: AppSettingsController.instance,
            builder: (context, _) {
              final saved = _savedPlaceStops();
              if (saved.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SAVED PLACES',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SavedPlaceChips(
                    stops: saved,
                    selectedStopId: _destination.id,
                    onSelect: (stop) {
                      setState(() {
                        _destination = stop;
                      });
                      AnnouncementCoordinator.instance.announce(
                        'Destination set to ${stop.name}.',
                        priority: AnnouncementPriority.normal,
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                ],
              );
            },
          ),

          // DATE Card
          InkWell(
            onTap: _openDatePicker,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceSubtle,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Icon(
                      Icons.calendar_today_outlined,
                      color: colors.textPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DATE',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedDateText,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: colors.textSecondary,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Find Buses Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () {
                AdaptiveUiService.instance.recordRouteSearch(
                  originId: _origin.id,
                  destinationId: _destination.id,
                  originName: _origin.name,
                  destinationName: _destination.name,
                );
                setState(() => _activeStepIndex = 1);
              },
              icon: Icon(Icons.search, color: colors.onActionPrimary, size: 22),
              label: Text(
                'Find Buses',
                style: TextStyle(
                  color: colors.onActionPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.actionPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                elevation: 4,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Recent Trips shortcut card (ticket history lives in My Tickets).
          // Saved places moved to one-tap chips above, next to the TO card.
          InkWell(
            onTap: () {
              setState(() => _activeStepIndex = 1);
            },
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surfaceSubtle,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.access_time_filled,
                      color: colors.textPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Recent Trips',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'View history',
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Available Buses Results (Image 2) ──────────────────────────────
  Widget _buildResultsStepView() {
    final colors = AppTheme.colors(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Route Summary Card
          Container(
            padding: const EdgeInsets.all(18),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.radio_button_checked,
                                color: colors.actionPrimary,
                                size: 16,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _origin.name,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 7),
                            child: Container(
                              width: 2,
                              height: 16,
                              color: colors.border,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: colors.textPrimary,
                                size: 16,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _destination.name,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => setState(() => _activeStepIndex = 0),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.surfaceSubtle,
                        foregroundColor: colors.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: const Text(
                        'Change',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(color: colors.border),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: colors.textMuted,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedDateText,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Builder(
            builder: (context) {
              final shortOrigin = _origin.name
                  .trim()
                  .split(' ')
                  .firstWhere((s) => s.isNotEmpty, orElse: () => _origin.name);
              final shortDest = _destination.name
                  .trim()
                  .split(' ')
                  .firstWhere(
                    (s) => s.isNotEmpty,
                    orElse: () => _destination.name,
                  );
              final summaryRouteName = '$shortOrigin → $shortDest';
              final dynamicQuote = _calculateCurrentFareQuote();

              return Column(
                children: [
                  // Bus Card 1 (Arriving Soon — success-tinted emphasis, Bus 18B)
                  _buildAvailableBusCard(
                    busId: '18B',
                    badgeText: 'Arriving Soon',
                    routeName: summaryRouteName,
                    fareText: dynamicQuote.formattedAmount,
                    statusText: '4 minutes away',
                    serviceNote: 'Frequent service',
                    buttonLabel: 'Select This Bus >',
                    isHighlighted: true,
                    onSelect: () => _openCheckoutDialog(
                      busId: '18B',
                      routeName: summaryRouteName,
                      fareQuote: dynamicQuote,
                      routeId: _resolveRouteId(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bus Card 2 (Bus 12A)
                  _buildAvailableBusCard(
                    busId: '12A',
                    badgeText: 'In 12 min',
                    routeName: summaryRouteName,
                    fareText: dynamicQuote.formattedAmount,
                    statusText: '12 minutes away',
                    serviceNote: 'Frequent service',
                    buttonLabel: 'Select This Bus',
                    isHighlighted: false,
                    onSelect: () => _openCheckoutDialog(
                      busId: '12A',
                      routeName: summaryRouteName,
                      fareQuote: dynamicQuote,
                      routeId: _resolveRouteId(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bus Card 3 (Bus 20C)
                  _buildAvailableBusCard(
                    busId: '20C',
                    badgeText: 'In 18 min',
                    routeName: summaryRouteName,
                    fareText: dynamicQuote.formattedAmount,
                    statusText: '18 minutes away',
                    serviceNote: 'Limited stops',
                    buttonLabel: 'Select This Bus',
                    isHighlighted: false,
                    onSelect: () => _openCheckoutDialog(
                      busId: '20C',
                      routeName: summaryRouteName,
                      fareQuote: dynamicQuote,
                      routeId: _resolveRouteId(),
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

  Widget _buildAvailableBusCard({
    required String busId,
    required String badgeText,
    required String routeName,
    required String fareText,
    required String statusText,
    required String serviceNote,
    required String buttonLabel,
    required bool isHighlighted,
    required VoidCallback onSelect,
  }) {
    final colors = AppTheme.colors(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // "Selected/arriving" emphasis is a subtle success tint with a success
        // border — never an inverted light card inside the dark page.
        color: isHighlighted ? colors.statusSuccessBg : colors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: isHighlighted ? colors.statusSuccess : colors.border,
        ),
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
                    Icons.directions_bus,
                    color: colors.textPrimary,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    busId,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
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
                  color: isHighlighted
                      ? colors.statusSuccessBg
                      : colors.statusInfoBg,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: isHighlighted
                        ? colors.statusSuccess
                        : colors.actionPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  routeName,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                fareText,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            statusText,
            style: TextStyle(
              color: isHighlighted
                  ? colors.statusSuccess
                  : colors.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          Text(
            serviceNote,
            style: TextStyle(color: colors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onSelect,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.actionPrimary,
                foregroundColor: colors.onActionPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                elevation: 0,
              ),
              child: Text(
                buttonLabel,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3: Active Trip Tracker (Image 3) ──────────────────────────────────
  Widget _buildActiveTripStepView() {
    final colors = AppTheme.colors(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Destination Banner (arrival state once the bus terminates)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: colors.statusSuccessBg,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: colors.statusSuccess),
            ),
            child: Row(
              children: [
                Icon(
                  _hasArrived ? Icons.check_circle : Icons.location_on,
                  color: colors.statusSuccess,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _hasArrived
                            ? 'Reached the destination'
                            : 'You are going to',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _destination.name,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (_hasArrived)
                        Text(
                          'You have reached. Tap End Trip below — your ticket will expire.',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: colors.textSecondary,
                  size: 26,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Active Bus Tracker Card
          StreamBuilder<BusLocation>(
            stream: _repository.streamBusLocation(
              _selectedBusId,
              _resolveRouteId(),
              originStopId: _origin.id,
              destinationStopId: _destination.id,
            ),
            builder: (context, snapshot) {
              final live = snapshot.data;
              final streamDone =
                  snapshot.connectionState == ConnectionState.done;
              final arrivedNow =
                  streamDone ||
                  (live != null && live.progressPercentage >= 1.0);
              if (arrivedNow && !_hasArrived) {
                // Deferred past build: mutating state during build trips the
                // framework's build-phase assertion.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || _hasArrived) return;
                  setState(() => _hasArrived = true);
                  AnnouncementCoordinator.instance.announce(
                    'You have reached ${_destination.name}. Tap End Trip to expire your ticket.',
                    priority: AnnouncementPriority.high,
                    routeId: _resolveRouteId(),
                  );
                });
              }
              if (live != null &&
                  live.nextStopName.isNotEmpty &&
                  live.nextStopName != _lastAnnouncedStop) {
                final nextStop = live.nextStopName;
                final eta = live.etaMinutes;
                _lastAnnouncedStop = nextStop;
                _hasAnnouncedCurrentStopArrival = false;
                if (_isAnnouncementsOn) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted || !_isAnnouncementsOn || _hasArrived) return;
                    final msg = eta <= 1
                        ? 'Arriving at $nextStop now.'
                        : 'Next stop: $nextStop. Estimated arrival in $eta minutes.';
                    AnnouncementCoordinator.instance.announce(
                      msg,
                      routeId: _resolveRouteId(),
                      priority: AnnouncementPriority.high,
                    );
                  });
                }
              } else if (live != null &&
                  live.nextStopName.isNotEmpty &&
                  live.etaMinutes <= 1 &&
                  !_hasAnnouncedCurrentStopArrival &&
                  !_hasArrived) {
                _hasAnnouncedCurrentStopArrival = true;
                if (_isAnnouncementsOn) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted || !_isAnnouncementsOn || _hasArrived) return;
                    AnnouncementCoordinator.instance.announce(
                      'Arriving at ${live.nextStopName} now.',
                      routeId: _resolveRouteId(),
                      priority: AnnouncementPriority.high,
                    );
                  });
                }
              }

              final remainingStops = _calculateRemainingStops(live);
              final etaMinutes = live?.etaMinutes ?? 6;
              final nextStop = (live != null && live.nextStopName.isNotEmpty)
                  ? live.nextStopName
                  : _upcomingStopName();
              final nextStopEta = live != null
                  ? '~ ${(live.etaMinutes / (remainingStops > 0 ? remainingStops : 1)).ceil().clamp(1, 10)} min'
                  : '~ 2 min';

              return Container(
                padding: const EdgeInsets.all(20),
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
                              Icons.directions_bus,
                              color: colors.textPrimary,
                              size: 28,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Bus $_selectedBusId',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
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
                            color: colors.statusSuccessBg,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd,
                            ),
                          ),
                          child: Text(
                            'On Track',
                            style: TextStyle(
                              color: colors.statusSuccess,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_origin.name.replaceAll(' Main Gate', '')} → ${_destination.name.replaceAll(' Railway Station', '')}',
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Metrics Row (Stops Remaining | Estimated Arrival)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '$remainingStops',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Stops Remaining',
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 40, color: colors.border),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '$etaMinutes min',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Estimated Arrival',
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Visual Step Progress Timeline Bar
                    _buildProgressTimeline(live),
                    const SizedBox(height: 20),

                    // Next Stop Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.statusInfoBg,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.directions_bus,
                            color: colors.actionPrimary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Next Stop ',
                            style: TextStyle(
                              color: colors.actionPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              nextStop,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            nextStopEta,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Interactive Real Map of the passenger's own route segment
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      child: LiveLocationMapWidget(
                        stops: _activeRouteStops,
                        currentLocation: live,
                        originStopId: _origin.id,
                        destinationStopId: _destination.id,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // Journey Assistant Banner
          InkWell(
            onTap: () {
              setState(() {
                _isAnnouncementsOn = !_isAnnouncementsOn;
                AnnouncementCoordinator.instance.isSpeechEnabled = _isAnnouncementsOn;
              });
              AnnouncementCoordinator.instance.announce(
                _isAnnouncementsOn
                    ? 'Journey announcements turned ON'
                    : 'Journey announcements muted',
                priority: AnnouncementPriority.high,
                routeId: _resolveRouteId(),
              );
            },
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.actionPrimary,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.volume_up,
                    color: colors.onActionPrimary,
                    size: 26,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Journey Assistant',
                          style: TextStyle(
                            color: colors.onActionPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Announcements are ${_isAnnouncementsOn ? 'ON' : 'OFF'}',
                          style: TextStyle(
                            color: colors.onActionPrimary.withValues(
                              alpha: 0.8,
                            ),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: colors.onActionPrimary,
                    size: 26,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Quick Action Grid (View Live Map | Repeat Last Instruction | Emergency Help)
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.map_outlined,
                  label: 'View Live Map',
                  bgColor: colors.surfaceSubtle,
                  textColor: colors.textPrimary,
                  onTap: () {
                    final ticket =
                        widget.ticketController.activeTicket ??
                        Ticket(
                          id: 'BB-20250906-184256',
                          routeId: 'vit-to-katpadi',
                          routeName: 'VIT → Katpadi',
                          origin: _origin,
                          destination: _destination,
                          busId: '18B',
                          passengerName: 'Pavan K',
                          passengerType: PassengerType.general,
                          fareQuote: FareEngine.calculateCorridorFare(
                            PassengerType.general,
                          ),
                          paymentMethod: PaymentMethod.upi,
                          issuedAt: DateTime.now(),
                          validUntil: DateTime.now().add(
                            const Duration(hours: 4),
                          ),
                          status: TicketStatus.active,
                          qrCodeData: Ticket.buildQrPayload(
                            ticketId: 'BB-20250906-184256',
                            originId: _origin.id,
                            destinationId: _destination.id,
                            busId: '18B',
                            farePaise: 2000,
                            validUntil: DateTime.now().add(
                              const Duration(hours: 4),
                            ),
                            isDemo: true,
                          ),
                          isDemo: true,
                        );
                    final repo = AppServiceLocator.instance.transportRepository;
                    unawaited(
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => LiveLocationScreen(
                            ticket: ticket,
                            repository: repo,
                            ticketController: widget.ticketController,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.published_with_changes,
                  label: 'Repeat Last Instruction',
                  bgColor: colors.surfaceSubtle,
                  textColor: colors.textPrimary,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Next stop ${_upcomingStopName()} in approximately 2 minutes.',
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.warning_amber_rounded,
                  label: 'Emergency Help',
                  // Emergency SOS keeps the reserved error-red role.
                  bgColor: colors.statusAlertBg,
                  textColor: colors.statusError,
                  iconColor: colors.statusError,
                  onTap: () {
                    final sosColors = AppTheme.colors(context);
                    unawaited(
                      showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: sosColors.background,
                          title: Text(
                            'Broadcast Emergency SOS?',
                            style: TextStyle(color: sosColors.textPrimary),
                          ),
                          content: Text(
                            'This will alert your trusted emergency contacts and transport help desk with live GPS location.',
                            style: TextStyle(color: sosColors.textSecondary),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: sosColors.textSecondary,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                unawaited(
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => SafetySharingPage(
                                        activeTicket: widget
                                            .ticketController
                                            .activeTicket,
                                      ),
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: sosColors.statusError,
                              ),
                              child: Text(
                                'SEND SOS NOW',
                                style: TextStyle(
                                  color: sosColors.onActionPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Trip Actions (End Trip | Cancel Ticket): always visible so the
          // rider can finish on arrival or end early / cancel at any point.
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: _hasArrived
                      ? 'End trip. Complete your journey.'
                      : 'End trip early. Your ticket will expire.',
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: ElevatedButton.icon(
                      onPressed: _tripActionInFlight
                          ? null
                          : () => _confirmEndTrip(arrived: _hasArrived),
                      icon: const Icon(Icons.flag_outlined, size: 20),
                      label: Text(
                        _hasArrived ? 'End Trip' : 'End Trip Early',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.actionPrimary,
                        foregroundColor: colors.onActionPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Cancel ticket. Your active ticket will be cancelled.',
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: OutlinedButton.icon(
                      onPressed: _tripActionInFlight
                          ? null
                          : _cancelActiveTicket,
                      icon: const Icon(Icons.cancel_outlined, size: 20),
                      label: const Text(
                        'Cancel Ticket',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        // Red is reserved exclusively for Emergency SOS — the
                        // destructive (non-SOS) cancel action stays neutral.
                        foregroundColor: colors.textPrimary,
                        side: BorderSide(color: colors.border, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTimeline([BusLocation? live]) {
    final colors = AppTheme.colors(context);
    // Timeline labels come from the passenger's real route segment: the
    // boarding stop, the next stop after boarding, a mid-journey stop, and
    // the alighting stop.
    final stops = _activeRouteStops;
    String label(int index, String fallback) {
      if (index >= 0 && index < stops.length) {
        return stops[index].name.replaceAll(' ', '\n');
      }
      return fallback;
    }

    final labels = [
      label(0, 'Origin'),
      label(stops.length > 1 ? 1 : 0, 'Next\nStop'),
      label(stops.length > 2 ? stops.length - 2 : 0, 'Via'),
      label(stops.length - 1, 'Destination'),
    ];
    final labelStyles = [
      Theme.of(context).textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: colors.textSecondary,
      ),
      Theme.of(context).textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w800,
        color: colors.textPrimary,
      ),
      Theme.of(context).textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: colors.textMuted,
      ),
      Theme.of(context).textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: colors.textMuted,
      ),
    ];

    int activeNodeIndex = 1;
    if (live != null) {
      if (live.progressPercentage >= 0.9) {
        activeNodeIndex = 3;
      } else if (live.progressPercentage >= 0.5) {
        activeNodeIndex = 2;
      } else if (live.progressPercentage >= 0.2) {
        activeNodeIndex = 1;
      } else {
        activeNodeIndex = 0;
      }
    }

    return Column(
      children: [
        Row(
          children: [
            _buildTimelineNode(
              isCompleted: activeNodeIndex > 0,
              isActive: activeNodeIndex == 0,
            ),
            Expanded(
              child: Container(
                height: 4,
                color: activeNodeIndex > 0
                    ? colors.statusSuccess
                    : colors.border,
              ),
            ),
            _buildTimelineNode(
              isCompleted: activeNodeIndex > 1,
              isActive: activeNodeIndex == 1,
            ),
            Expanded(
              child: Container(
                height: 4,
                color: activeNodeIndex > 1
                    ? colors.statusSuccess
                    : colors.border,
              ),
            ),
            _buildTimelineNode(
              isCompleted: activeNodeIndex > 2,
              isActive: activeNodeIndex == 2,
            ),
            Expanded(
              child: Container(
                height: 4,
                color: activeNodeIndex > 2
                    ? colors.statusSuccess
                    : colors.border,
              ),
            ),
            _buildTimelineNode(
              isCompleted: activeNodeIndex >= 3,
              isActive: activeNodeIndex == 3,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (int i = 0; i < labels.length; i++)
              Expanded(
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: labelStyles[i],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimelineNode({
    required bool isCompleted,
    required bool isActive,
  }) {
    final colors = AppTheme.colors(context);
    if (isCompleted) {
      return Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: colors.statusSuccess,
          shape: BoxShape.circle,
        ),
      );
    } else if (isActive) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: colors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: colors.statusSuccess, width: 4),
        ),
      );
    } else {
      return Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: colors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: colors.border, width: 3),
        ),
      );
    }
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color textColor,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        // minHeight instead of a fixed height so the label can reflow and
        // wrap at large text scales instead of overflowing.
        constraints: const BoxConstraints(minHeight: 105),
        padding: const EdgeInsets.all(12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor ?? textColor, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Sticky Bottom Ask BusBuddy Action Bar
  Widget _buildStickyAskBusBuddyBar() {
    final colors = AppTheme.colors(context);
    final prompts = [
      'Speak your destination',
      'Select a bus or ask for schedule',
      'Need anything? Just ask.',
    ];
    final activePrompt = prompts[_activeStepIndex.clamp(0, 2)];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          height: 60,
          child: ElevatedButton(
            onPressed: _openAiAssistant,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.actionPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
              elevation: 4,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.onActionPrimary.withValues(alpha: 0.24),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mic,
                    color: colors.onActionPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ask BusBuddy',
                        style: TextStyle(
                          color: colors.onActionPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        activePrompt,
                        style: TextStyle(
                          color: colors.onActionPrimary.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scopeToken?.dispose();
    _scopeToken = null;
    super.dispose();
  }
}
