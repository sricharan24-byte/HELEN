import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/tokens/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../tickets/booking_page.dart';
import '../tickets/my_tickets_page.dart';
import '../tickets/ticket_controller.dart';
import '../tickets/ticket_details_page.dart';

class SavedPage extends StatelessWidget {
  const SavedPage({super.key, required this.ticketController});

  final TicketController ticketController;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final textTheme = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: ticketController,
      builder: (context, _) {
        final tickets = ticketController.tickets;
        final activeTicket = ticketController.activeTicket;

        return Scaffold(
          backgroundColor: colors.surfaceBackground,
          appBar: AppBar(
            title: const Text('Saved Passes & Favorites'),
            centerTitle: true,
            backgroundColor: colors.surfaceBackground,
            foregroundColor: colors.primaryBlue,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.confirmation_number),
                tooltip: 'My Tickets Hub',
                onPressed: () {
                  unawaited(
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            MyTicketsPage(ticketController: ticketController),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Active Pass Highlight Card
                if (activeTicket != null) ...[
                  Text(
                    'ACTIVE DIGITAL PASS',
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      unawaited(
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                TicketDetailsPage(ticket: activeTicket),
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusLg,
                        ),
                        border: Border.all(color: colors.cardBorder),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Standard 4dp accent bar on the leading edge,
                            // matching the home task-card pattern.
                            Container(width: 4, color: colors.actionPrimary),
                            Expanded(
                              child: Padding(
                                padding: AppSpacing.cardPadding,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      runSpacing: 6,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons
                                                  .confirmation_number_outlined,
                                              color: colors.textPrimary,
                                              size: 24,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              'Active Pass',
                                              style: TextStyle(
                                                color: colors.textPrimary,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colors.statusSuccessBg,
                                            borderRadius: BorderRadius.circular(
                                              AppSpacing.radiusSm,
                                            ),
                                          ),
                                          child: Text(
                                            'READY TO BOARD',
                                            style: TextStyle(
                                              color: colors.statusSuccess,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      activeTicket.routeName,
                                      style: textTheme.titleMedium?.copyWith(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Bus ${activeTicket.busId} • ${activeTicket.origin.name} → ${activeTicket.destination.name}',
                                      style: TextStyle(
                                        color: colors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      runSpacing: 6,
                                      children: [
                                        Text(
                                          'Tap to view QR Code Pass',
                                          style: TextStyle(
                                            color: colors.actionPrimary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Icon(
                                          Icons.qr_code_2,
                                          color: colors.textPrimary,
                                          size: 28,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  // Empty state book pass prompt
                  Container(
                    padding: AppSpacing.cardPadding,
                    decoration: BoxDecoration(
                      color: colors.surfaceCard,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      border: Border.all(color: colors.cardBorder),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.confirmation_number_outlined,
                          size: 48,
                          color: colors.textMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No Active Digital Pass',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Book a digital pass to enable QR boarding and active bus tracking.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.textMuted),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () {
                            unawaited(
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => BookingPage(
                                    ticketController: ticketController,
                                  ),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.confirmation_number_outlined,
                            size: 18,
                          ),
                          label: const Text('Book Digital Pass Now'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(
                              double.infinity,
                              AppSpacing.minTouchTarget,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Ticket History Section
                Text(
                  'TICKET PASSBOOK HISTORY (${tickets.length})',
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                if (tickets.isEmpty)
                  Text(
                    'No previous ticket history.',
                    style: TextStyle(color: colors.textMuted),
                  )
                else
                  ...tickets.map((t) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusLg,
                        ),
                        border: Border.all(color: colors.cardBorder),
                      ),
                      child: Material(
                        color: colors.surfaceCard,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusLg,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: colors.primaryBlue.withValues(
                              alpha: 0.12,
                            ),
                            foregroundColor: colors.primaryBlue,
                            child: const Icon(Icons.receipt_long),
                          ),
                          title: Text(
                            t.routeName,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            'ID: ${t.id} • Fare ${t.fareQuote.formattedAmount}',
                            style: TextStyle(color: colors.textMuted),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: colors.textMuted,
                          ),
                          onTap: () {
                            unawaited(
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => TicketDetailsPage(ticket: t),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
}
