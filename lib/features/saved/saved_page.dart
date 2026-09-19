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
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MyTicketsPage(ticketController: ticketController),
                    ),
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
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
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TicketDetailsPage(ticket: activeTicket),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.cardPadding),
                      decoration: BoxDecoration(
                        color: colors.primaryBlue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.confirmation_number_outlined, color: colors.cardBackground, size: 24),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Active Pass',
                                    style: TextStyle(color: colors.cardBackground, fontWeight: FontWeight.w800, fontSize: 16),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colors.successGreen,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'READY TO BOARD',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            activeTicket.routeName,
                            style: textTheme.titleMedium?.copyWith(color: colors.cardBackground, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Bus ${activeTicket.busId} • ${activeTicket.origin.name} → ${activeTicket.destination.name}',
                            style: TextStyle(color: colors.cardBackground.withOpacity(0.8), fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Tap to view QR Code Pass', style: TextStyle(color: colors.accentYellow, fontWeight: FontWeight.w700)),
                              Icon(Icons.qr_code_2, color: colors.cardBackground, size: 28),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  // Empty state book pass prompt
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.cardPadding),
                    decoration: BoxDecoration(
                      color: colors.surfaceCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.cardBorder),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.confirmation_number_outlined, size: 48, color: colors.textMuted),
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
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => BookingPage(ticketController: ticketController),
                              ),
                            );
                          },
                          icon: const Icon(Icons.confirmation_number_outlined, size: 18),
                          label: const Text('Book Digital Pass Now'),
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.primaryBlue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, AppSpacing.minTouchTarget),
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
                  Text('No previous ticket history.', style: TextStyle(color: colors.textMuted))
                else
                  ...tickets.map((t) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.cardBorder),
                      ),
                      child: Material(
                        color: colors.surfaceCard,
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: colors.primaryBlue.withOpacity(0.12),
                            foregroundColor: colors.primaryBlue,
                            child: const Icon(Icons.receipt_long),
                          ),
                          title: Text(t.routeName, style: TextStyle(fontWeight: FontWeight.w700, color: colors.textPrimary)),
                          subtitle: Text(
                            'ID: ${t.id} • ₹${t.fareAmount.toStringAsFixed(0)}',
                            style: TextStyle(color: colors.textMuted),
                          ),
                          trailing: Icon(Icons.chevron_right, color: colors.textMuted),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TicketDetailsPage(ticket: t),
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
