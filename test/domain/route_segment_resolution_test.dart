import 'package:flutter_test/flutter_test.dart';
import 'package:busbuddy/domain/transit/entities/transit_route.dart';
import 'package:busbuddy/domain/ticketing/entities/fare_engine.dart';
import 'package:busbuddy/domain/ticketing/entities/ticket.dart'
    show PassengerType;

void main() {
  group('Route Segment Resolution Tests (BUS-P1-02)', () {
    test('linear standard corridor route resolves correctly', () {
      final route = TransitRoute(
        id: 'route-linear',
        displayName: 'Linear Corridor',
        direction: 'North',
        orderedStopIds: ['A', 'B', 'C', 'D', 'E'],
      );

      final segment = route.resolveSegment(
        originStopId: 'B',
        destinationStopId: 'D',
      );

      expect(segment.isSuccess, isTrue);
      final val = segment.valueOrNull!;
      expect(val.hopCount, equals(2));
      expect(val.stopIds, equals(['B', 'C', 'D']));
      expect(val.originOccurrence.sequence, equals(1));
      expect(val.destinationOccurrence.sequence, equals(3));
    });

    test('repeated physical stop pattern A-B-C-B-D resolves forward segments without indexOf bug', () {
      // Physical stop 'B' occurs at sequence 1 and sequence 3
      final route = TransitRoute(
        id: 'route-repeated',
        displayName: 'Repeated Stop Route',
        direction: 'Outbound',
        orderedStopIds: ['A', 'B', 'C', 'B', 'D'],
      );

      // 1. Travel from C (seq 2) to B (seq 3)
      // Old indexOf would fail because indexOf('B') == 1 < indexOf('C') == 2.
      final segCtoB = route.resolveSegment(
        originStopId: 'C',
        destinationStopId: 'B',
      );
      expect(segCtoB.isSuccess, isTrue);
      final cToB = segCtoB.valueOrNull!;
      expect(cToB.hopCount, equals(1));
      expect(cToB.stopIds, equals(['C', 'B']));
      expect(cToB.originOccurrence.sequence, equals(2));
      expect(cToB.destinationOccurrence.sequence, equals(3));

      // 2. Travel from A to D traversing both occurrences of B
      final segAtoD = route.resolveSegment(
        originStopId: 'A',
        destinationStopId: 'D',
      );
      expect(segAtoD.isSuccess, isTrue);
      expect(segAtoD.valueOrNull!.hopCount, equals(4));
      expect(segAtoD.valueOrNull!.stopIds, equals(['A', 'B', 'C', 'B', 'D']));

      // 3. Explicit sequence disambiguation from first B (seq 1) to second B (seq 3)
      final segBtoB = route.resolveSegment(
        originStopId: 'B',
        destinationStopId: 'B',
        originSequence: 1,
        destinationSequence: 3,
      );
      expect(segBtoB.isSuccess, isTrue);
      expect(segBtoB.valueOrNull!.hopCount, equals(2));
      expect(segBtoB.valueOrNull!.stopIds, equals(['B', 'C', 'B']));
    });

    test('circular loop route A-B-C-A allows completing loop from C to terminal A', () {
      // Physical stop 'A' occurs at sequence 0 and sequence 3
      final route = TransitRoute(
        id: 'route-circular',
        displayName: 'Circular Loop',
        direction: 'Loop',
        orderedStopIds: ['A', 'B', 'C', 'A'],
      );

      // Travel from C (seq 2) back to A (seq 3)
      // Old indexOf would fail because indexOf('A') == 0 < indexOf('C') == 2.
      final segCtoA = route.resolveSegment(
        originStopId: 'C',
        destinationStopId: 'A',
      );
      expect(segCtoA.isSuccess, isTrue);
      final val = segCtoA.valueOrNull!;
      expect(val.hopCount, equals(1));
      expect(val.stopIds, equals(['C', 'A']));
      expect(val.originOccurrence.sequence, equals(2));
      expect(val.destinationOccurrence.sequence, equals(3));

      // Full loop from A (seq 0) to A (seq 3)
      final fullLoop = route.resolveSegment(
        originStopId: 'A',
        destinationStopId: 'A',
        originSequence: 0,
        destinationSequence: 3,
      );
      expect(fullLoop.isSuccess, isTrue);
      expect(fullLoop.valueOrNull!.hopCount, equals(3));
      expect(fullLoop.valueOrNull!.stopIds, equals(['A', 'B', 'C', 'A']));
    });

    test('same occurrence (0 hops) is rejected with typed failure', () {
      final route = TransitRoute(
        id: 'route-linear',
        displayName: 'Linear Corridor',
        direction: 'North',
        orderedStopIds: ['A', 'B', 'C'],
      );

      final result = route.resolveSegment(
        originStopId: 'B',
        destinationStopId: 'B',
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.message, contains('cannot be identical'));
    });

    test('reverse travel is explicitly rejected with typed failure', () {
      final route = TransitRoute(
        id: 'route-linear',
        displayName: 'Linear Corridor',
        direction: 'North',
        orderedStopIds: ['A', 'B', 'C', 'D'],
      );

      // Request D to B when route runs A -> B -> C -> D
      final result = route.resolveSegment(
        originStopId: 'D',
        destinationStopId: 'B',
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.isReverseTravel, isTrue);
      expect(result.failureOrNull!.message, contains('Reverse travel'));
    });

    test('fare engine parity with segment hop count', () {
      final route = TransitRoute(
        id: 'route-repeated',
        displayName: 'Corridor',
        direction: 'Outbound',
        orderedStopIds: ['A', 'B', 'C', 'B', 'D', 'E'],
      );

      // C (seq 2) to B (seq 3) = 1 hop -> short hop tier (1500 paise)
      final fare1Hop = FareEngine.quoteRouteFareResult(
        route: route,
        originStopId: 'C',
        destinationStopId: 'B',
        passengerType: PassengerType.general,
      );
      expect(fare1Hop.isSuccess, isTrue);
      expect(fare1Hop.valueOrNull!.finalPaise, equals(1500));
      expect(fare1Hop.valueOrNull!.hopCount, equals(1));

      // A (seq 0) to E (seq 5) = 5 hops -> medium hop tier (2000 paise)
      final fare5Hops = FareEngine.quoteRouteFareResult(
        route: route,
        originStopId: 'A',
        destinationStopId: 'E',
        passengerType: PassengerType.student,
      );
      expect(fare5Hops.isSuccess, isTrue);
      // 2000 paise base - 40% = 1200 paise
      expect(fare5Hops.valueOrNull!.finalPaise, equals(1200));
      expect(fare5Hops.valueOrNull!.hopCount, equals(5));
    });
  });
}
