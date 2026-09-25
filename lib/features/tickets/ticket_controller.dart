import 'package:flutter/foundation.dart';

import '../../data/datasources/local_json_store.dart';
import '../../data/models/ticket_model.dart';
import '../../data/models/transport_models.dart';
import '../../data/repositories/ticket_repository.dart';

class TicketController extends ChangeNotifier {
  TicketController(this._repository);

  final TicketRepository _repository;

  List<Ticket> get tickets => _repository.allTickets;
  Ticket? get activeTicket => _repository.activeTicket;
  bool get hasActiveTicket => _repository.hasActiveTicket;

  /// Hydrates ticket state from persistent storage across process death.
  Future<void> hydrate(LocalJsonStore store) async {
    if (_repository is LocalTicketRepository) {
      await (_repository).hydrate(store);
    }
    notifyListeners();
  }

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

  /// Marks the active ticket as expired when the ride ends — arrival at the
  /// destination or an explicit End Trip (including early alighting).
  /// Terminal-state tickets are left untouched.
  void completeActiveTrip({String reason = 'Reached destination'}) {
    final active = activeTicket;
    if (active != null) {
      _repository.completeTicket(active.id, reason: reason);
      notifyListeners();
    }
  }

  void refresh() {
    notifyListeners();
  }
}
