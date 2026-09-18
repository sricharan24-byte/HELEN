import 'package:flutter/material.dart';

import '../../data/models/transport_models.dart';
import 'ticket_booking_suite_page.dart';
import 'ticket_controller.dart';

/// Legacy entry point for booking, forwarding to [TicketBookingSuitePage].
class BookingPage extends StatelessWidget {
  const BookingPage({
    super.key,
    required this.ticketController,
    this.initialOrigin,
    this.initialDestination,
  });

  final TicketController ticketController;
  final Stop? initialOrigin;
  final Stop? initialDestination;

  @override
  Widget build(BuildContext context) {
    return TicketBookingSuitePage(
      ticketController: ticketController,
      initialOrigin: initialOrigin,
      initialDestination: initialDestination,
    );
  }
}
