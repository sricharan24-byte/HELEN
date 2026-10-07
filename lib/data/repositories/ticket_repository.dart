import 'dart:math';

import '../datasources/local_json_store.dart';
import '../models/ticket_model.dart';
import '../models/transport_models.dart';
import '../../domain/ticketing/entities/fare_engine.dart';

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
    FareQuote? fareQuote,
    DateTime? travelDate,
  });

  void addTicket(Ticket ticket);
  void cancelTicket(String ticketId);

  /// Marks the active ticket as expired when the journey completes — arrival
  /// at the destination ("Reached destination") or an explicit End Trip.
  /// No-op for unknown ids or tickets that already left the active state.
  void completeTicket(String ticketId, {String reason = 'Reached destination'});

  /// Marks all currently active tickets as expired.
  void completeAllActiveTickets({String reason = 'Reached destination'});

  /// Cancels all currently active tickets.
  void cancelAllActiveTickets({String reason = 'User cancelled ticket'});
}

class LocalTicketRepository implements TicketRepository {
  LocalTicketRepository() {
    final extendedQuote = FareEngine.calculateByStopCount(
      stopCount: 6,
      passengerType: PassengerType.general,
    );
    final katpadiQuote = FareEngine.calculateByStopCount(
      stopCount: 4,
      passengerType: PassengerType.general,
    );

    // Seed history only: past (expired) demo tickets for the Previous
    // Tickets tab. There is deliberately NO active seed — a fresh install
    // starts with no ticket until the rider books one.
    _tickets.addAll([
      Ticket(
        id: 'BB-20250902-184102',
        routeId: 'vit-to-vellore',
        routeName: 'VIT Main Gate → Vellore',
        origin: const Stop(
          id: 'vit-main-gate',
          name: 'VIT Main Gate',
          area: 'VIT University',
        ),
        destination: const Stop(
          id: 'old-bus-stand',
          name: 'Vellore',
          area: 'Vellore Central',
        ),
        busId: 'Bus 12A',
        passengerName: 'Pavan K',
        passengerType: PassengerType.general,
        fareQuote: extendedQuote,
        paymentMethod: PaymentMethod.upi,
        issuedAt: DateTime(2025, 9, 2, 8, 15),
        validUntil: DateTime(2025, 9, 2, 12, 15),
        status: TicketStatus.expired,
        qrCodeData: Ticket.buildQrPayload(
          ticketId: 'BB-20250902-184102',
          originId: 'vit-main-gate',
          destinationId: 'old-bus-stand',
          busId: 'Bus 12A',
          farePaise: extendedQuote.finalPaise,
          validUntil: DateTime(2025, 9, 2, 12, 15),
          isDemo: true,
        ),
        isDemo: true,
      ),
      Ticket(
        id: 'BB-20250828-183950',
        routeId: 'vit-to-katpadi',
        routeName: 'VIT Main Gate → Katpadi',
        origin: const Stop(
          id: 'vit-main-gate',
          name: 'VIT Main Gate',
          area: 'VIT University',
        ),
        destination: const Stop(
          id: 'katpadi-railway-station',
          name: 'Katpadi',
          area: 'Katpadi',
        ),
        busId: 'Bus 18B',
        passengerName: 'Pavan K',
        passengerType: PassengerType.general,
        fareQuote: katpadiQuote,
        paymentMethod: PaymentMethod.upi,
        issuedAt: DateTime(2025, 8, 28, 18, 40),
        validUntil: DateTime(2025, 8, 28, 22, 40),
        status: TicketStatus.expired,
        qrCodeData: Ticket.buildQrPayload(
          ticketId: 'BB-20250828-183950',
          originId: 'vit-main-gate',
          destinationId: 'katpadi-railway-station',
          busId: 'Bus 18B',
          farePaise: katpadiQuote.finalPaise,
          validUntil: DateTime(2025, 8, 28, 22, 40),
          isDemo: true,
        ),
        isDemo: true,
      ),
      Ticket(
        id: 'BB-20250825-183812',
        routeId: 'vit-to-arcot',
        routeName: 'VIT Main Gate → Arcot',
        origin: const Stop(
          id: 'vit-main-gate',
          name: 'VIT Main Gate',
          area: 'VIT University',
        ),
        destination: const Stop(
          id: 'arcot-bus-stand',
          name: 'Arcot',
          area: 'Arcot',
        ),
        busId: 'Bus 20C',
        passengerName: 'Pavan K',
        passengerType: PassengerType.general,
        fareQuote: extendedQuote,
        paymentMethod: PaymentMethod.upi,
        issuedAt: DateTime(2025, 8, 25, 11, 20),
        validUntil: DateTime(2025, 8, 25, 15, 20),
        status: TicketStatus.expired,
        qrCodeData: Ticket.buildQrPayload(
          ticketId: 'BB-20250825-183812',
          originId: 'vit-main-gate',
          destinationId: 'arcot-bus-stand',
          busId: 'Bus 20C',
          farePaise: extendedQuote.finalPaise,
          validUntil: DateTime(2025, 8, 25, 15, 20),
          isDemo: true,
        ),
        isDemo: true,
      ),
      Ticket(
        id: 'BB-20250820-183700',
        routeId: 'vellore-to-vit',
        routeName: 'Vellore → VIT Main Gate',
        origin: const Stop(
          id: 'old-bus-stand',
          name: 'Vellore',
          area: 'Vellore Central',
        ),
        destination: const Stop(
          id: 'vit-main-gate',
          name: 'VIT Main Gate',
          area: 'VIT University',
        ),
        busId: 'Bus 12A',
        passengerName: 'Pavan K',
        passengerType: PassengerType.general,
        fareQuote: extendedQuote,
        paymentMethod: PaymentMethod.upi,
        issuedAt: DateTime(2025, 8, 20, 17, 10),
        validUntil: DateTime(2025, 8, 20, 21, 10),
        status: TicketStatus.expired,
        qrCodeData: Ticket.buildQrPayload(
          ticketId: 'BB-20250820-183700',
          originId: 'old-bus-stand',
          destinationId: 'vit-main-gate',
          busId: 'Bus 12A',
          farePaise: extendedQuote.finalPaise,
          validUntil: DateTime(2025, 8, 20, 21, 10),
          isDemo: true,
        ),
        isDemo: true,
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

    // One-time migration: drop the legacy pre-booked demo ticket
    // (BB-20250906-184256) if it is still sitting active in a persisted
    // store from an older install. Fresh installs never create it.
    final legacyIndex = _tickets.indexWhere(
      (t) => t.id == 'BB-20250906-184256' && t.status == TicketStatus.active,
    );
    if (legacyIndex != -1) {
      _tickets.removeAt(legacyIndex);
      _persist();
    }

    // Cleanly transition any expired active tickets per BUS-P1-10
    _sweepExpiredTickets(reason: 'Validity window elapsed during app closure');
  }

  /// Sweeps through all stored tickets and transitions any active tickets
  /// whose validity window has elapsed to [TicketStatus.expired].
  bool _sweepExpiredTickets({String reason = 'Validity window elapsed'}) {
    final now = DateTime.now();
    bool hadExpiredTransition = false;
    for (int i = 0; i < _tickets.length; i++) {
      final t = _tickets[i];
      if (t.status == TicketStatus.active && t.validUntil.isBefore(now)) {
        final transition = t.transitionTo(
          TicketStatus.expired,
          reason: reason,
        );
        if (transition.isSuccess) {
          _tickets[i] = transition.valueOrNull!;
          hadExpiredTransition = true;
        }
      }
    }
    if (hadExpiredTransition) {
      _persist();
    }
    return hadExpiredTransition;
  }

  List<Map<String, Object?>> _snapshot() =>
      _tickets.map((ticket) => ticket.toJson()).toList();

  void _persist() => _store?.write(storageKey, _snapshot());

  @override
  List<Ticket> get allTickets {
    _sweepExpiredTickets();
    return List<Ticket>.unmodifiable(_tickets);
  }

  @override
  Ticket? get activeTicket {
    _sweepExpiredTickets();
    final now = DateTime.now();
    for (final ticket in _tickets) {
      if (ticket.status == TicketStatus.active &&
          ticket.validUntil.isAfter(now)) {
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
    FareQuote? fareQuote,
    DateTime? travelDate,
  }) {
    final now = DateTime.now();
    final ticketId = Ticket.generateSecureTicketId(now);
    final busId = 'TN-23-BUS-${Random().nextInt(89) + 10}';

    // Authoritative FareEngine calculation in exact integer paise
    final originIdx = route.orderedStopIds.indexOf(origin.id);
    final destIdx = route.orderedStopIds.indexOf(destination.id);
    final stopCount = (originIdx != -1 && destIdx != -1 && destIdx > originIdx)
        ? (destIdx - originIdx)
        : (originIdx != -1 && destIdx != -1)
        ? (originIdx - destIdx).abs()
        : 2;

    final quote =
        fareQuote ??
        FareEngine.calculateByStopCount(
          stopCount: stopCount > 0 ? stopCount : 1,
          passengerType: passengerType,
        );

    final travelDay = travelDate ?? now;
    final dayEnd = DateTime(
      travelDay.year,
      travelDay.month,
      travelDay.day,
      23,
      59,
      59,
    );
    final finalizedValidUntil = dayEnd.isBefore(now)
        ? now.add(const Duration(hours: 4))
        : dayEnd;

    final qrPayload = Ticket.buildQrPayload(
      ticketId: ticketId,
      originId: origin.id,
      destinationId: destination.id,
      busId: busId,
      farePaise: quote.finalPaise,
      validUntil: finalizedValidUntil,
      isDemo: true,
    );

    final ticket = Ticket(
      id: ticketId,
      routeId: route.id,
      routeName: route.displayName,
      origin: origin,
      destination: destination,
      busId: busId,
      passengerName: passengerName.trim().isEmpty
          ? 'Passholder'
          : passengerName,
      passengerType: passengerType,
      fareQuote: quote,
      paymentMethod: paymentMethod,
      issuedAt: now,
      validUntil: finalizedValidUntil,
      status: TicketStatus.active,
      qrCodeData: qrPayload,
      isDemo: true,
    );

    // Ensure any previously active ticket is superseded and closed
    completeAllActiveTickets(reason: 'Superseded by new ticket booking');

    // Prepend to ticket history so newest is first
    _tickets.insert(0, ticket);
    _persist();
    return ticket;
  }

  @override
  void addTicket(Ticket ticket) {
    if (ticket.status == TicketStatus.active) {
      completeAllActiveTickets(reason: 'Superseded by new ticket booking');
    }
    _tickets.insert(0, ticket);
    _persist();
  }

  @override
  void cancelTicket(String ticketId) {
    final index = _tickets.indexWhere((t) => t.id == ticketId);
    if (index != -1) {
      final transitionResult = _tickets[index].transitionTo(
        TicketStatus.cancelled,
        reason: 'User cancelled ticket',
      );
      if (transitionResult.isSuccess) {
        _tickets[index] = transitionResult.valueOrNull!;
        _persist();
      }
    }
    _sweepExpiredTickets();
  }

  @override
  void completeTicket(
    String ticketId, {
    String reason = 'Reached destination',
  }) {
    final index = _tickets.indexWhere((t) => t.id == ticketId);
    if (index != -1) {
      final transitionResult = _tickets[index].transitionTo(
        TicketStatus.expired,
        reason: reason,
      );
      if (transitionResult.isSuccess) {
        _tickets[index] = transitionResult.valueOrNull!;
        _persist();
      }
    }
    _sweepExpiredTickets();
  }

  @override
  void completeAllActiveTickets({String reason = 'Reached destination'}) {
    _sweepExpiredTickets();
    bool changed = false;
    for (int i = 0; i < _tickets.length; i++) {
      if (_tickets[i].status == TicketStatus.active) {
        final transition = _tickets[i].transitionTo(
          TicketStatus.expired,
          reason: reason,
        );
        if (transition.isSuccess) {
          _tickets[i] = transition.valueOrNull!;
          changed = true;
        }
      }
    }
    if (changed) {
      _persist();
    }
  }

  @override
  void cancelAllActiveTickets({String reason = 'User cancelled ticket'}) {
    _sweepExpiredTickets();
    bool changed = false;
    for (int i = 0; i < _tickets.length; i++) {
      if (_tickets[i].status == TicketStatus.active) {
        final transition = _tickets[i].transitionTo(
          TicketStatus.cancelled,
          reason: reason,
        );
        if (transition.isSuccess) {
          _tickets[i] = transition.valueOrNull!;
          changed = true;
        }
      }
    }
    if (changed) {
      _persist();
    }
  }
}
