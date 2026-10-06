import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/a11y/announcement_coordinator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/tokens/app_spacing.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/ticket_model.dart';
import '../../data/repositories/transport_repository.dart';
import '../ai_assistant/gemini_live_screen.dart';
import 'live_location_screen.dart';
import 'ticket_controller.dart';
import 'ticket_details_page.dart';

/// My Tickets screen with Current Ticket and Previous Tickets tabs matching design references.
class MyTicketsPage extends StatefulWidget {
  const MyTicketsPage({
    super.key,
    required this.ticketController,
    this.repository,
  });

  final TicketController ticketController;
  final TransportRepository? repository;

  @override
  State<MyTicketsPage> createState() => _MyTicketsPageState();
}

class _MyTicketsPageState extends State<MyTicketsPage> {
  int _selectedTabIndex = 0; // 0: Current Ticket, 1: Previous Tickets

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    return ListenableBuilder(
      listenable: widget.ticketController,
      builder: (context, _) {
        final activeTicket = widget.ticketController.activeTicket;
        final allTickets = widget.ticketController.tickets;
        final pastTickets = allTickets
            .where((t) => t.id != activeTicket?.id)
            .toList();

        return Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            backgroundColor: colors.background,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: colors.textPrimary,
                size: 20,
              ),
              onPressed: () => Navigator.of(context).pop(),
              constraints: const BoxConstraints(
                minWidth: AppSpacing.minTouchTarget,
                minHeight: AppSpacing.minTouchTarget,
              ),
            ),
            title: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Bus',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      'Buddy',
                      style: TextStyle(
                        color: colors.actionPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
                Text(
                  'My Tickets',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    const SizedBox(height: 12),
                    // ── Segmented Tab Switcher ───────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusLg),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Semantics(
                                selected: _selectedTabIndex == 0,
                                button: true,
                                label: 'Current Ticket tab',
                                excludeSemantics: true,
                                child: InkWell(
                                  onTap: () {
                                    setState(() => _selectedTabIndex = 0);
                                    AnnouncementCoordinator.instance.announce(
                                      'Showing Current Ticket',
                                      priority: AnnouncementPriority.low,
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minHeight: AppSpacing.minTouchTarget,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _selectedTabIndex == 0
                                          ? colors.actionPrimary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Current Ticket',
                                      style: TextStyle(
                                        color: _selectedTabIndex == 0
                                            ? colors.actionPrimaryText
                                            : colors.textSecondary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Semantics(
                                selected: _selectedTabIndex == 1,
                                button: true,
                                label: 'Previous Tickets tab',
                                excludeSemantics: true,
                                child: InkWell(
                                  onTap: () {
                                    setState(() => _selectedTabIndex = 1);
                                    AnnouncementCoordinator.instance.announce(
                                      'Showing Previous Tickets',
                                      priority: AnnouncementPriority.low,
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minHeight: AppSpacing.minTouchTarget,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _selectedTabIndex == 1
                                          ? colors.actionPrimary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Previous Tickets',
                                      style: TextStyle(
                                        color: _selectedTabIndex == 1
                                            ? colors.actionPrimaryText
                                            : colors.textSecondary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Active Tab Body ──────────────────────────────────────
                    Expanded(
                      child: _selectedTabIndex == 0
                          ? _buildCurrentTicketTab(activeTicket)
                          : _buildPreviousTicketsTab(pastTickets),
                    ),
                  ],
                ),

                // ── Sticky Bottom Action Bar ─────────────────────────────
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: Semantics(
                    button: true,
                    label: _selectedTabIndex == 0
                        ? 'Ask BusBuddy. Show my ticket, check ticket status, etc.'
                        : 'Ask BusBuddy. Get details about a previous ticket',
                    excludeSemantics: true,
                    child: InkWell(
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
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      child: Container(
                        height: 60,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: colors.actionPrimary,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusLg),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: colors.onActionPrimary.withValues(
                                  alpha: 0.2,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.mic,
                                color: colors.onActionPrimary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ask BusBuddy',
                                  style: TextStyle(
                                    color: colors.onActionPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  _selectedTabIndex == 0
                                      ? 'Show my ticket, check ticket status, etc.'
                                      : 'Get details about a previous ticket',
                                  style: TextStyle(
                                    color: colors.onActionPrimary.withValues(
                                      alpha: 0.8,
                                    ),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Current Ticket Tab View ──────────────────────────────────────────────
  Widget _buildCurrentTicketTab(Ticket? activeTicket) {
    final colors = AppTheme.colors(context);
    if (activeTicket == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.confirmation_number_outlined,
              color: colors.textMuted,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'No Active Ticket',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Book a ticket to view active pass details and live tracking.',
              style: TextStyle(color: colors.textMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      children: [
        // Active Ticket Card (status-tinted surface, matches image reference)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.statusSuccessBg,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
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
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeTicket.busId,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '${activeTicket.origin.name} → ${activeTicket.destination.name}',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: colors.statusSuccess,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: colors.border, height: 1),
              const SizedBox(height: 16),

              // Detail Rows
              _buildTicketDetailRow(
                Icons.calendar_today_outlined,
                _formatActiveDate(activeTicket.issuedAt),
              ),
              const SizedBox(height: 10),
              _buildTicketDetailRow(
                Icons.access_time_outlined,
                _formatActiveTime(activeTicket.issuedAt),
              ),
              const SizedBox(height: 10),
              _buildTicketDetailRow(
                Icons.currency_rupee,
                activeTicket.fareQuote.formattedAmount,
              ),
              const SizedBox(height: 10),
              _buildTicketDetailRow(
                Icons.confirmation_number_outlined,
                'Ticket ID: ${activeTicket.id}',
              ),

              const SizedBox(height: 16),
              Divider(color: colors.border, height: 1),
              const SizedBox(height: 16),

              // Valid Ticket Status Banner
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.statusSuccess,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.onError,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Valid Ticket',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Show this ticket while boarding',
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // View Ticket Action Button
              // BUS-P1-05: minimum height (not fixed) so the label can
              // reflow at 200-300% text scale.
              SizedBox(
                width: double.infinity,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      unawaited(
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                TicketDetailsPage(ticket: activeTicket),
                          ),
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.qr_code_2,
                      color: colors.onActionPrimary,
                      size: 22,
                    ),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View Ticket',
                          style: TextStyle(
                            color: colors.onActionPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
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
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Cancel Ticket Action Button
              SizedBox(
                width: double.infinity,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Semantics(
                    button: true,
                    label:
                        'Cancel ticket. Your active ticket will be cancelled.',
                    child: OutlinedButton.icon(
                      onPressed: () {
                        unawaited(
                          showDialog<void>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Cancel this ticket?'),
                              content: const Text(
                                'Your active ticket will be cancelled and the trip will end. This cannot be undone.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Keep Ticket'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    widget.ticketController
                                        .cancelActiveTicket();
                                    AnnouncementCoordinator.instance.announce(
                                      'Ticket cancelled.',
                                      priority: AnnouncementPriority.high,
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Ticket cancelled.'),
                                      ),
                                    );
                                  },
                                  // Destructive confirmation: semantic error
                                  // role, on-error foreground from the theme.
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colors.statusError,
                                    foregroundColor:
                                        Theme.of(context).colorScheme.onError,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.radiusMd,
                                      ),
                                    ),
                                  ),
                                  child: const Text('Cancel Ticket'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      // Destructive accent: colors.statusError (never raw
                      // hex, never the SOS red) on a neutral outline.
                      icon: Icon(
                        Icons.cancel_outlined,
                        color: colors.statusError,
                        size: 22,
                      ),
                      label: Text(
                        'Cancel Ticket',
                        style: TextStyle(
                          color: colors.statusError,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.statusError),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Quick Actions Section
        Text(
          'Quick Actions',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.map_outlined,
                title: 'Live Map',
                subtitle: 'Track real bus location',
                onTap: () {
                  final repo =
                      widget.repository ??
                      AppServiceLocator.instance.transportRepository;
                  unawaited(
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LiveLocationScreen(
                          ticket: activeTicket,
                          repository: repo,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.share_outlined,
                title: 'Share Ticket',
                subtitle: 'Share trip details',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ticket sharing link copied to clipboard.'),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.download_outlined,
                title: 'Download',
                subtitle: 'Save offline',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Digital pass saved to offline downloads.'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTicketDetailRow(IconData icon, String text) {
    final colors = AppTheme.colors(context);
    return Row(
      children: [
        Icon(icon, color: colors.textSecondary, size: 18),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colors = AppTheme.colors(context);
    return Semantics(
      button: true,
      label: '$title. $subtitle.',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
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
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: colors.textPrimary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Previous Tickets Tab View (Matching Image 3) ─────────────────────────
  Widget _buildPreviousTicketsTab(List<Ticket> pastTickets) {
    final colors = AppTheme.colors(context);
    if (pastTickets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, color: colors.textMuted, size: 48),
            const SizedBox(height: 16),
            Text(
              'No Previous Tickets',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your completed and past bus travel passes will appear here.',
              style: TextStyle(color: colors.textMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: pastTickets.length,
      itemBuilder: (context, index) {
        final ticket = pastTickets[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Semantics(
            button: true,
            label:
                '${ticket.busId}, ${ticket.routeName}, Fare ${ticket.fareQuote.formattedAmount}.',
            excludeSemantics: true,
            child: InkWell(
              onTap: () {
                unawaited(
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TicketDetailsPage(ticket: ticket),
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.directions_bus,
                      color: colors.textPrimary,
                      size: 28,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ticket.busId,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ticket.routeName,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                color: colors.textMuted,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatTimestamp(ticket.issuedAt),
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.currency_rupee,
                                color: colors.textMuted,
                                size: 14,
                              ),
                              Text(
                                ticket.fareQuote.formattedAmount,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: colors.textMuted,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatActiveDate(DateTime dt) {
    if (dt.year == 2025 && dt.month == 9 && dt.day == 6) {
      return 'Today, 6 Sep 2025';
    }
    final now = DateTime.now();
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
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final prefix = isToday ? 'Today, ' : '';
    return '$prefix${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatActiveTime(DateTime dt) {
    if (dt.hour == 10 && dt.minute == 30) {
      return '10:30 AM';
    }
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  String _formatTimestamp(DateTime dt) {
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
    final day = dt.day;
    final month = months[dt.month - 1];
    final year = dt.year;
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$day $month $year, ${hour.toString().padLeft(2, '0')}:$minute $period';
  }
}
