/// Home page — the task-oriented landing screen for BusBuddy.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/tokens/app_spacing.dart';
import '../../core/widgets/bus_buddy_logo.dart';
import '../../core/settings/app_settings_controller.dart';
import '../../data/models/adaptive_shortcut.dart';
import '../../data/models/home_screen_item.dart';
import '../../data/models/ticket_model.dart';
import '../../data/models/transport_models.dart';
import '../../data/repositories/transport_repository.dart';
import '../../domain/ticketing/entities/fare_engine.dart';
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

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.ticketController.addListener(_onStateChanged);
    AppSettingsController.instance.addListener(_onStateChanged);
    AdaptiveUiService.instance.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.ticketController.removeListener(_onStateChanged);
    AppSettingsController.instance.removeListener(_onStateChanged);
    AdaptiveUiService.instance.removeListener(_onStateChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.ticketController.refresh();
      if (mounted) setState(() {});
    }
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
          final matches = widget.repository.allRoutes
              .where(
                (r) =>
                    r.orderedStopIds.contains(originId) &&
                    r.orderedStopIds.contains(destinationId),
              )
              .toList();
          if (matches.isNotEmpty) {
            widget.controller.selectRoute(matches.first);
            widget.onRouteSelected(matches.first.id);
          }
        }
        unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TicketBookingSuitePage(
                ticketController: widget.ticketController,
                journeyController: widget.controller,
                initialStepIndex: 0,
                showTopPrototypeTabs: false,
              ),
            ),
          ).then((_) {
            if (mounted) {
              widget.ticketController.refresh();
              setState(() {});
            }
          }),
        );
        break;

      case AdaptiveShortcutType.liveTracking:
        final busId = shortcut.actionData['busId'] as String? ?? '18B';
        final routeId =
            shortcut.actionData['routeId'] as String? ?? 'vit-to-katpadi';
        final allStops = widget.repository.findStops('');
        final origin = allStops.isNotEmpty
            ? allStops.first
            : const Stop(
                id: 'vit-main-gate',
                name: 'VIT Main Gate',
                area: 'Vellore',
              );
        final destination = allStops.length > 1 ? allStops.last : origin;
        final ticketToTrack =
            widget.ticketController.activeTicket ??
            Ticket(
              id: 'BB-SHORTCUT-$busId',
              busId: busId,
              routeId: routeId,
              routeName: 'VIT → Katpadi Express',
              origin: origin,
              destination: destination,
              passengerName: 'Pavan',
              passengerType: PassengerType.general,
              fareQuote: FareEngine.calculateCorridorFare(
                PassengerType.general,
              ),
              paymentMethod: PaymentMethod.upi,
              issuedAt: DateTime.now(),
              validUntil: DateTime.now().add(const Duration(hours: 4)),
              status: TicketStatus.active,
              qrCodeData: Ticket.buildQrPayload(
                ticketId: 'BB-SHORTCUT-$busId',
                originId: origin.id,
                destinationId: destination.id,
                busId: busId,
                farePaise: 2000,
                validUntil: DateTime.now().add(const Duration(hours: 4)),
                isDemo: true,
              ),
              isDemo: true,
            );
        unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => LiveLocationScreen(
                ticket: ticketToTrack,
                repository: widget.repository,
                ticketController: widget.ticketController,
              ),
            ),
          ).then((_) {
            if (mounted) {
              widget.ticketController.refresh();
              setState(() {});
            }
          }),
        );
        break;

      case AdaptiveShortcutType.ticketBooking:
        unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TicketBookingSuitePage(
                ticketController: widget.ticketController,
                journeyController: widget.controller,
                initialStepIndex: 1,
                showTopPrototypeTabs: false,
              ),
            ),
          ).then((_) {
            if (mounted) {
              widget.ticketController.refresh();
              setState(() {});
            }
          }),
        );
        break;

      case AdaptiveShortcutType.savedPlace:
        // Saved places no longer own a page: they are one-tap chips inside
        // the booking pickers, so the shortcut opens booking step 1.
        _openRouteSearch();
        break;

      case AdaptiveShortcutType.corridorAlerts:
        unawaited(
          Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const AlertsPage())),
        );
        break;

      case AdaptiveShortcutType.safety:
        unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SafetySharingPage(
                activeTicket: widget.ticketController.activeTicket,
              ),
            ),
          ),
        );
        break;

      case AdaptiveShortcutType.feature:
        if (shortcut.actionType == 'voice_assistant') {
          unawaited(
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GeminiLiveScreen(
                  ticketController: widget.ticketController,
                  repository: widget.repository,
                ),
              ),
            ),
          );
        } else {
          _openRouteSearch();
        }
        break;
    }
  }

  DateTime? _lastNavigationAt;

  /// Debounce: ignore a second navigation start within 500 ms of the previous
  /// accepted one (rapid double-tap on search or a home card).
  bool _shouldNavigate() {
    final now = DateTime.now();
    final last = _lastNavigationAt;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 500)) {
      return false;
    }
    _lastNavigationAt = now;
    return true;
  }

  void _openRouteSearch() {
    if (!_shouldNavigate()) return;
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TicketBookingSuitePage(
            ticketController: widget.ticketController,
            journeyController: widget.controller,
            initialStepIndex: 0,
            showTopPrototypeTabs: false,
          ),
        ),
      ).then((_) {
        if (mounted) {
          widget.ticketController.refresh();
          setState(() {});
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    widget.ticketController.checkExpiry();
    final colors = AppTheme.colors(context);
    final activeTicket = widget.ticketController.activeTicket;
    final hasActiveTicket = activeTicket != null;
    final visibleItems = AppSettingsController.instance.homeScreenItems
        .where((e) => e.isVisible && e.id != HomeScreenItem.idAlerts)
        .toList();

    final customCards = <Widget>[];
    for (final item in visibleItems) {
      final cardWidget = _buildCustomCardForItem(
        item,
        hasActiveTicket,
        activeTicket,
      );
      if (cardWidget is! SizedBox) {
        customCards.add(cardWidget);
        customCards.add(const SizedBox(height: 14));
      }
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                children: [
                  // Hidden purpose statement for screen reader context
                  Semantics(
                    label:
                        'BusBuddy helps plan journeys from VIT Vellore to Katpadi Railway Station',
                    child: const SizedBox.shrink(),
                  ),

                  // ── Top App Header ───────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              headingLevel: 1,
                              child: const BusBuddyLogo(
                                fontSize: 26,
                                crossAxisAlignment: CrossAxisAlignment.start,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Travel Together, Go Further',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'User Profile',
                        excludeSemantics: true,
                        child: Tooltip(
                          message: 'User Profile',
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: colors.surface,
                            child: Icon(
                              Icons.person,
                              color: colors.textPrimary,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Greeting Banner ──────────────────────────────────────
                  Row(
                    children: [
                      Icon(
                        hasActiveTicket
                            ? Icons.wb_sunny_outlined
                            : Icons.waving_hand_outlined,
                        color: hasActiveTicket
                            ? colors.statusWarning
                            : colors.actionSecondary,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasActiveTicket
                                  ? 'Good morning, Pavan!'
                                  : 'Good morning!',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              hasActiveTicket
                                  ? "Here's your journey today."
                                  : 'What would you like to do?',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Adaptive UI Suggested Shortcuts Carousel ────────────
                  AdaptiveShortcutsView(
                    onExecuteShortcut: _handleAdaptiveShortcut,
                  ),

                  // ── Active Ticket Hero Card ─────────────────────────────
                  if (hasActiveTicket) ...[
                    Semantics(
                      container: true,
                      label:
                          'Active Journey: Bus 18B to Katpadi. On Track. 3 stops remaining. Estimated arrival 6 minutes.',
                      child: Builder(
                        builder: (context) {
                          final heroBg = colors.isHighContrast
                              ? colors.surface
                              : colors.statusSuccessBg;
                          final heroBorder = colors.isHighContrast
                              ? colors.border
                              : colors.statusSuccess.withValues(alpha: 0.55);
                          final heroTitle = colors.textPrimary;
                          final heroBody = colors.isHighContrast
                              ? colors.textSecondary
                              : colors.statusSuccess;
                          final chipBg = colors.statusSuccess;
                          final chipFg = colors.onActionPrimary;
                          final iconBg = colors.isHighContrast
                              ? colors.surfaceSubtle
                              : colors.statusSuccessBg;
                          final divider = colors.isHighContrast
                              ? colors.border
                              : colors.statusSuccess.withValues(alpha: 0.4);

                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: heroBg,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusLg,
                              ),
                              border: Border.all(
                                color: heroBorder,
                                width: colors.isHighContrast ? 2 : 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: iconBg,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.directions_bus,
                                              color: colors.statusSuccess,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Flexible(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'My Journey',
                                                  style: TextStyle(
                                                    color: heroTitle,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${activeTicket.busId} → ${activeTicket.destination.name}',
                                                  style: TextStyle(
                                                    color: heroBody,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: chipBg,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          'On Track',
                                          style: TextStyle(
                                            color: chipFg,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Divider(color: divider, height: 1),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.location_on,
                                            color: heroBody,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '3 stops',
                                                  style: TextStyle(
                                                    color: heroTitle,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                                Text(
                                                  'remaining',
                                                  style: TextStyle(
                                                    color: heroBody,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      height: 30,
                                      width: 1,
                                      color: divider,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.access_time_filled,
                                            color: heroBody,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '6 min',
                                                  style: TextStyle(
                                                    color: heroTitle,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                                Text(
                                                  'estimated arrival',
                                                  style: TextStyle(
                                                    color: heroBody,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
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
                                      final routes =
                                          widget.repository.allRoutes;
                                      if (routes.isNotEmpty) {
                                        widget.controller.selectRoute(
                                          routes.first,
                                        );
                                      }
                                      final ticketToTrack = activeTicket;
                                      unawaited(
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => LiveLocationScreen(
                                              ticket: ticketToTrack,
                                              repository: widget.repository,
                                              ticketController:
                                                  widget.ticketController,
                                            ),
                                          ),
                                        ).then((_) {
                                          if (mounted) {
                                            widget.ticketController.refresh();
                                            setState(() {});
                                          }
                                        }),
                                      );
                                    },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: colors.actionPrimary,
                                      foregroundColor: colors.onActionPrimary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusMd,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.map_outlined,
                                          color: colors.onActionPrimary,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            'View Journey Details',
                                            style: TextStyle(
                                              color: colors.onActionPrimary,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(
                                          Icons.chevron_right,
                                          color: colors.onActionPrimary,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
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
                          Icon(
                            Icons.eco_outlined,
                            color: colors.textMuted,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'More Accessible Cities',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'for a Brighter Tomorrow',
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Icon(
                        Icons.directions_bus_filled_outlined,
                        color: colors.border,
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
    final colors = AppTheme.colors(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.border,
          width: colors.isHighContrast ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.dashboard_customize_outlined,
            color: colors.textSecondary,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            'All Home Cards Hidden',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You have hidden all feature cards on your home screen. Tap below to restore default cards.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: AppSettingsController.instance.resetHomeScreenLayout,
            style: FilledButton.styleFrom(
              backgroundColor: colors.actionPrimary,
              foregroundColor: colors.onActionPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: Icon(Icons.restore, color: colors.onActionPrimary, size: 20),
            label: Text(
              'Restore Default Cards',
              style: TextStyle(
                color: colors.onActionPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomCardForItem(
    HomeScreenItem item,
    bool hasActiveTicket,
    Ticket? activeTicket,
  ) {
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

      case HomeScreenItem.idMyTickets:
        return _buildTaskActionCard(
          color: item.color,
          icon: item.icon,
          title: item.title,
          subtitle: item.subtitle,
          semanticLabel: '${item.title}. ${item.subtitle}.',
          onTap: () {
            unawaited(
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      MyTicketsPage(ticketController: widget.ticketController),
                ),
              ).then((_) {
                if (mounted) {
                  widget.ticketController.refresh();
                  setState(() {});
                }
              }),
            );
          },
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
            unawaited(
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => GeminiLiveScreen(
                    ticketController: widget.ticketController,
                    repository: widget.repository,
                  ),
                ),
              ),
            );
          },
        );

      case HomeScreenItem.idAlerts:
        return const SizedBox.shrink();

      case HomeScreenItem.idSafety:
        return _buildTaskActionCard(
          color: item.color,
          icon: item.icon,
          title: item.title,
          subtitle: item.subtitle,
          semanticLabel: '${item.title}. ${item.subtitle}.',
          onTap: () {
            unawaited(
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SafetySharingPage(activeTicket: activeTicket),
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
            unawaited(
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SettingsPage(
                    repository: widget.repository,
                    ticketController: widget.ticketController,
                  ),
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
    final colors = AppTheme.colors(context);
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: borderColor ?? colors.border),
              ),
              child: Row(
                children: [
                  // Single-accent indicator bar; red reserved for SOS.
                  Container(
                    width: 4,
                    constraints: const BoxConstraints(minHeight: 56),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    trailingIcon ?? Icons.chevron_right,
                    color: colors.textSecondary,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
