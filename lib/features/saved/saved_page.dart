import 'package:flutter/material.dart';

import '../tickets/booking_page.dart';
import '../tickets/my_tickets_page.dart';
import '../tickets/ticket_controller.dart';
import '../tickets/ticket_details_page.dart';

class SavedPage extends StatelessWidget {
  const SavedPage({super.key, required this.ticketController});

  final TicketController ticketController;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: ticketController,
      builder: (context, _) {
        final tickets = ticketController.tickets;
        final activeTicket = ticketController.activeTicket;

        return Scaffold(
          backgroundColor: const Color(0xFFF4F6F8),
          appBar: AppBar(
            title: const Text('Saved Passes & Favorites'),
            centerTitle: true,
            backgroundColor: const Color(0xFFF4F6F8),
            foregroundColor: const Color(0xFF002B7F),
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
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Active Pass Highlight Card
                if (activeTicket != null) ...[
                  Text(
                    'ACTIVE DIGITAL PASS',
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF64748B),
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
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF002B7F),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.confirmation_number_outlined, color: Colors.white, size: 24),
                                  SizedBox(width: 10),
                                  Text(
                                    'Active Pass',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
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
                            style: textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Bus ${activeTicket.busId} • ${activeTicket.origin.name} → ${activeTicket.destination.name}',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text('Tap to view QR Code Pass', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w700)),
                              Icon(Icons.qr_code_2, color: Colors.white, size: 28),
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
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.confirmation_number_outlined, size: 48, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 12),
                        Text(
                          'No Active Digital Pass',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Book a digital pass to enable QR boarding and active bus tracking.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF64748B)),
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
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF002B7F)),
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
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                if (tickets.isEmpty)
                  const Text('No previous ticket history.', style: TextStyle(color: Color(0xFF64748B)))
                else
                  ...tickets.map((t) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE8EEFF),
                          foregroundColor: Color(0xFF002B7F),
                          child: Icon(Icons.receipt_long),
                        ),
                        title: Text(t.routeName, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                        subtitle: Text('ID: ${t.id} • ₹${t.fareAmount.toStringAsFixed(0)}'),
                        trailing: const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
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
