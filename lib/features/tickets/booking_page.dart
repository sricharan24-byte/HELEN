import 'package:flutter/material.dart';

import '../../data/models/ticket_model.dart';
import '../../data/models/transport_models.dart';
import '../journey/journey_controller.dart';
import 'ticket_booking_suite_page.dart';
import 'ticket_controller.dart';

/// Legacy entry point for booking, forwarding to [TicketBookingSuitePage].
class BookingPage extends StatelessWidget {
  const BookingPage({
    super.key,
    required this.ticketController,
    this.initialOrigin,
    this.initialDestination,
    this.initialBusId,
    this.initialPassengerType = PassengerType.general,
    this.initialPaymentMethod = PaymentMethod.upi,
    this.initialPassengerName,
    this.autoOpenCheckout = false,
    this.journeyController,
  });

  final TicketController ticketController;
  final Stop? initialOrigin;
  final Stop? initialDestination;
  final String? initialBusId;
  final PassengerType initialPassengerType;
  final PaymentMethod initialPaymentMethod;
  final String? initialPassengerName;
  final bool autoOpenCheckout;
  final JourneyController? journeyController;

  @override
  Widget build(BuildContext context) {
    return TicketBookingSuitePage(
      ticketController: ticketController,
      journeyController: journeyController,
      initialOrigin: initialOrigin,
      initialDestination: initialDestination,
      initialBusId: initialBusId,
      initialPassengerType: initialPassengerType,
      initialPaymentMethod: initialPaymentMethod,
      initialPassengerName: initialPassengerName,
      autoOpenCheckout: autoOpenCheckout,
    );
  }
}
