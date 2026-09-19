import 'package:flutter_test/flutter_test.dart';
import 'package:busbuddy/domain/core/failure.dart';
import 'package:busbuddy/domain/safety/entities/emergency_contact.dart';
import 'package:busbuddy/domain/ticketing/entities/ticket.dart';
import 'package:busbuddy/domain/transit/entities/bus_position.dart';
import 'package:busbuddy/domain/transit/entities/stop.dart';
import 'package:busbuddy/domain/transit/entities/transit_route.dart';

void main() {
  group('Stop domain entity', () {
    test('coordinate validation and equality', () {
      const stop1 = Stop(
        id: 'vit-main-gate',
        name: 'VIT Main Gate',
        area: 'Katpadi',
        latitude: 12.9698,
        longitude: 79.1559,
      );

      const stop2 = Stop(
        id: 'vit-main-gate',
        name: 'VIT Main Gate',
        area: 'Katpadi',
      );

      expect(stop1.hasCoordinates, isTrue);
      expect(stop2.hasCoordinates, isFalse);
      expect(stop1, equals(stop2));
      expect(stop1.hashCode, equals(stop2.hashCode));
      expect(stop1.toString(), contains('VIT Main Gate'));
    });
  });

  group('TransitRoute domain entity', () {
    final route = TransitRoute(
      id: 'route-18b',
      displayName: 'Route 18B',
      direction: 'VIT to Katpadi',
      orderedStopIds: ['s1', 's2', 's3', 's4'],
    );

    test('properties, containment, and stop sequencing', () {
      expect(route.stopCount, 4);
      expect(route.containsStop('s2'), isTrue);
      expect(route.containsStop('non-existent'), isFalse);
      expect(route.indexOfStop('s3'), 2);

      // Valid forward sequence
      expect(route.isValidSequence('s1', 's4'), isTrue);
      expect(route.isValidSequence('s2', 's3'), isTrue);

      // Invalid backwards sequence
      expect(route.isValidSequence('s4', 's1'), isFalse);

      // Invalid non-existent stops
      expect(route.isValidSequence('s1', 'unknown'), isFalse);
    });

    test('defensively copies orderedStopIds as unmodifiable per Astra Table 2.1', () {
      expect(
        () => (route.orderedStopIds as dynamic).add('s5'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('equality and hash code', () {
      final route2 = TransitRoute(
        id: 'route-18b',
        displayName: 'Route 18B',
        direction: 'VIT to Katpadi',
        orderedStopIds: ['s1', 's2', 's3', 's4'],
      );
      expect(route, equals(route2));
      expect(route.hashCode, equals(route2.hashCode));
      expect(route.toString(), contains('stops: 4'));
    });
  });

  group('BusPosition domain entity', () {
    final now = DateTime(2026, 9, 19, 12, 0);
    final pos = BusPosition(
      busId: 'BUS-18B',
      routeId: 'route-18b',
      latitude: 12.97,
      longitude: 79.16,
      speedKmh: 34.5,
      nextStopId: 'stop-chittoor',
      nextStopName: 'Chittoor Bus Stand',
      etaMinutes: 4,
      timestamp: now,
      progressPercentage: 0.55,
      isSimulated: true,
    );

    test('properties, simulation tracking, and copyWith', () {
      expect(pos.isSimulated, isTrue);
      expect(pos.speedKmh, 34.5);
      expect(pos.etaMinutes, 4);

      final updated = pos.copyWith(speedKmh: 42.0, isSimulated: false);
      expect(updated.speedKmh, 42.0);
      expect(updated.isSimulated, isFalse);
      expect(updated.busId, pos.busId);
      expect(updated.nextStopName, pos.nextStopName);
    });

    test('equality and hash code', () {
      final pos2 = BusPosition(
        busId: 'BUS-18B',
        routeId: 'route-18b',
        latitude: 12.97,
        longitude: 79.16,
        speedKmh: 99.0, // speed doesn't affect identity
        nextStopId: 'other',
        nextStopName: 'other',
        etaMinutes: 1,
        timestamp: now,
        progressPercentage: 0.9,
      );
      expect(pos, equals(pos2));
      expect(pos.hashCode, equals(pos2.hashCode));
    });
  });

  group('Ticket domain entity serialization, validation, and state machine', () {
    final issued = DateTime.now();
    final validUntil = issued.add(const Duration(hours: 3));

    final ticket = Ticket(
      id: 'TICKET-001',
      routeId: 'route-18b',
      routeName: 'Route 18B',
      origin: const Stop(id: 's1', name: 'VIT', area: 'Katpadi'),
      destination: const Stop(id: 's2', name: 'Katpadi RS', area: 'Katpadi'),
      busId: 'BUS-18B',
      passengerName: 'Pavan',
      passengerType: PassengerType.student,
      fareAmount: 12.0,
      paymentMethod: PaymentMethod.upi,
      issuedAt: issued,
      validUntil: validUntil,
      status: TicketStatus.active,
      qrCodeData: 'QR-DATA-12345',
    );

    test('roundtrip serialization via toJson and fromJson', () {
      final json = ticket.toJson();
      final revived = Ticket.fromJson(json);

      expect(revived.id, ticket.id);
      expect(revived.passengerName, ticket.passengerName);
      expect(revived.passengerType, PassengerType.student);
      expect(revived.fareAmount, 12.0);
      expect(revived.paymentMethod, PaymentMethod.upi);
      expect(revived.status, TicketStatus.active);
      expect(revived.origin.name, 'VIT');
      expect(revived.destination.name, 'Katpadi RS');
      expect(revived.isActive, isTrue);
    });

    test('state machine validates legal transitions per Astra Table 2.1', () {
      expect(ticket.canTransitionTo(TicketStatus.used), isTrue);
      expect(ticket.canTransitionTo(TicketStatus.expired), isTrue);

      final usedTicket = ticket.transitionTo(TicketStatus.used);
      expect(usedTicket.status, TicketStatus.used);

      // Terminal state cannot transition back to active
      expect(usedTicket.canTransitionTo(TicketStatus.active), isFalse);
      expect(
        () => usedTicket.transitionTo(TicketStatus.active),
        throwsA(isA<StateError>()),
      );
    });

    test('fromJson rejects negative fare and malformed dates', () {
      final badFareJson = ticket.toJson()..['fareAmount'] = -10.0;
      expect(() => Ticket.fromJson(badFareJson), throwsA(isA<FormatException>()));

      final badDateJson = ticket.toJson()..['validUntil'] = 'not-a-date';
      expect(() => Ticket.fromJson(badDateJson), throwsA(isA<FormatException>()));
    });
  });

  group('EmergencyContact domain entity', () {
    test('valid contact and serialization roundtrip', () {
      const contact = EmergencyContact(
        name: 'Jane Doe',
        phone: '+91 9876543210',
        relation: 'Sister',
        isTrusted: true,
      );

      expect(contact.isValid, isTrue);
      final map = contact.toMap();
      final revived = EmergencyContact.fromMap(map);

      expect(revived, equals(contact));
      expect(revived.name, 'Jane Doe');
      expect(revived.phone, '+91 9876543210');
      expect(revived.relation, 'Sister');
    });

    test('isValid rejects blank fields', () {
      const invalid = EmergencyContact(
        name: ' ',
        phone: '',
        relation: 'None',
      );
      expect(invalid.isValid, isFalse);
    });
  });

  group('Domain Failures', () {
    test('subclasses instantiate with message and code', () {
      const f1 = NetworkFailure('No internet connection', code: 503);
      const f2 = StorageFailure('Disk full', code: 507);
      const f3 = ValidationFailure('Invalid passenger type');
      const f4 = NotFoundFailure('Route not found');
      const f5 = ServiceUnavailableFailure('Transit server maintenance');

      expect(f1.message, 'No internet connection');
      expect(f1.code, 503);
      expect(f1.toString(), contains('NetworkFailure'));
      expect(f2.toString(), contains('StorageFailure'));
      expect(f3.toString(), contains('ValidationFailure'));
      expect(f4.toString(), contains('NotFoundFailure'));
      expect(f5.toString(), contains('ServiceUnavailableFailure'));
    });
  });
}
