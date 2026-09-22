import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:busbuddy/data/datasources/local_json_store.dart';
import 'package:busbuddy/data/models/transport_models.dart';
import 'package:busbuddy/data/repositories/ticket_repository.dart';
import 'package:busbuddy/domain/ticketing/entities/fare_engine.dart';
import 'package:busbuddy/domain/ticketing/entities/ticket.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BUS-P0-02: Ticket Replay, Persistence, & Tamper Protection Integration Tests', () {
    const origin = Stop(id: 'vit-main-gate', name: 'VIT Main Gate', area: 'VIT');
    const destination = Stop(id: 'katpadi-railway-station', name: 'Katpadi', area: 'Katpadi');
    final corridorRoute = Route(
      id: 'vit-to-katpadi',
      displayName: 'VIT → Katpadi',
      direction: 'inbound',
      orderedStopIds: const [
        'vit-main-gate',
        'old-katpadi',
        'chittoor-bus-stop',
        'katpadi-bus-stand',
        'katpadi-railway-station',
      ],
    );

    final fareQuote = FareEngine.calculateByStopCount(
      stopCount: 4,
      passengerType: PassengerType.general,
    );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Tickets survive process restart and database rehydration with ledger intact', () async {
      final store = await LocalJsonStore.open();
      final repo1 = LocalTicketRepository();
      await repo1.hydrate(store);

      final booked = repo1.bookTicket(
        origin: origin,
        destination: destination,
        route: corridorRoute,
        passengerName: 'Astra Verifier',
        passengerType: PassengerType.general,
        paymentMethod: PaymentMethod.upi,
        fareQuote: fareQuote,
      );

      // Verify booked ticket has initial ledger entry
      expect(booked.ledger, isNotEmpty);
      expect(booked.ledger.first.status, equals(TicketStatus.active));
      expect(booked.isDemo, isTrue);

      await store.flush();

      // Simulate app restart with a new repository instance
      final repo2 = LocalTicketRepository();
      await repo2.hydrate(await LocalJsonStore.open());

      final restored = repo2.allTickets.firstWhere((t) => t.id == booked.id);
      expect(restored.id, equals(booked.id));
      expect(restored.farePaise, equals(booked.farePaise));
      expect(restored.status, equals(TicketStatus.active));
      expect(restored.validUntil.toIso8601String(), equals(booked.validUntil.toIso8601String()));
      expect(restored.ledger.length, equals(booked.ledger.length));
      expect(restored.isDemo, equals(booked.isDemo));
    });

    test('Duplicate ticket ID insertion is rejected / deduplicated on hydration', () async {
      final store = await LocalJsonStore.open();
      final repo = LocalTicketRepository();
      await repo.hydrate(store);

      final ticket = repo.bookTicket(
        origin: origin,
        destination: destination,
        route: corridorRoute,
        passengerName: 'Idempotency Commuter',
        passengerType: PassengerType.general,
        paymentMethod: PaymentMethod.upi,
      );

      // Pre-count intentionally omitted; duplicate handling is asserted via containsTicket.

      // Attempt to add duplicate ticket
      repo.addTicket(ticket);
      await store.flush();

      final reloadedRepo = LocalTicketRepository();
      await reloadedRepo.hydrate(await LocalJsonStore.open());

      // Assert that duplicate ID entries are ignored on hydration
      final occurrences = reloadedRepo.allTickets.where((t) => t.id == ticket.id).length;
      expect(occurrences, equals(1));
    });

    test('QR Code tampering is detected and rejected by verifyQrPayload', () {
      final now = DateTime.now();
      final validUntil = now.add(const Duration(hours: 4));
      final ticketId = Ticket.generateSecureTicketId(now);

      final legitimatePayload = Ticket.buildQrPayload(
        ticketId: ticketId,
        originId: origin.id,
        destinationId: destination.id,
        busId: 'Bus 18B',
        farePaise: 2000,
        validUntil: validUntil,
        isDemo: true,
      );

      final ticket = Ticket(
        id: ticketId,
        routeId: 'vit-to-katpadi',
        routeName: 'VIT → Katpadi',
        origin: origin,
        destination: destination,
        busId: 'Bus 18B',
        passengerName: 'Legitimate Commuter',
        passengerType: PassengerType.general,
        fareQuote: fareQuote,
        paymentMethod: PaymentMethod.upi,
        issuedAt: now,
        validUntil: validUntil,
        status: TicketStatus.active,
        qrCodeData: legitimatePayload,
        isDemo: true,
      );

      // Legitimate verification succeeds
      expect(Ticket.verifyQrPayload(legitimatePayload, ticket), isTrue);

      // Tampered ticket ID
      final tamperedId = legitimatePayload.replaceAll(ticketId, 'BB-FORGED-999');
      expect(Ticket.verifyQrPayload(tamperedId, ticket), isFalse);

      // Tampered fare (trying to spoof 100 paise instead of 2000 paise)
      final tamperedFare = legitimatePayload.replaceAll('|2000|', '|100|');
      expect(Ticket.verifyQrPayload(tamperedFare, ticket), isFalse);

      // Tampered destination stop
      final tamperedDest = legitimatePayload.replaceAll(destination.id, 'cmc-hospital');
      expect(Ticket.verifyQrPayload(tamperedDest, ticket), isFalse);
    });

    test('Replayed expired QR code fails validation after validity period expires', () {
      final pastDate = DateTime.now().subtract(const Duration(hours: 5));
      final expiredTicketId = Ticket.generateSecureTicketId(pastDate);

      // QR with expired validity
      final expiredPayload = Ticket.buildQrPayload(
        ticketId: expiredTicketId,
        originId: origin.id,
        destinationId: destination.id,
        busId: 'Bus 18B',
        farePaise: 2000,
        validUntil: pastDate, // in the past!
        isDemo: true,
      );

      final expiredTicket = Ticket(
        id: expiredTicketId,
        routeId: 'vit-to-katpadi',
        routeName: 'VIT → Katpadi',
        origin: origin,
        destination: destination,
        busId: 'Bus 18B',
        passengerName: 'Late Commuter',
        passengerType: PassengerType.general,
        fareQuote: fareQuote,
        paymentMethod: PaymentMethod.upi,
        issuedAt: pastDate.subtract(const Duration(hours: 1)),
        validUntil: pastDate,
        status: TicketStatus.expired,
        qrCodeData: expiredPayload,
        isDemo: true,
      );

      // Fails verification due to clock expiry
      expect(Ticket.verifyQrPayload(expiredPayload, expiredTicket), isFalse);
      expect(expiredTicket.isActive, isFalse);
    });

    test('Past travel date booking aligns QR expiry precisely with finalized ticket validUntil', () {
      final repo = LocalTicketRepository();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));

      final ticket = repo.bookTicket(
        origin: origin,
        destination: destination,
        route: corridorRoute,
        passengerName: 'Date Fallback Commuter',
        passengerType: PassengerType.general,
        paymentMethod: PaymentMethod.upi,
        travelDate: yesterday, // Past date forces fallback validity!
      );

      // Assert QR payload expiry matches finalized ticket.validUntil exactly
      expect(ticket.validUntil.isAfter(DateTime.now()), isTrue);
      expect(ticket.qrCodeData, contains(ticket.validUntil.toIso8601String()));
      expect(Ticket.verifyQrPayload(ticket.qrCodeData, ticket), isTrue);
    });
  });
}
