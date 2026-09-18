import 'dart:math';

import '../datasources/local_json_store.dart';
import '../models/ticket_model.dart';
import '../models/transport_models.dart';

abstract class TicketRepository {
  List<Ticket> get allTickets;
  Ticket? get activeTicket;
  bool get hasActiveTicket;

  Ticket bookTicket({
    required Stop origin,
    required Stop destination,
    required Route route,
    required String passengerName,
    required PassengerType passengerType,
    required PaymentMethod paymentMethod,
  });

  void addTicket(Ticket ticket);
  void cancelTicket(String ticketId);
}

class LocalTicketRepository implements TicketRepository {
  LocalTicketRepository() {
    final now = DateTime.now();
    _tickets.addAll([
      Ticket(
        id: 'BB184256',
        routeId: 'vit-to-katpadi',
        routeName: 'VIT Main Gate → Katpadi',
        origin: const Stop(id: 'vit-main-gate', name: 'VIT Main Gate', area: 'VIT University'),
        destination: const Stop(id: 'katpadi-railway-station', name: 'Katpadi', area: 'Katpadi'),
        busId: 'Bus 18B',
        passengerName: 'Pavan K',
        passengerType: PassengerType.general,
        fareAmount: 25.0,
        paymentMethod: PaymentMethod.upi,
        issuedAt: DateTime(2025, 9, 6, 10, 30),
        validUntil: now.add(const Duration(hours: 4)),
        status: TicketStatus.active,
        qrCodeData: 'BUSBUDDY::BB184256::vit-main-gate::katpadi-railway-station::Bus 18B',
      ),
      Ticket(
        id: 'BB184102',
        routeId: 'vit-to-vellore',
        routeName: 'VIT Main Gate → Vellore',
        origin: const Stop(id: 'vit-main-gate', name: 'VIT Main Gate', area: 'VIT University'),
        destination: const Stop(id: 'old-bus-stand', name: 'Vellore', area: 'Vellore Central'),
        busId: 'Bus 12A',
        passengerName: 'Pavan K',
        passengerType: PassengerType.general,
        fareAmount: 30.0,
        paymentMethod: PaymentMethod.upi,
        issuedAt: DateTime(2025, 9, 2, 8, 15),
        validUntil: DateTime(2025, 9, 2, 12, 15),
        status: TicketStatus.expired,
        qrCodeData: 'BUSBUDDY::BB184102::vit-main-gate::old-bus-stand::Bus 12A',
      ),
      Ticket(
        id: 'BB183950',
        routeId: 'vit-to-katpadi',
        routeName: 'VIT Main Gate → Katpadi',
        origin: const Stop(id: 'vit-main-gate', name: 'VIT Main Gate', area: 'VIT University'),
        destination: const Stop(id: 'katpadi-railway-station', name: 'Katpadi', area: 'Katpadi'),
        busId: 'Bus 18B',
        passengerName: 'Pavan K',
        passengerType: PassengerType.general,
        fareAmount: 25.0,
        paymentMethod: PaymentMethod.upi,
        issuedAt: DateTime(2025, 8, 28, 18, 40),
        validUntil: DateTime(2025, 8, 28, 22, 40),
        status: TicketStatus.expired,
        qrCodeData: 'BUSBUDDY::BB183950::vit-main-gate::katpadi-railway-station::Bus 18B',
      ),
      Ticket(
        id: 'BB183812',
        routeId: 'vit-to-arcot',
        routeName: 'VIT Main Gate → Arcot',
        origin: const Stop(id: 'vit-main-gate', name: 'VIT Main Gate', area: 'VIT University'),
        destination: const Stop(id: 'arcot-bus-stand', name: 'Arcot', area: 'Arcot'),
        busId: 'Bus 20C',
        passengerName: 'Pavan K',
        passengerType: PassengerType.general,
        fareAmount: 30.0,
        paymentMethod: PaymentMethod.upi,
        issuedAt: DateTime(2025, 8, 25, 11, 20),
        validUntil: DateTime(2025, 8, 25, 15, 20),
        status: TicketStatus.expired,
        qrCodeData: 'BUSBUDDY::BB183812::vit-main-gate::arcot-bus-stand::Bus 20C',
      ),
      Ticket(
        id: 'BB183700',
        routeId: 'vellore-to-vit',
        routeName: 'Vellore → VIT Main Gate',
        origin: const Stop(id: 'old-bus-stand', name: 'Vellore', area: 'Vellore Central'),
        destination: const Stop(id: 'vit-main-gate', name: 'VIT Main Gate', area: 'VIT University'),
        busId: 'Bus 12A',
        passengerName: 'Pavan K',
        passengerType: PassengerType.general,
        fareAmount: 30.0,
        paymentMethod: PaymentMethod.upi,
        issuedAt: DateTime(2025, 8, 20, 17, 10),
        validUntil: DateTime(2025, 8, 20, 21, 10),
        status: TicketStatus.expired,
        qrCodeData: 'BUSBUDDY::BB183700::old-bus-stand::vit-main-gate::Bus 12A',
      ),
    ]);
  }

  static const storageKey = 'busbuddy.tickets.v1';
  final List<Ticket> _tickets = [];
  LocalJsonStore? _store;

  Future<void> hydrate(LocalJsonStore store) async {
    await store.flush();
    _store = store;
    final stored = store.read(storageKey);
    if (stored.absent) {
      await store.write(storageKey, _snapshot());
      return;
    }
    final value = stored.value;
    if (value is! List) return;
    final parsed = <Ticket>[];
    for (final item in value) {
      try {
        if (item is! Map<String, dynamic>) continue;
        final ticket = Ticket.fromJson(item);
        if (parsed.every((existing) => existing.id != ticket.id)) {
          parsed.add(ticket);
        }
      } on FormatException {
        continue;
      }
    }
    _tickets
      ..clear()
      ..addAll(parsed);
  }

  List<Map<String, Object?>> _snapshot() =>
      _tickets.map((ticket) => ticket.toJson()).toList();

  void _persist() => _store?.write(storageKey, _snapshot());

  @override
  List<Ticket> get allTickets => List<Ticket>.unmodifiable(_tickets);

  @override
  Ticket? get activeTicket {
    final now = DateTime.now();
    for (final ticket in _tickets) {
      if (ticket.status == TicketStatus.active && ticket.validUntil.isAfter(now)) {
        return ticket;
      }
    }
    return null;
  }

  @override
  bool get hasActiveTicket => activeTicket != null;

  @override
  Ticket bookTicket({
    required Stop origin,
    required Stop destination,
    required Route route,
    required String passengerName,
    required PassengerType passengerType,
    required PaymentMethod paymentMethod,
  }) {
    final now = DateTime.now();
    final randomId = Random().nextInt(899999) + 100000;
    final ticketId = 'TKT-$randomId';
    final busId = 'TN-23-BUS-${Random().nextInt(89) + 10}';

    // Fare calculation: Base fare ₹15 + ₹5 per stop difference
    final originIdx = route.orderedStopIds.indexOf(origin.id);
    final destIdx = route.orderedStopIds.indexOf(destination.id);
    final stopCount = (originIdx != -1 && destIdx != -1 && destIdx > originIdx)
        ? (destIdx - originIdx)
        : 2;
    double fare = (15.0 + (stopCount - 1) * 5.0).clamp(15.0, 50.0);
    if (passengerType == PassengerType.student || passengerType == PassengerType.senior) {
      fare = (fare * 0.6).roundToDouble(); // 40% concession discount
    }

    final ticket = Ticket(
      id: ticketId,
      routeId: route.id,
      routeName: route.displayName,
      origin: origin,
      destination: destination,
      busId: busId,
      passengerName: passengerName.trim().isEmpty ? 'Passholder' : passengerName,
      passengerType: passengerType,
      fareAmount: fare,
      paymentMethod: paymentMethod,
      issuedAt: now,
      validUntil: now.add(const Duration(hours: 4)),
      status: TicketStatus.active,
      qrCodeData: 'BUSBUDDY::$ticketId::${origin.id}::${destination.id}::$busId',
    );

    // Prepend to ticket history so newest is first
    _tickets.insert(0, ticket);
    _persist();
    return ticket;
  }

  @override
  void addTicket(Ticket ticket) {
    _tickets.insert(0, ticket);
    _persist();
  }

  @override
  void cancelTicket(String ticketId) {
    final index = _tickets.indexWhere((t) => t.id == ticketId);
    if (index != -1) {
      _tickets[index] = _tickets[index].copyWith(status: TicketStatus.expired);
      _persist();
    }
  }
}
