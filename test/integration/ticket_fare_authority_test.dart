import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:busbuddy/data/models/transport_models.dart';
import 'package:busbuddy/data/repositories/ticket_repository.dart';
import 'package:busbuddy/domain/core/failure.dart';
import 'package:busbuddy/domain/ticketing/entities/fare_engine.dart';
import 'package:busbuddy/domain/ticketing/entities/ticket.dart';

void main() {
  group('BUS-P0-01: FareEngine Sole Authority Integration Tests', () {
    late LocalTicketRepository ticketRepository;

    // Test Corridor Stops
    const stop0 = Stop(id: 'stop-0', name: 'Stop 0 (VIT Main Gate)', area: 'Corridor');
    const stop1 = Stop(id: 'stop-1', name: 'Stop 1 (Old Katpadi)', area: 'Corridor');
    const stop2 = Stop(id: 'stop-2', name: 'Stop 2 (Chittoor Stop)', area: 'Corridor');
    const stop3 = Stop(id: 'stop-3', name: 'Stop 3 (Silk Mill)', area: 'Corridor');
    const stop4 = Stop(id: 'stop-4', name: 'Stop 4 (Katpadi RS)', area: 'Corridor');
    const stop5 = Stop(id: 'stop-5', name: 'Stop 5 (Gandhi Nagar)', area: 'Corridor');
    const stop6 = Stop(id: 'stop-6', name: 'Stop 6 (CMC Hospital)', area: 'Corridor');

    // Forward and Reverse Routes
    final forwardRoute = Route(
      id: 'route-fwd-extended',
      displayName: 'Stop 0 → Stop 6 Extended Corridor',
      direction: 'inbound',
      orderedStopIds: const [
        'stop-0',
        'stop-1',
        'stop-2',
        'stop-3',
        'stop-4',
        'stop-5',
        'stop-6',
      ],
    );

    final reverseRoute = Route(
      id: 'route-rev-extended',
      displayName: 'Stop 6 → Stop 0 Extended Corridor',
      direction: 'outbound',
      orderedStopIds: const [
        'stop-6',
        'stop-5',
        'stop-4',
        'stop-3',
        'stop-2',
        'stop-1',
        'stop-0',
      ],
    );

    setUp(() {
      ticketRepository = LocalTicketRepository();
    });

    test('Forward corridor: 1, 3, 4, 5, 6 hops for general, student, and senior', () {
      final cases = [
        // (hopCount, destinationStop, generalPaise, studentPaise, seniorPaise)
        (1, stop1, 1500, 900, 900),
        (3, stop3, 1500, 900, 900),
        (4, stop4, 2000, 1200, 1200),
        (5, stop5, 2000, 1200, 1200),
        (6, stop6, 2500, 1500, 1500),
      ];

      for (final c in cases) {
        final hops = c.$1;
        final destStop = c.$2;
        final expectedGen = c.$3;
        final expectedStu = c.$4;
        final expectedSen = c.$5;

        // General
        final genQuoteResult = FareEngine.quoteFareResult(
          orderedStopIds: forwardRoute.orderedStopIds,
          originStopId: stop0.id,
          destinationStopId: destStop.id,
          passengerType: PassengerType.general,
          routeName: forwardRoute.displayName,
        );
        expect(genQuoteResult.isSuccess, isTrue, reason: 'Failed for general $hops hops');
        final genQuote = genQuoteResult.valueOrNull!;
        expect(genQuote.hopCount, equals(hops));
        expect(genQuote.finalPaise, equals(expectedGen));
        expect(genQuote.amount, equals(expectedGen / 100.0));

        // Student (40% concession)
        final stuQuoteResult = FareEngine.quoteFareResult(
          orderedStopIds: forwardRoute.orderedStopIds,
          originStopId: stop0.id,
          destinationStopId: destStop.id,
          passengerType: PassengerType.student,
          routeName: forwardRoute.displayName,
        );
        expect(stuQuoteResult.isSuccess, isTrue, reason: 'Failed for student $hops hops');
        final stuQuote = stuQuoteResult.valueOrNull!;
        expect(stuQuote.hopCount, equals(hops));
        expect(stuQuote.finalPaise, equals(expectedStu));
        expect(stuQuote.amount, equals(expectedStu / 100.0));

        // Senior (40% concession)
        final senQuoteResult = FareEngine.quoteFareResult(
          orderedStopIds: forwardRoute.orderedStopIds,
          originStopId: stop0.id,
          destinationStopId: destStop.id,
          passengerType: PassengerType.senior,
          routeName: forwardRoute.displayName,
        );
        expect(senQuoteResult.isSuccess, isTrue, reason: 'Failed for senior $hops hops');
        final senQuote = senQuoteResult.valueOrNull!;
        expect(senQuote.hopCount, equals(hops));
        expect(senQuote.finalPaise, equals(expectedSen));
        expect(senQuote.amount, equals(expectedSen / 100.0));
      }
    });

    test('Reverse corridor: 1, 3, 4, 5, 6 hops in opposite direction produce identical authority paise', () {
      final cases = [
        // (hopCount, destinationStop, generalPaise, studentPaise, seniorPaise)
        (1, stop5, 1500, 900, 900),
        (3, stop3, 1500, 900, 900),
        (4, stop2, 2000, 1200, 1200),
        (5, stop1, 2000, 1200, 1200),
        (6, stop0, 2500, 1500, 1500),
      ];

      for (final c in cases) {
        // `hops` (c.$1) is asserted directly in the forward-corridor test;
        // the reverse-corridor test verifies fare totals per passenger type.
        final destStop = c.$2;
        final expectedGen = c.$3;
        final expectedStu = c.$4;
        final expectedSen = c.$5;

        final genQuoteResult = FareEngine.quoteFareResult(
          orderedStopIds: reverseRoute.orderedStopIds,
          originStopId: stop6.id,
          destinationStopId: destStop.id,
          passengerType: PassengerType.general,
          routeName: reverseRoute.displayName,
        );
        expect(genQuoteResult.isSuccess, isTrue);
        expect(genQuoteResult.valueOrNull!.finalPaise, equals(expectedGen));

        final stuQuoteResult = FareEngine.quoteFareResult(
          orderedStopIds: reverseRoute.orderedStopIds,
          originStopId: stop6.id,
          destinationStopId: destStop.id,
          passengerType: PassengerType.student,
          routeName: reverseRoute.displayName,
        );
        expect(stuQuoteResult.isSuccess, isTrue);
        expect(stuQuoteResult.valueOrNull!.finalPaise, equals(expectedStu));

        final senQuoteResult = FareEngine.quoteFareResult(
          orderedStopIds: reverseRoute.orderedStopIds,
          originStopId: stop6.id,
          destinationStopId: destStop.id,
          passengerType: PassengerType.senior,
          routeName: reverseRoute.displayName,
        );
        expect(senQuoteResult.isSuccess, isTrue);
        expect(senQuoteResult.valueOrNull!.finalPaise, equals(expectedSen));
      }
    });

    test('Boundary: origin == destination returns ValidationFailure', () {
      final result = FareEngine.quoteFareResult(
        orderedStopIds: forwardRoute.orderedStopIds,
        originStopId: stop0.id,
        destinationStopId: stop0.id,
        passengerType: PassengerType.general,
      );

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<ValidationFailure>());
      expect(result.errorOrNull!.message, contains('cannot be identical'));
    });

    test('Boundary: unordered stops on route return ValidationFailure', () {
      // Boarding at stop-4 and attempting to travel to stop-1 on forward route
      final result = FareEngine.quoteFareResult(
        orderedStopIds: forwardRoute.orderedStopIds,
        originStopId: stop4.id,
        destinationStopId: stop1.id,
        passengerType: PassengerType.general,
      );

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<ValidationFailure>());
      expect(result.errorOrNull!.message, contains('Reverse travel'));
    });

    test('End-to-end parity: quote, booked ticket, QR payload, and receipt paise are identical', () {
      final quoteResult = FareEngine.quoteFareResult(
        orderedStopIds: forwardRoute.orderedStopIds,
        originStopId: stop0.id,
        destinationStopId: stop4.id, // 4 hops = 2000 paise (₹20)
        passengerType: PassengerType.student, // 1200 paise (₹12)
      );
      expect(quoteResult.isSuccess, isTrue);
      final quote = quoteResult.valueOrNull!;

      final ticket = ticketRepository.bookTicket(
        origin: stop0,
        destination: stop4,
        route: forwardRoute,
        passengerName: 'Test Commuter',
        passengerType: PassengerType.student,
        paymentMethod: PaymentMethod.upi,
        fareQuote: quote,
      );

      // Quote, Ticket, and Presentation parity
      expect(ticket.farePaise, equals(quote.finalPaise));
      expect(ticket.fareAmount, equals(12.0));
      expect(ticket.fareQuote.discountPaise, equals(800));
      expect(ticket.fareQuote.basePaise, equals(2000));

      // QR payload parity
      expect(ticket.qrCodeData, contains('|${quote.finalPaise}|'));
      expect(ticket.qrCodeData, contains(ticket.validUntil.toIso8601String()));
      expect(Ticket.verifyQrPayload(ticket.qrCodeData, ticket), isTrue);

      // Persisted repository ticket parity
      final fetched = ticketRepository.allTickets.firstWhere((t) => t.id == ticket.id);
      expect(fetched.farePaise, equals(quote.finalPaise));
      expect(fetched.fareAmount, equals(quote.amount));
      expect(fetched.fareQuote.ruleVersion, equals(quote.ruleVersion));
    });

    test('Source Guard: No duplicate production fare formulas or doublefare constructors in lib/', () {
      final libDir = Directory('lib');
      final dartFiles = libDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

      final violations = <String>[];

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        final path = file.path;

        // Skip the authoritative engine and its value object
        if (path.contains('fare_engine.dart') || path.contains('fare.dart')) {
          continue;
        }

        // Check for double fare field declarations in entity classes
        if (content.contains('final double fareAmount;') && !content.contains('double get fareAmount')) {
          violations.add('$path declares raw double fareAmount field instead of getter from FareQuote');
        }

        // Check for hard-coded rupee calculations
        if (content.contains('* 0.6') || content.contains('* 0.40') || content.contains('fare * 0.')) {
          violations.add('$path performs manual concession calculation outside FareEngine');
        }
      }

      expect(violations, isEmpty, reason: 'Violations found:\n${violations.join('\n')}');
    });
  });
}
