/// Home page — the task-oriented landing screen for BusBuddy.
library;

import 'package:flutter/material.dart';

import '../../core/settings/app_settings_controller.dart';
import '../../data/models/adaptive_shortcut.dart';
import '../../data/models/home_screen_item.dart';
import '../../data/models/ticket_model.dart';
import '../../data/models/transport_models.dart';
import '../../data/repositories/transport_repository.dart';
import '../adaptive_ui/adaptive_shortcuts_view.dart';
import '../adaptive_ui/adaptive_ui_service.dart';
import '../ai_assistant/gemini_live_screen.dart';
import '../journey/journey_controller.dart';
import '../safety/safety_sharing_page.dart';
import '../settings/settings_page.dart';
import '../alerts/alerts_page.dart';
import '../tickets/live_location_screen.dart';
import '../tickets/my_tickets_page.dart';
import '../tickets/ticket_booking_suite_page.dart';
import '../tickets/ticket_controller.dart';

/// The redesigned task-oriented landing screen for BusBuddy matching master UI design.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.repository,
    required this.ticketController,
    required this.onRouteSelected,
  });

  final JourneyController controller;
  final TransportRepository repository;
  final TicketController ticketController;

  /// Called when the user taps a route result in the route-search flow.
  final void Function(String routeId) onRouteSelected;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  @override
  void initState() {
    super.initState();
    widget.ticketController.addListener(_onStateChanged);
    AppSettingsController.instance.addListener(_onStateChanged);
    AdaptiveUiService.instance.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    widget.ticketController.removeListener(_onStateChanged);
    AppSettingsController.instance.removeListener(_onStateChanged);
    AdaptiveUiService.instance.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _handleAdaptiveShortcut(AdaptiveShortcut shortcut) {
    switch (shortcut.type) {
      case AdaptiveShortcutType.route:
        final originId = shortcut.actionData['originId'] as String?;
        final destinationId = shortcut.actionData['destinationId'] as String?;
        if (originId != null && destinationId != null) {
          final matches = widget.repository.allRoutes.where((r) =>
            r.orderedStopIds.contains(originId) && r.orderedStopIds.contains(destinationId)
          ).toList();
          if (matches.isNotEmpty) {
            widget.controller.selectRoute(matches.first);
            widget.onRouteSelected(matches.first.id);
            return;
          }
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TicketBookingSuitePage(
              ticketController: widget.ticketController,
              journeyController: widget.controller,
              initialStepIndex: 0,
              showTopPrototypeTabs: false,
            ),
          ),
        );
        break;

      case AdaptiveShortcutType.liveTracking:
        final busId = shortcut.actionData['busId'] as String? ?? '18B';
        final routeId = shortcut.actionData['routeId'] as String? ?? 'vit-to-katpadi';
        final allStops = widget.repository.findStops('');
        final origin = allStops.isNotEmpty
            ? allStops.first
            : const Stop(id: 'vit-main-gate', name: 'VIT Main Gate', area: 'Vellore');
        final destination = allStops.length > 1
            ? allStops.last
            : origin;
        final ticketToTrack = widget.ticketController.activeTicket ??
            Ticket(
              id: 'BB-SHORTCUT-$busId',
              busId: busId,
              routeId: routeId,
              routeName: 'VIT → Katpadi Express',
              origin: origin,
              destination: destination,
              passengerName: 'Pavan',
              passengerType: PassengerType.general,
              fareAmount: 25.0,
              paymentMethod: PaymentMethod.upi,
              issuedAt: DateTime.now(),
              validUntil: DateTime.now().add(const Duration(hours: 4)),
              status: TicketStatus.active,
              qrCodeData: 'BB-SHORTCUT-$busId',
            );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LiveLocationScreen(
              ticket: ticketToTrack,
              repository: widget.repository,
            ),
          ),
        );
        break;

      case AdaptiveShortcutType.ticketBooking:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TicketBookingSuitePage(
              ticketController: widget.ticketController,
              journeyController: widget.controller,
              initialStepIndex: 1,
              showTopPrototypeTabs: false,
            ),
          ),
        );
        break;

      case AdaptiveShortcutType.savedPlace:
        _openSavedPlacesModal();
        break;

      case AdaptiveShortcutType.corridorAlerts:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AlertsPage()),
        );
        break;

      case AdaptiveShortcutType.safety:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SafetySharingPage(
              activeTicket: widget.ticketController.activeTicket,
            ),
          ),
        );
        break;

      case AdaptiveShortcutType.feature:
        if (shortcut.actionType == 'voice_assistant') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GeminiLiveScreen(
                ticketController: widget.ticketController,
                repository: widget.repository,
              ),
            ),
          );
        } else {
          _openRouteSearch();
        }
        break;
    }
  }

  void _openRouteSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TicketBookingSuitePage(
          ticketController: widget.ticketController,
          journeyController: widget.controller,
          initialStepIndex: 0,
          showTopPrototypeTabs: false,
        ),
      ),
    );
  }

  void _openSavedPlacesModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Saved Places',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSavedPlaceTile(Icons.home, 'Home', 'Gandhi Nagar, Vellore'),
            _buildSavedPlaceTile(Icons.school, 'VIT Campus', 'VIT Main Gate'),
            _buildSavedPlaceTile(Icons.train, 'Katpadi Junction', 'Katpadi Railway Station'),
            _buildSavedPlaceTile(Icons.local_hospital, 'CMC Hospital', 'Vellore Town'),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedPlaceTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF334155),
        foregroundColor: const Color(0xFF38BDF8),
        child: Icon(icon),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8))),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
      onTap: () {
        Navigator.of(context).pop();
        _openRouteSearch();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final activeTicket = widget.ticketController.activeTicket;
    final hasActiveTicket = activeTicket != null;
    final visibleItems = AppSettingsController.instance.homeScreenItems
        .where((e) => e.isVisible)
        .toList();

    final customCards = <Widget>[];
    for (final item in visibleItems) {
      final cardWidget = _buildCustomCardForItem(item, hasActiveTicket, activeTicket);
      if (cardWidget is! SizedBox) {
        customCards.add(cardWidget);
        customCards.add(const SizedBox(height: 14));
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B101D),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  // Hidden purpose statement for screen reader context
                  Semantics(
                    label: 'BusBuddy helps plan journeys from VIT Vellore to Katpadi Railway Station',
                    child: const SizedBox.shrink(),
                  ),

                  // ── Top App Header ───────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Bus',
                                style: textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 26,
                                ),
                              ),
                              Text(
                                'Buddy',
                                style: textTheme.headlineSmall?.copyWith(
                                  color: const Color(0xFF38BDF8),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 26,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Travel Together, Go Further',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Semantics(
                            button: true,
                            label: 'Corridor Alerts',
                            child: IconButton(
                              icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 24),
                              tooltip: 'Corridor Alerts',
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const AlertsPage()),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 4),
                          Semantics(
                            button: true,
                            label: 'User Profile',
                            child: const CircleAvatar(
                              radius: 22,
                              backgroundColor: Color(0xFF1E293B),
                              child: Icon(Icons.person, color: Colors.white, size: 24),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Greeting Banner ──────────────────────────────────────
                  Row(
                    children: [
                      Text(hasActiveTicket ? '☀️ ' : '👋 ', style: const TextStyle(fontSize: 22)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasActiveTicket ? 'Good morning, Pavan!' : 'Good morning!',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasActiveTicket ? "Here's your journey today." : 'What would you like to do?',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Adaptive UI Suggested Shortcuts Carousel ────────────
                  AdaptiveShortcutsView(
                    onExecuteShortcut: _handleAdaptiveShortcut,
                  ),

                  // ── Active Ticket Hero Card (Image 2) ───────────────────
                  if (hasActiveTicket) ...[
                    Semantics(
                      container: true,
                      label: 'Active Journey: Bus 18B to Katpadi. On Track. 3 stops remaining. Estimated arrival 6 minutes.',
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7), // Light Mint Green
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
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFBBF7D0),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.directions_bus,
                                        color: Color(0xFF15803D),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'My Journey',
                                          style: TextStyle(
                                            color: Color(0xFF14532D),
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${activeTicket.busId} → ${activeTicket.destination.name}',
                                          style: const TextStyle(
                                            color: Color(0xFF15803D),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF15803D),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'On Track',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(color: Color(0xFF86EFAC), height: 1),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.location_on, color: Color(0xFF15803D), size: 20),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: const [
                                          Text(
                                            '3 stops',
                                            style: TextStyle(
                                              color: Color(0xFF14532D),
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          Text(
                                            'remaining',
                                            style: TextStyle(
                                              color: Color(0xFF15803D),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(height: 30, width: 1, color: const Color(0xFF86EFAC)),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.access_time_filled, color: Color(0xFF15803D), size: 20),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: const [
                                          Text(
                                            '6 min',
                                            style: TextStyle(
                                              color: Color(0xFF14532D),
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          Text(
                                            'estimated arrival',
                                            style: TextStyle(
                                              color: Color(0xFF15803D),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: FilledButton(
                                onPressed: () {
                                  final routes = widget.repository.allRoutes;
                                  if (routes.isNotEmpty) {
                                    widget.controller.selectRoute(routes.first);
                                  }
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => TicketBookingSuitePage(
                                        ticketController: widget.ticketController,
                                        journeyController: widget.controller,
                                        initialStepIndex: 2,
                                      ),
                                    ),
                                  );
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF15803D),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Text(
                                      'View Journey Details',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Icon(Icons.chevron_right, color: Colors.white, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // ── Customizable Task Action Stack ───────────────────────
                  if (visibleItems.isEmpty) ...[
                    _buildEmptyLayoutCard(),
                    const SizedBox(height: 24),
                  ] else ...[
                    ...customCards,
                    const SizedBox(height: 10),
                  ],

                  // ── Footer ───────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.eco_outlined, color: Color(0xFF64748B), size: 20),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'More Accessible Cities',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'for a Brighter Tomorrow',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Icon(
                        Icons.directions_bus_filled_outlined,
                        color: Color(0xFF334155),
                        size: 32,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyLayoutCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF111C33),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        children: [
          const Icon(Icons.dashboard_customize_outlined, color: Color(0xFF94A3B8), size: 40),
          const SizedBox(height: 12),
          const Text(
            'All Home Cards Hidden',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'You have hidden all feature cards on your home screen. Tap below to restore default cards.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => AppSettingsController.instance.resetHomeScreenLayout(),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.restore, color: Colors.white, size: 20),
            label: const Text('Restore Default Cards', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomCardForItem(HomeScreenItem item, bool hasActiveTicket, Ticket? activeTicket) {
    switch (item.id) {
      case HomeScreenItem.idRouteSearch:
        return _buildTaskActionCard(
          color: item.color,
          icon: item.icon,
          title: item.title,
          subtitle: item.subtitle,
          semanticLabel: '${item.title}. ${item.subtitle}.',
          onTap: _openRouteSearch,
        );

      case HomeScreenItem.idMyJourney:
        if (hasActiveTicket) {
          // The active journey is already prominently featured in the Hero Card above
          return const SizedBox.shrink();
        }
        return _buildTaskActionCard(
          color: item.color,
          icon: item.icon,
          title: item.title,
          subtitle: 'No active journey',
          semanticLabel: '${item.title}. No active journey.',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TicketBookingSuitePage(
                  ticketController: widget.ticketController,
                  journeyController: widget.controller,
                  initialStepIndex: 0,
                ),
              ),
            );
          },
        );

      case HomeScreenItem.idMyTickets:
        return _buildTaskActionCard(
          color: item.color,
          icon: item.icon,
          title: item.title,
          subtitle: item.subtitle,
          semanticLabel: '${item.title}. ${item.subtitle}.',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MyTicketsPage(
                  ticketController: widget.ticketController,
                ),
              ),
            );
          },
        );

      case HomeScreenItem.idSavedPlaces:
        return _buildTaskActionCard(
          color: item.color,
          icon: item.icon,
          title: item.title,
          subtitle: item.subtitle,
          semanticLabel: '${item.title}. ${item.subtitle}.',
          onTap: _openSavedPlacesModal,
        );

      case HomeScreenItem.idVoiceAssistant:
        return _buildTaskActionCard(
          color: item.color,
          icon: item.icon,
          title: item.title,
          subtitle: item.subtitle,
          semanticLabel: '${item.title}. ${item.subtitle}.',
          trailingIcon: Icons.graphic_eq,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GeminiLiveScreen(
                  ticketController: widget.ticketController,
                  repository: widget.repository,
                ),
              ),
            );
          },
        );

      case HomeScreenItem.idLiveTracking:
        return _buildTaskActionCard(
          color: item.color,
          icon: item.icon,
          title: item.title,
          subtitle: hasActiveTicket
              ? 'Bus ${activeTicket?.busId ?? "18B"} • Live corridor tracking'
              : item.subtitle,
          semanticLabel: '${item.title}. ${item.subtitle}.',
          onTap: () {
            final allStops = widget.repository.findStops('');
            final origin = allStops.isNotEmpty
                ? allStops.first
                : const Stop(id: 'vit-main-gate', name: 'VIT Main Gate', area: 'Vellore');
            final destination = allStops.length > 1
                ? allStops.last
                : origin;
            final ticketToTrack = activeTicket ??
                Ticket(
                  id: 'BB-PREVIEW-CORRIDOR',
                  busId: '18B',
                  routeId: 'vit-to-katpadi',
                  routeName: 'VIT → Katpadi Express',
                  origin: origin,
                  destination: destination,
                  passengerName: 'Pavan',
                  passengerType: PassengerType.general,
                  fareAmount: 25.0,
                  paymentMethod: PaymentMethod.upi,
                  issuedAt: DateTime.now(),
                  validUntil: DateTime.now().add(const Duration(hours: 4)),
                  status: TicketStatus.active,
                  qrCodeData: 'BB-PREVIEW-CORRIDOR',
                );
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LiveLocationScreen(
                  ticket: ticketToTrack,
                  repository: widget.repository,
                ),
              ),
            );
          },
        );

      case HomeScreenItem.idAlerts:
        return _buildTaskActionCard(
          color: item.color,
          icon: item.icon,
          title: item.title,
          subtitle: item.subtitle,
          semanticLabel: '${item.title}. ${item.subtitle}.',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AlertsPage(),
              ),
            );
          },
        );

      case HomeScreenItem.idSafety:
        return _buildTaskActionCard(
          color: item.color,
          icon: item.icon,
          title: item.title,
          subtitle: item.subtitle,
          semanticLabel: '${item.title}. ${item.subtitle}.',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SafetySharingPage(
                  activeTicket: activeTicket,
                ),
              ),
            );
          },
        );

      case HomeScreenItem.idSettings:
        return _buildTaskActionCard(
          color: item.color,
          icon: item.icon,
          title: item.title,
          subtitle: item.subtitle,
          semanticLabel: '${item.title}. ${item.subtitle}.',
          borderColor: const Color(0xFF334155),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SettingsPage(
                  repository: widget.repository,
                  ticketController: widget.ticketController,
                ),
              ),
            );
          },
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTaskActionCard({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    required String semanticLabel,
    required VoidCallback onTap,
    IconData? trailingIcon,
    Color? borderColor,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: borderColor != null ? Border.all(color: borderColor) : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  trailingIcon ?? Icons.chevron_right,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
