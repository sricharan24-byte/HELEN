import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/datasources/local_json_store.dart';
import '../../data/models/ticket_model.dart';
import '../../data/models/transport_models.dart';
import '../../data/repositories/ticket_repository.dart';

class TicketController extends ChangeNotifier {
  TicketController(this._repository) {
    _scheduleExpiryCheck();
  }

  final TicketRepository _repository;
  Timer? _expiryTimer;

  List<Ticket> get tickets => _repository.allTickets;
  Ticket? get activeTicket => _repository.activeTicket;
  bool get hasActiveTicket => _repository.hasActiveTicket;

  /// Hydrates ticket state from persistent storage across process death.
  Future<void> hydrate(LocalJsonStore store) async {
    if (_repository is LocalTicketRepository) {
      await (_repository).hydrate(store);
    }
    _scheduleExpiryCheck();
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
    _scheduleExpiryCheck();
    notifyListeners();
    return ticket;
  }

  void addTicket(Ticket ticket) {
    _repository.addTicket(ticket);
    _scheduleExpiryCheck();
    notifyListeners();
  }

  void cancelActiveTicket() {
    _repository.cancelAllActiveTickets();
    _scheduleExpiryCheck();
    notifyListeners();
  }

  void completeTicket(String ticketId, {String reason = 'Reached destination'}) {
    _repository.completeTicket(ticketId, reason: reason);
    _scheduleExpiryCheck();
    notifyListeners();
  }

  /// Marks all active tickets as expired when the ride ends — arrival at the
  /// destination or an explicit End Trip (including early alighting).
  /// Terminal-state tickets are left untouched.
  void completeActiveTrip({String reason = 'Reached destination'}) {
    _repository.completeAllActiveTickets(reason: reason);
    _scheduleExpiryCheck();
    notifyListeners();
  }

  /// Checks if the active ticket has elapsed and triggers notification if expired.
  void checkExpiry() {
    final active = _repository.activeTicket;
    if (active == null) {
      if (_expiryTimer != null) {
        _expiryTimer?.cancel();
        _expiryTimer = null;
        notifyListeners();
      }
      return;
    }
    if (DateTime.now().isAfter(active.validUntil)) {
      _repository.completeAllActiveTickets(reason: 'Validity window elapsed');
      _expiryTimer?.cancel();
      _expiryTimer = null;
      notifyListeners();
    }
  }

  void _scheduleExpiryCheck() {
    _expiryTimer?.cancel();
    _expiryTimer = null;

    final active = _repository.activeTicket;
    if (active == null) return;

    final remaining = active.validUntil.difference(DateTime.now());
    if (remaining.isNegative) {
      _repository.completeAllActiveTickets(reason: 'Validity window elapsed');
      return;
    }

    // Schedule timer to fire right when validUntil expires
    _expiryTimer = Timer(remaining + const Duration(milliseconds: 100), () {
      _repository.completeAllActiveTickets(reason: 'Validity window elapsed');
      notifyListeners();
      _scheduleExpiryCheck();
    });
  }

  void refresh() {
    checkExpiry();
    _scheduleExpiryCheck();
    notifyListeners();
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    super.dispose();
  }
}
