import 'package:flutter/foundation.dart';

import '../../data/models/ticket_model.dart';
import '../../data/models/transport_models.dart';
import '../../data/repositories/ticket_repository.dart';

class TicketController extends ChangeNotifier {
  TicketController(this._repository);

  final TicketRepository _repository;

  List<Ticket> get tickets => _repository.allTickets;
  Ticket? get activeTicket => _repository.activeTicket;
  bool get hasActiveTicket => _repository.hasActiveTicket;

  Ticket bookTicket({
    required Stop origin,
    required Stop destination,
    required Route route,
    String passengerName = 'Passholder',
    PassengerType passengerType = PassengerType.general,
    PaymentMethod paymentMethod = PaymentMethod.upi,
  }) {
    final ticket = _repository.bookTicket(
      origin: origin,
      destination: destination,
      route: route,
      passengerName: passengerName,
      passengerType: passengerType,
      paymentMethod: paymentMethod,
    );
    notifyListeners();
    return ticket;
  }

  void addTicket(Ticket ticket) {
    _repository.addTicket(ticket);
    notifyListeners();
  }

  void cancelActiveTicket() {
    final active = activeTicket;
    if (active != null) {
      _repository.cancelTicket(active.id);
      notifyListeners();
    }
  }

  void refresh() {
    notifyListeners();
  }
}
