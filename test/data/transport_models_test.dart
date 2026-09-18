import 'package:busbuddy/data/models/transport_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Route equality and hashCode', () {
    test('equal Routes with distinct orderedStopIds lists share hashCode', () {
      final a = const Route(
        id: 'r1',
        displayName: 'Red Line',
        direction: 'Northbound',
        orderedStopIds: ['s1', 's2', 's3'],
      );

      // Construct a SEPARATE list with the same contents.
      final b = Route(
        id: 'r1',
        displayName: 'Red Line',
        direction: 'Northbound',
        orderedStopIds: ['s1', 's2', 's3'],
      );

      expect(a, equals(b), reason: 'operator == should consider these equal');
      expect(
        a.hashCode,
        equals(b.hashCode),
        reason:
            'hashCode must be equal for objects that operator == considers equal',
      );
    });

    test('Routes that differ in orderedStopIds are not equal', () {
      final a = const Route(
        id: 'r1',
        displayName: 'Red Line',
        direction: 'Northbound',
        orderedStopIds: ['s1', 's2', 's3'],
      );
      final b = const Route(
        id: 'r1',
        displayName: 'Red Line',
        direction: 'Northbound',
        orderedStopIds: ['s1', 's2', 's4'],
      );

      expect(a, isNot(equals(b)));
    });
  });
}
