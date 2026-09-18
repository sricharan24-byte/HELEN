import 'package:flutter/material.dart';

import '../../data/datasources/local_transport_data_source.dart';
import '../../data/models/ticket_model.dart';
import '../../data/models/transport_models.dart';
import '../../data/repositories/transport_repository.dart';
import '../adaptive_ui/adaptive_ui_service.dart';
import '../ai_assistant/gemini_live_screen.dart';
import '../journey/journey_controller.dart';
import '../journey/live_location_map_widget.dart';
import '../saved/saved_page.dart';
import '../tickets/booking_checkout_dialog.dart';
import '../tickets/live_location_screen.dart';
import '../tickets/ticket_controller.dart';

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
  });

  final TicketController ticketController;
  final JourneyController? journeyController;
  final int initialStepIndex;
  final bool showTopPrototypeTabs;
  final Stop? initialOrigin;
  final Stop? initialDestination;

  @override
  State<TicketBookingSuitePage> createState() => _TicketBookingSuitePageState();
}

class _TicketBookingSuitePageState extends State<TicketBookingSuitePage> {
  late int _activeStepIndex;

  late List<Stop> _allStops;
  late Stop _origin;
  late Stop _destination;
  String _selectedDateText = 'Today, 6 Sep 2025';
  bool _isAnnouncementsOn = true;
  String _selectedBusId = '18B';
  bool _isCurrentLocation = true;

  @override
  void initState() {
    super.initState();
    _activeStepIndex = widget.initialStepIndex;

    final dataSource = LocalTransportDataSource();
    _allStops = dataSource.allStops;

    const fallbackOrigin = Stop(id: 'vit-main-gate', name: 'VIT Main Gate', area: 'Vellore');
    const fallbackDestination = Stop(id: 'katpadi-railway-station', name: 'Katpadi Railway Station', area: 'Katpadi');

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
  }

  void _openOriginPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B101D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Origin Stop',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.my_location, color: Color(0xFF38BDF8)),
                title: const Text(
                  'Current Location (VIT Main Gate)',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  setState(() {
                    _isCurrentLocation = true;
                    _origin = _allStops.firstWhere(
                      (s) => s.name.contains('VIT'),
                      orElse: () => _allStops.isNotEmpty
                          ? _allStops.first
                          : const Stop(id: 'vit-main-gate', name: 'VIT Main Gate', area: 'Vellore'),
                    );
                  });
                  Navigator.of(context).pop();
                },
              ),
              const Divider(color: Color(0xFF1E293B)),
              Expanded(
                child: ListView(
                  children: _allStops.map((stop) {
                    final isSelected = !_isCurrentLocation && stop.id == _origin.id;
                    return ListTile(
                      leading: Icon(
                        Icons.location_on,
                        color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
                      ),
                      title: Text(
                        stop.name,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF38BDF8) : Colors.white,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        stop.area,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                      onTap: () {
                        setState(() {
                          _isCurrentLocation = false;
                          _origin = stop;
                        });
                        Navigator.of(context).pop();
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openDestinationPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B101D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Destination Stop',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: _allStops.map((stop) {
                    final isSelected = stop.id == _destination.id;
                    return ListTile(
                      leading: Icon(
                        Icons.location_on,
                        color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
                      ),
                      title: Text(
                        stop.name,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF38BDF8) : Colors.white,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        stop.area,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                      onTap: () {
                        setState(() {
                          _destination = stop;
                        });
                        Navigator.of(context).pop();
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2025, 9, 6),
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime(2026, 12, 31),
    );
    if (picked != null) {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      setState(() {
        _selectedDateText = 'Selected, ${picked.day} ${months[picked.month - 1]} ${picked.year}';
      });
    }
  }

  void _openAiAssistant() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GeminiLiveScreen(
          ticketController: widget.ticketController,
          repository: LocalTransportRepository(dataSource: LocalTransportDataSource()),
          journeyController: widget.journeyController,
        ),
      ),
    );
  }

  void _openCheckoutDialog({
    required String busId,
    required String routeName,
    required double baseFare,
    String? routeId,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BookingCheckoutDialog(
          busId: busId,
          routeName: routeName,
          origin: _origin,
          destination: _destination,
          baseFare: baseFare,
          routeId: routeId ?? _resolveRouteId(),
          onTicketBooked: (ticket) {
            AdaptiveUiService.instance.recordTicketBooking(
              originName: ticket.origin.name,
              destinationName: ticket.destination.name,
              busId: ticket.busId,
              routeId: ticket.routeId,
            );
            widget.ticketController.addTicket(ticket);
            setState(() {
              _selectedBusId = ticket.busId;
              _activeStepIndex = 2;
            });
          },
        );
      },
    );
  }

  String _resolveRouteId() {
    final routes = LocalTransportDataSource().allRoutes;
    for (final route in routes) {
      final o = route.orderedStopIds.indexOf(_origin.id);
      final d = route.orderedStopIds.indexOf(_destination.id);
      if (o != -1 && d != -1 && o < d) {
        return route.id;
      }
    }
    return 'vit-to-katpadi';
  }

  /// Stops on the passenger's own journey segment of the active route
  /// (boarding stop through alighting stop), in travel order.
  List<Stop> get _activeRouteStops {
    final dataSource = LocalTransportDataSource();
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

  int _calculateRemainingStops() {
    final routes = LocalTransportDataSource().allRoutes;
    for (final route in routes) {
      final o = route.orderedStopIds.indexOf(_origin.id);
      final d = route.orderedStopIds.indexOf(_destination.id);
      if (o != -1 && d != -1 && o < d) {
        final totalStops = d - o;
        return (totalStops > 3 ? 3 : totalStops).clamp(1, 10);
      }
    }
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B101D),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(widget.showTopPrototypeTabs ? 116 : 56),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Prototype Header Tabs (1. Booking | 2. Results | 3. Active Trip)
              if (widget.showTopPrototypeTabs)
                Container(
                  color: const Color(0xFF080D18),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        Navigator.of(context).maybePop();
                      },
                    ),
                    const SizedBox(width: 8),
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'Bus',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          TextSpan(
                            text: 'Buddy',
                            style: TextStyle(
                              color: Color(0xFF007AFF),
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _activeStepIndex == 0
                          ? 'Book a Ticket'
                          : _activeStepIndex == 1
                              ? 'Available Buses'
                              : 'My Journey',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
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
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF007AFF) : const Color(0xFF111C33),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Where would you like to go?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Select your starting point and destination to find buses and book a ticket.',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // FROM Card
          InkWell(
            onTap: _openOriginPicker,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111C33),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.location_on, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FROM',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isCurrentLocation ? 'Current Location' : _origin.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (_isCurrentLocation)
                          Text(
                            _origin.name,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.my_location, color: Colors.white70, size: 22),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // TO Card
          InkWell(
            onTap: _openDestinationPicker,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111C33),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.location_on_outlined, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TO',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _destination.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white70, size: 24),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // DATE Card
          InkWell(
            onTap: _openDatePicker,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111C33),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.calendar_today_outlined, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DATE',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedDateText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white70, size: 24),
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
              icon: const Icon(Icons.search, color: Colors.white, size: 22),
              label: const Text(
                'Find Buses',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Shortcut Cards Row (Saved Places | Recent Trips)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SavedPage(ticketController: widget.ticketController),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111C33),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E293B),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.star, color: Colors.white, size: 20),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Saved Places',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Home, College etc.',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() => _activeStepIndex = 1);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111C33),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E293B),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.access_time_filled, color: Colors.white, size: 20),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Recent Trips',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'View history',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      ],
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

  // ── Step 2: Available Buses Results (Image 2) ──────────────────────────────
  Widget _buildResultsStepView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Route Summary White Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
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
                              const Icon(Icons.radio_button_checked, color: Color(0xFF007AFF), size: 16),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _origin.name,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
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
                              color: const Color(0xFFCBD5E1),
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.location_on, color: Color(0xFF0F172A), size: 16),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _destination.name,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
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
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('Change', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Color(0xFF64748B), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      _selectedDateText,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
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
              final shortOrigin = _origin.name.trim().split(' ').firstWhere((s) => s.isNotEmpty, orElse: () => _origin.name);
              final shortDest = _destination.name.trim().split(' ').firstWhere((s) => s.isNotEmpty, orElse: () => _destination.name);
              final summaryRouteName = '$shortOrigin → $shortDest';

              return Column(
                children: [
                  // Bus Card 1 (Highlighted Mint Card - Bus 18B)
                  _buildAvailableBusCard(
                    busId: '18B',
                    badgeText: 'Arriving Soon',
                    badgeColor: const Color(0xFF16A34A),
                    routeName: summaryRouteName,
                    fareText: '₹25',
                    statusText: '4 minutes away',
                    serviceNote: 'Frequent service',
                    buttonLabel: 'Select This Bus >',
                    isHighlighted: true,
                    onSelect: () => _openCheckoutDialog(
                      busId: '18B',
                      routeName: summaryRouteName,
                      baseFare: 25.0,
                      routeId: _resolveRouteId(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bus Card 2 (Bus 12A)
                  _buildAvailableBusCard(
                    busId: '12A',
                    badgeText: 'In 12 min',
                    badgeColor: const Color(0xFF007AFF),
                    routeName: summaryRouteName,
                    fareText: '₹30',
                    statusText: '12 minutes away',
                    serviceNote: 'Frequent service',
                    buttonLabel: 'Select This Bus',
                    isHighlighted: false,
                    onSelect: () => _openCheckoutDialog(
                      busId: '12A',
                      routeName: summaryRouteName,
                      baseFare: 30.0,
                      routeId: _resolveRouteId(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bus Card 3 (Bus 20C)
                  _buildAvailableBusCard(
                    busId: '20C',
                    badgeText: 'In 18 min',
                    badgeColor: const Color(0xFF007AFF),
                    routeName: summaryRouteName,
                    fareText: '₹25',
                    statusText: '18 minutes away',
                    serviceNote: 'Limited stops',
                    buttonLabel: 'Select This Bus',
                    isHighlighted: false,
                    onSelect: () => _openCheckoutDialog(
                      busId: '20C',
                      routeName: summaryRouteName,
                      baseFare: 25.0,
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
    required Color badgeColor,
    required String routeName,
    required String fareText,
    required String statusText,
    required String serviceNote,
    required String buttonLabel,
    required bool isHighlighted,
    required VoidCallback onSelect,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color(0xFFE6F4EA) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.directions_bus, color: Color(0xFF0F172A), size: 28),
                  const SizedBox(width: 10),
                  Text(
                    busId,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isHighlighted ? badgeColor : const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: isHighlighted ? Colors.white : const Color(0xFF0369A1),
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
              Text(
                routeName,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                fareText,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
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
              color: isHighlighted ? const Color(0xFF16A34A) : const Color(0xFF334155),
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          Text(
            serviceNote,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onSelect,
              style: ElevatedButton.styleFrom(
                backgroundColor: isHighlighted ? const Color(0xFF16A34A) : const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Green Destination Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'You are going to',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _destination.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white, size: 26),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Active Bus Tracker Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.directions_bus, color: Color(0xFF0F172A), size: 28),
                        const SizedBox(width: 10),
                        Text(
                          'Bus $_selectedBusId',
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'On Track',
                        style: TextStyle(
                          color: Color(0xFF16A34A),
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
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),

                // Metrics Row (3 Stops Remaining | 6 min Estimated Arrival)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '${_calculateRemainingStops()}',
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Stops Remaining',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 40, color: const Color(0xFFE2E8F0)),
                    Expanded(
                      child: Column(
                        children: const [
                          Text(
                            '6 min',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Estimated Arrival',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Visual Step Progress Timeline Bar
                _buildProgressTimeline(),
                const SizedBox(height: 20),

                // Next Stop Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F2FE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.directions_bus, color: Color(0xFF007AFF), size: 20),
                      const SizedBox(width: 10),
                      const Text(
                        'Next Stop ',
                        style: TextStyle(color: Color(0xFF007AFF), fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      Expanded(
                        child: Text(
                          _upcomingStopName(),
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const Text(
                        '~ 2 min',
                        style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Interactive Real Map of the passenger's own route segment
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: LiveLocationMapWidget(
                    stops: _activeRouteStops,
                    originStopId: _origin.id,
                    destinationStopId: _destination.id,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Journey Assistant Banner
          InkWell(
            onTap: () {
              setState(() {
                _isAnnouncementsOn = !_isAnnouncementsOn;
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.volume_up, color: Colors.white, size: 26),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Journey Assistant',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Announcements are ${_isAnnouncementsOn ? 'ON' : 'OFF'}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white, size: 26),
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
                  bgColor: const Color(0xFF111C33),
                  textColor: Colors.white,
                  onTap: () {
                    final ticket = widget.ticketController.activeTicket ??
                        Ticket(
                          id: 'BB184256',
                          routeId: 'vit-to-katpadi',
                          routeName: 'VIT → Katpadi',
                          origin: _origin,
                          destination: _destination,
                          busId: '18B',
                          passengerName: 'Pavan K',
                          passengerType: PassengerType.general,
                          fareAmount: 25.0,
                          paymentMethod: PaymentMethod.upi,
                          issuedAt: DateTime.now(),
                          validUntil: DateTime.now().add(const Duration(hours: 4)),
                          status: TicketStatus.active,
                          qrCodeData: 'BUSBUDDY-PASS-BB184256',
                        );
                    final repo = LocalTransportRepository(dataSource: LocalTransportDataSource());
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LiveLocationScreen(
                          ticket: ticket,
                          repository: repo,
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
                  bgColor: const Color(0xFF111C33),
                  textColor: Colors.white,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Next stop ${_upcomingStopName()} in approximately 2 minutes.')),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.warning_amber_rounded,
                  label: 'Emergency Help',
                  bgColor: const Color(0xFFFECDD3),
                  textColor: const Color(0xFF991B1B),
                  iconColor: const Color(0xFFDC2626),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF0B101D),
                        title: const Text('Broadcast Emergency SOS?', style: TextStyle(color: Colors.white)),
                        content: const Text(
                          'This will alert your trusted emergency contacts and transport help desk with live GPS location.',
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Color(0xFFDC2626),
                                  content: Text('SOS Emergency Alert Broadcasted!'),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                            child: const Text('SEND SOS NOW', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTimeline() {
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
    final labelStyles = const [
      TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
      TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
      TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
      TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
    ];

    return Column(
      children: [
        Row(
          children: [
            _buildTimelineNode(isCompleted: true, isActive: false),
            Expanded(child: Container(height: 4, color: const Color(0xFF16A34A))),
            _buildTimelineNode(isCompleted: false, isActive: true),
            Expanded(child: Container(height: 4, color: const Color(0xFFCBD5E1))),
            _buildTimelineNode(isCompleted: false, isActive: false),
            Expanded(child: Container(height: 4, color: const Color(0xFFCBD5E1))),
            _buildTimelineNode(isCompleted: false, isActive: false),
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

  Widget _buildTimelineNode({required bool isCompleted, required bool isActive}) {
    if (isCompleted) {
      return Container(
        width: 18,
        height: 18,
        decoration: const BoxDecoration(
          color: Color(0xFF16A34A),
          shape: BoxShape.circle,
        ),
      );
    } else if (isActive) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF16A34A), width: 4),
        ),
      );
    } else {
      return Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFCBD5E1), width: 3),
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 105,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
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
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 4,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ask BusBuddy',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        activePrompt,
                        style: const TextStyle(
                          color: Colors.white70,
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
}
