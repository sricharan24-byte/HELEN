import 'package:flutter_test/flutter_test.dart';
import 'package:busbuddy/domain/ticketing/entities/fare.dart';
import 'package:busbuddy/domain/ticketing/entities/fare_engine.dart';
import 'package:busbuddy/domain/ticketing/entities/ticket.dart';

void main() {
  group('FareEngine - Standard Corridor', () {
    test('General passenger pays standard base fare ₹20 with 0% discount', () {
      final fare = FareEngine.calculateCorridorFare(PassengerType.general);
      expect(fare.baseFare, 20.0);
      expect(fare.amount, 20.0);
      expect(fare.basePaise, 2000);
      expect(fare.payablePaise, 2000);
      expect(fare.discountPaise, 0);
      expect(fare.discountPercentage, 0);
      expect(fare.effectiveDiscountAmount, 0.0);
      expect(fare.passengerType, PassengerType.general);
      expect(fare.ruleId, 'RULE_CORRIDOR_V1');
      expect(fare.hopCount, 4);
    });

    test('Student receives 40% concession discount -> ₹12 (1200 paise)', () {
      final fare = FareEngine.calculateCorridorFare(PassengerType.student);
      expect(fare.baseFare, 20.0);
      expect(fare.amount, 12.0);
      expect(fare.basePaise, 2000);
      expect(fare.payablePaise, 1200);
      expect(fare.discountPaise, 800);
      expect(fare.discountPercentage, 40);
      expect(fare.effectiveDiscountAmount, 8.0);
      expect(fare.passengerType, PassengerType.student);
      expect(fare.formattedSavings, '₹8');
    });

    test('Senior citizen receives 40% concession discount -> ₹12 (1200 paise)', () {
      final fare = FareEngine.calculateCorridorFare(PassengerType.senior);
      expect(fare.baseFare, 20.0);
      expect(fare.amount, 12.0);
      expect(fare.basePaise, 2000);
      expect(fare.payablePaise, 1200);
      expect(fare.discountPaise, 800);
      expect(fare.discountPercentage, 40);
      expect(fare.effectiveDiscountAmount, 8.0);
      expect(fare.passengerType, PassengerType.senior);
    });
  });

  group('FareEngine - Stop Count Traversal', () {
    test('Short-hop (1 to 3 stops) base fare is ₹15 (1500 paise)', () {
      final genFare = FareEngine.calculateByStopCount(
        stopCount: 2,
        passengerType: PassengerType.general,
      );
      expect(genFare.baseFare, 15.0);
      expect(genFare.amount, 15.0);
      expect(genFare.basePaise, 1500);
      expect(genFare.payablePaise, 1500);
      expect(genFare.ruleId, 'RULE_HOP_SHORT_V1');

      final studentFare = FareEngine.calculateByStopCount(
        stopCount: 3,
        passengerType: PassengerType.student,
      );
      expect(studentFare.baseFare, 15.0);
      expect(studentFare.amount, 9.0); // 1500 * 0.6 = 900 paise
      expect(studentFare.payablePaise, 900);
      expect(studentFare.discountPaise, 600);
    });

    test('Medium-hop (4 to 5 stops) base fare is ₹20 (2000 paise)', () {
      final genFare = FareEngine.calculateByStopCount(
        stopCount: 5,
        passengerType: PassengerType.general,
      );
      expect(genFare.baseFare, 20.0);
      expect(genFare.amount, 20.0);
      expect(genFare.basePaise, 2000);
      expect(genFare.ruleId, 'RULE_HOP_MEDIUM_V1');

      final seniorFare = FareEngine.calculateByStopCount(
        stopCount: 4,
        passengerType: PassengerType.senior,
      );
      expect(seniorFare.baseFare, 20.0);
      expect(seniorFare.amount, 12.0);
      expect(seniorFare.payablePaise, 1200);
    });

    test('Extended corridor (6+ stops) base fare is ₹25 (2500 paise)', () {
      final genFare = FareEngine.calculateByStopCount(
        stopCount: 7,
        passengerType: PassengerType.general,
      );
      expect(genFare.baseFare, 25.0);
      expect(genFare.amount, 25.0);
      expect(genFare.basePaise, 2500);
      expect(genFare.ruleId, 'RULE_HOP_EXTENDED_V1');

      final studentFare = FareEngine.calculateByStopCount(
        stopCount: 8,
        passengerType: PassengerType.student,
      );
      expect(studentFare.baseFare, 25.0);
      expect(studentFare.amount, 15.0);
      expect(studentFare.payablePaise, 1500);
    });
  });

  group('FareEngine - Route index calculations and Astra boundary cases', () {
    test('calculateRouteFare correctly handles forwards and backwards stop indices', () {
      final forwardFare = FareEngine.calculateRouteFare(
        originIndex: 0,
        destinationIndex: 4,
        passengerType: PassengerType.general,
      );
      expect(forwardFare.baseFare, 20.0);

      final backwardFare = FareEngine.calculateRouteFare(
        originIndex: 5,
        destinationIndex: 1,
        passengerType: PassengerType.general,
      );
      expect(backwardFare.baseFare, 20.0);
    });

    test('Zero hops (origin == destination) throws ArgumentError per Astra P0.1', () {
      expect(
        () => FareEngine.calculateRouteFare(
          originIndex: 2,
          destinationIndex: 2,
          passengerType: PassengerType.general,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => FareEngine.calculateByStopCount(
          stopCount: 0,
          passengerType: PassengerType.general,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Negative base fare clamps safely to 0.0 / 0 paise', () {
      final fare = FareEngine.calculateFromBase(
        baseFare: -50.0,
        passengerType: PassengerType.general,
      );
      expect(fare.baseFare, 0.0);
      expect(fare.amount, 0.0);
      expect(fare.basePaise, 0);
      expect(fare.payablePaise, 0);
    });
  });

  group('Fare value object equality and formatting', () {
    test('Equality holds for identical fare values with rule ID', () {
      final fare1 = Fare.fromPaise(
        basePaise: 2000,
        passengerType: PassengerType.general,
        discountPercentage: 0,
        ruleId: 'RULE_CORRIDOR_V1',
      );
      final fare2 = Fare.fromPaise(
        basePaise: 2000,
        passengerType: PassengerType.general,
        discountPercentage: 0,
        ruleId: 'RULE_CORRIDOR_V1',
      );
      expect(fare1, equals(fare2));
      expect(fare1.hashCode, equals(fare2.hashCode));
      expect(fare1.toString(), contains('₹20'));
      expect(fare1.toString(), contains('RULE_CORRIDOR_V1'));
    });
  });
}
