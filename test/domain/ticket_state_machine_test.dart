import 'package:flutter_test/flutter_test.dart';
import 'package:busbuddy/domain/core/failure.dart';
import 'package:busbuddy/domain/ticketing/entities/fare.dart';
import 'package:busbuddy/domain/ticketing/entities/ticket.dart';
import 'package:busbuddy/domain/transit/entities/stop.dart';

void main() {
  group('BUS-P0-02: Ticket Domain State Machine & Ledger Tests', () {
    const origin = Stop(id: 'vit-main-gate', name: 'VIT Main Gate', area: 'VIT');
    const destination = Stop(id: 'katpadi-railway-station', name: 'Katpadi', area: 'Katpadi');
    final fareQuote = FareQuote.fromPaise(
      basePaise: 2000,
      passengerType: PassengerType.general,
      discountPercentage: 0,
      hopCount: 4,
      ruleVersion: 'RULE_CORRIDOR_V1',
    );

    Ticket createTestTicket({TicketStatus initialStatus = TicketStatus.quoted}) {
      final now = DateTime.now();
      return Ticket(
        id: Ticket.generateSecureTicketId(now),
        routeId: 'vit-to-katpadi',
        routeName: 'VIT → Katpadi',
        origin: origin,
        destination: destination,
        busId: 'Bus 18B',
        passengerName: 'Pavan',
        passengerType: PassengerType.general,
        fareQuote: fareQuote,
        paymentMethod: PaymentMethod.upi,
        issuedAt: now,
        validUntil: now.add(const Duration(hours: 4)),
        status: initialStatus,
        qrCodeData: 'TEST-QR',
      );
    }

    test('Happy Path: quoted -> paymentPending -> issued -> active -> used', () {
      final t1 = createTestTicket(initialStatus: TicketStatus.quoted);
      expect(t1.status, equals(TicketStatus.quoted));
      expect(t1.ledger.length, equals(1));

      // 1. quoted -> paymentPending
      final r1 = t1.transitionTo(TicketStatus.paymentPending, reason: 'Initiated UPI payment');
      expect(r1.isSuccess, isTrue);
      final t2 = r1.valueOrNull!;
      expect(t2.status, equals(TicketStatus.paymentPending));
      expect(t2.ledger.length, equals(2));
      expect(t2.ledger.last.reason, equals('Initiated UPI payment'));

      // 2. paymentPending -> issued
      final r2 = t2.transitionTo(TicketStatus.issued, reason: 'Payment gateway confirmed callback');
      expect(r2.isSuccess, isTrue);
      final t3 = r2.valueOrNull!;
      expect(t3.status, equals(TicketStatus.issued));
      expect(t3.ledger.length, equals(3));

      // 3. issued -> active
      final r3 = t3.transitionTo(TicketStatus.active, reason: 'Ticket activated for boarding');
      expect(r3.isSuccess, isTrue);
      final t4 = r3.valueOrNull!;
      expect(t4.status, equals(TicketStatus.active));
      expect(t4.isActive, isTrue);
      expect(t4.ledger.length, equals(4));

      // 4. active -> used (terminal)
      final r4 = t4.transitionTo(TicketStatus.used, reason: 'Conductor scanned and validated ticket');
      expect(r4.isSuccess, isTrue);
      final t5 = r4.valueOrNull!;
      expect(t5.status, equals(TicketStatus.used));
      expect(t5.isTerminal, isTrue);
      expect(t5.ledger.length, equals(5));
    });

    test('Cancellation branch: quoted -> cancelled', () {
      final t = createTestTicket(initialStatus: TicketStatus.quoted);
      final res = t.transitionTo(TicketStatus.cancelled, reason: 'Commuter aborted');
      expect(res.isSuccess, isTrue);
      expect(res.valueOrNull!.status, equals(TicketStatus.cancelled));
      expect(res.valueOrNull!.isTerminal, isTrue);
    });

    test('Refund branch: active -> refunded', () {
      final t = createTestTicket(initialStatus: TicketStatus.active);
      final res = t.transitionTo(TicketStatus.refunded, reason: 'Bus breakdown refund');
      expect(res.isSuccess, isTrue);
      final refundedTicket = res.valueOrNull!;
      expect(refundedTicket.status, equals(TicketStatus.refunded));
      expect(refundedTicket.isTerminal, isTrue);
    });

    test('Expiry branch: active -> expired', () {
      final t = createTestTicket(initialStatus: TicketStatus.active);
      final res = t.transitionTo(TicketStatus.expired, reason: 'Time limit reached');
      expect(res.isSuccess, isTrue);
      expect(res.valueOrNull!.status, equals(TicketStatus.expired));
      expect(res.valueOrNull!.isTerminal, isTrue);
    });

    test('Terminal state immutability: terminal states reject all transitions', () {
      final terminalStatuses = [
        TicketStatus.used,
        TicketStatus.expired,
        TicketStatus.cancelled,
        TicketStatus.refunded,
      ];

      for (final terminalStatus in terminalStatuses) {
        final ticket = createTestTicket(initialStatus: terminalStatus);
        expect(ticket.isTerminal, isTrue);

        for (final target in TicketStatus.values) {
          final res = ticket.transitionTo(target);
          expect(res.isFailure, isTrue, reason: 'Terminal $terminalStatus must not transition to $target');
          expect(res.errorOrNull, isA<StateTransitionFailure>());
        }
      }
    });

    test('Duplicate transition rejection: transitioning to identical status fails', () {
      final t = createTestTicket(initialStatus: TicketStatus.active);
      final res = t.transitionTo(TicketStatus.active);
      expect(res.isFailure, isTrue);
      expect(res.errorOrNull, isA<StateTransitionFailure>());
    });

    test('Illegal transition skips: quoted -> active directly is rejected', () {
      final t = createTestTicket(initialStatus: TicketStatus.quoted);
      final res = t.transitionTo(TicketStatus.active);
      expect(res.isFailure, isTrue);
      expect(res.errorOrNull, isA<StateTransitionFailure>());
    });

    test('Secure Ticket ID uniqueness and structure', () {
      final ids = <String>{};
      final now = DateTime(2026, 9, 20);

      for (int i = 0; i < 1000; i++) {
        final id = Ticket.generateSecureTicketId(now);
        expect(id, startsWith('BB-20260920-'));
        expect(ids.contains(id), isFalse, reason: 'Duplicate ID generated: $id');
        ids.add(id);
      }
      expect(ids.length, equals(1000));
    });
  });
}
