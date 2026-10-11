import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/data/models/transport_models.dart';
import 'package:busbuddy/domain/ticketing/entities/ticket.dart';
import 'package:busbuddy/features/ai_assistant/app_automation_controller.dart';

void main() {
  group('booking slot provenance', () {
    test('passengerToolCallsMarkSlotSourcesAsPassenger', () {
      final automation = AppAutomationController();

      automation.handleToolCall('set_trip', {
        'origin': 'VIT Main Gate',
        'destination': 'Katpadi Railway Station',
      });
      expect(
        automation.slotSources['origin'],
        BookingValueSource.passenger,
      );
      expect(
        automation.slotSources['destination'],
        BookingValueSource.passenger,
      );

      automation.handleToolCall('select_bus', {'busId': '18B'});
      expect(automation.slotSources['bus'], BookingValueSource.passenger);

      automation.handleToolCall('set_passenger', {
        'type': 'student',
        'name': 'Pavan',
      });
      expect(
        automation.slotSources['passengerType'],
        BookingValueSource.passenger,
      );
      expect(
        automation.slotSources['passengerName'],
        BookingValueSource.passenger,
      );

      automation.handleToolCall('set_payment', {'method': 'upi'});
      expect(
        automation.slotSources['paymentMethod'],
        BookingValueSource.passenger,
      );
    });

    test('correctionReplacesValueAndSource', () {
      final automation = AppAutomationController();

      automation.handleToolCall('set_trip', {
        'origin': 'VIT Main Gate',
        'destination': 'Katpadi Railway Station',
      });
      // A later passenger correction replaces both the value and the source;
      // the latest passenger utterance always wins.
      automation.handleToolCall('set_trip', {
        'origin': 'Katpadi Bus Stand',
      });
      expect(automation.origin?.name, 'Katpadi Bus Stand');
      expect(automation.slotSources['origin'], BookingValueSource.passenger);
    });

    test('profileDefaultsFillOnlyUnsetPassengerType', () {
      final automation = AppAutomationController();

      automation.applyProfileDefaults(
        preferredName: 'Pavan',
        passengerType: PassengerType.student,
      );
      // The profile default prefills the slot, marked as such…
      expect(automation.passengerType, PassengerType.student);
      expect(
        automation.slotSources['passengerType'],
        BookingValueSource.profileDefault,
      );
      // …the preferred name is stored for assistant address only and is
      // never assumed to be the ticket passenger's name…
      expect(automation.profilePreferredName, 'Pavan');
      expect(automation.passengerName, isNot('Pavan'));

      // …and an explicit passenger choice is never overwritten by a later
      // profile default.
      automation.handleToolCall('set_passenger', {'type': 'senior'});
      automation.applyProfileDefaults(
        preferredName: 'Pavan',
        passengerType: PassengerType.student,
      );
      expect(automation.passengerType, PassengerType.senior);
      expect(
        automation.slotSources['passengerType'],
        BookingValueSource.passenger,
      );
    });

    test('recentTripSuggestionWaitsForPassengerAcceptance', () {
      final automation = AppAutomationController();
      const origin = Stop(
        id: 'vit-main-gate',
        name: 'VIT Main Gate',
        area: 'VIT',
      );
      const destination = Stop(
        id: 'katpadi-railway-station',
        name: 'Katpadi Railway Station',
        area: 'Katpadi',
      );

      automation.stageRecentTripSuggestion(
        origin: origin,
        destination: destination,
        busId: 'Bus 18B',
      );
      // Staged values are visible in the draft, marked recentActivity…
      expect(automation.origin, origin);
      expect(automation.destination, destination);
      expect(automation.slotSources['origin'], BookingValueSource.recentActivity);
      expect(
        automation.slotSources['destination'],
        BookingValueSource.recentActivity,
      );
      expect(automation.slotSources['bus'], BookingValueSource.recentActivity);

      // …but they do not satisfy readiness on their own.
      final staged = automation.bookingReadiness();
      expect(staged.isComplete, isFalse);
      expect(staged.missingSlots, contains('trip'));
      expect(staged.missingSlots, contains('bus'));

      // Even with type and payment supplied, the staged suggestion alone
      // still cannot complete the booking.
      automation.handleToolCall('set_passenger', {'type': 'student'});
      automation.handleToolCall('set_payment', {'method': 'card'});
      expect(automation.bookingReadiness().isComplete, isFalse);

      // Passenger acceptance promotes the staged values to passenger.
      automation.acceptStagedSuggestion();
      expect(automation.slotSources['origin'], BookingValueSource.passenger);
      expect(
        automation.slotSources['destination'],
        BookingValueSource.passenger,
      );
      expect(automation.slotSources['bus'], BookingValueSource.passenger);
      final ready = automation.bookingReadiness();
      expect(ready.isComplete, isTrue);
      expect(ready.needsGateway, isTrue);
    });

    test('appFallbacksDoNotSatisfyReadiness', () {
      final automation = AppAutomationController();
      // Fresh controller carries app fallback values (Bus 18B / UPI).
      expect(automation.busId, contains('18B'));
      expect(automation.paymentMethod, PaymentMethod.upi);

      automation.handleToolCall('set_trip', {
        'origin': 'VIT Main Gate',
        'destination': 'Katpadi Railway Station',
      });
      automation.handleToolCall('set_passenger', {'type': 'general'});

      final readiness = automation.bookingReadiness();
      expect(readiness.isComplete, isFalse);
      // The bus and payment fallbacks must not masquerade as choices.
      expect(readiness.missingSlots, contains('bus'));
      expect(readiness.missingSlots, contains('payment'));

      automation.handleToolCall('select_bus', {'busId': '18B'});
      automation.handleToolCall('set_payment', {'method': 'upi'});
      expect(automation.bookingReadiness().isComplete, isTrue);
    });

    test('bookingReadinessRequiresTripBusPassengerAndPayment', () {
      final automation = AppAutomationController();

      var ready = automation.handleToolCall('confirm_booking', null);
      expect(ready.missingSlots, containsAll(<String>[
        'trip',
        'bus',
        'passenger',
        'payment',
      ]));

      automation.handleToolCall('set_trip', {
        'origin': 'VIT Main Gate',
        'destination': 'Katpadi Railway Station',
      });
      ready = automation.handleToolCall('confirm_booking', null);
      expect(ready.isComplete, isFalse);
      expect(ready.missingSlots, isNot(contains('trip')));

      automation.handleToolCall('select_bus', {'busId': '12A'});
      ready = automation.handleToolCall('confirm_booking', null);
      expect(ready.isComplete, isFalse);
      expect(ready.missingSlots, isNot(contains('bus')));

      automation.handleToolCall('set_passenger', {'type': 'student'});
      ready = automation.handleToolCall('confirm_booking', null);
      expect(ready.isComplete, isFalse);
      expect(ready.missingSlots, isNot(contains('passenger')));

      automation.handleToolCall('set_payment', {'method': 'wallet'});
      ready = automation.handleToolCall('confirm_booking', null);
      expect(ready.isComplete, isTrue);
      expect(ready.needsGateway, isTrue);
    });

    test('bookingDraftSnapshotIncludesOnlySlotValueAndSource', () {
      final automation = AppAutomationController();
      automation.handleToolCall('set_trip', {
        'origin': 'VIT Main Gate',
        'destination': 'Katpadi Railway Station',
      });
      automation.handleToolCall('select_bus', {'busId': '18B'});
      automation.handleToolCall('set_passenger', {'type': 'student'});
      automation.handleToolCall('set_payment', {'method': 'card'});

      final snapshot = automation.bookingDraftSnapshot();
      final slots = snapshot['slots'] as Map<String, Object?>;

      expect(
        slots.keys,
        unorderedEquals(<String>[
          'origin',
          'destination',
          'bus',
          'passengerName',
          'passengerType',
          'paymentMethod',
        ]),
      );
      for (final slot in slots.values) {
        expect((slot as Map).keys, unorderedEquals(<String>['value', 'source']));
      }
      expect(slots['bus'], {'value': 'Bus 18B', 'source': 'passenger'});
      expect(slots['passengerType'], {
        'value': 'student',
        'source': 'passenger',
      });
      expect(slots['paymentMethod'], {'value': 'Card', 'source': 'passenger'});
      // A fresh controller serializes the unset state honestly.
      final fresh = AppAutomationController().bookingDraftSnapshot();
      final freshSlots = fresh['slots'] as Map<String, Object?>;
      expect(freshSlots['origin'], {'value': '', 'source': 'unset'});
      expect(freshSlots['bus'], {'value': '18B', 'source': 'unset'});
    });
  });
}
