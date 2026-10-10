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
import '../journey/live_location_screen.dart';
import '../saved/saved_place_chips.dart';
import 'booking_checkout_dialog.dart';
import 'ticket_controller.dart';

/// Ticket booking flow; active tickets open the dedicated live location screen.
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
    this.showBackButton = true,
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
  final bool showBackButton;

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
  String _selectedBusId = '18B';
  bool _isCurrentLocation = true;
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
    _activeStepIndex = widget.initialStepIndex.clamp(0, 1);

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
    Ticket? ticketToTrack;
    final checkout = showModalBottomSheet<void>(
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
            ticketToTrack = ticket;
            setState(() {
              _selectedBusId = ticket.busId;
              _activeStepIndex = 1;
            });
          },
        );
      },
    );
    unawaited(
      checkout.whenComplete(() {
        final ticket = ticketToTrack;
        if (!mounted || ticket == null) return;
        unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => LiveLocationScreen(
                ticket: ticket,
                repository: _repository,
                ticketController: widget.ticketController,
              ),
            ),
          ),
        );
      }),
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

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(widget.showTopPrototypeTabs ? 124 : 56),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showTopPrototypeTabs)
                Container(
                  color: colors.background,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      _buildStepTab(0, '1. Booking'),
                      _buildStepTab(1, '2. Results'),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    if (widget.showBackButton) ...[
                      IconButton(
                        constraints: const BoxConstraints(
                          minWidth: AppSpacing.minTouchTarget,
                          minHeight: AppSpacing.minTouchTarget,
                        ),
                        icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                        onPressed: () =>
                            unawaited(Navigator.of(context).maybePop()),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    const BusBuddyLogo(fontSize: 20),
                    const Spacer(),
                    Text(
                      _activeStepIndex == 0
                          ? 'Book a Ticket'
                          : 'Available Buses',
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
        children: [_buildBookingStepView(), _buildResultsStepView()],
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

  // Sticky Bottom Ask BusBuddy Action Bar
  Widget _buildStickyAskBusBuddyBar() {
    final colors = AppTheme.colors(context);
    final prompts = [
      'Speak your destination',
      'Select a bus or ask for schedule',
      'Need anything? Just ask.',
    ];
    final activePrompt = prompts[_activeStepIndex.clamp(0, 1)];

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
