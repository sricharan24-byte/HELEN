import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/core/settings/app_settings_controller.dart';
import 'package:busbuddy/data/models/transport_models.dart';
import 'package:busbuddy/data/repositories/transport_repository.dart';
import 'package:busbuddy/data/repositories/ticket_repository.dart';
import 'package:busbuddy/domain/ticketing/entities/fare.dart';
import 'package:busbuddy/domain/ticketing/entities/ticket.dart';
import 'package:busbuddy/features/ai_assistant/booking_context.dart';
import 'package:busbuddy/features/tickets/ticket_controller.dart';

/// The builder only resolves saved stop IDs against the repository, so a
/// two-stop fake is enough to prove resolution, skipping, and privacy.
class _FakeStopRepository implements TransportRepository {
  _FakeStopRepository(this._stops);

  final Map<String, Stop> _stops;

  @override
  Stop? getStop(String stopId) => _stops[stopId];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('not needed by BookingContextBuilder');
}

void main() {
  final knownStops = {
    'vit-main-gate': const Stop(
      id: 'vit-main-gate',
      name: 'VIT Main Gate',
      area: 'VIT University',
    ),
    'katpadi-railway-station': const Stop(
      id: 'katpadi-railway-station',
      name: 'Katpadi Railway Station',
      area: 'Katpadi',
    ),
  };

  Ticket ticket({
    required String id,
    bool isDemo = false,
    String origin = 'VIT Main Gate',
    String destination = 'Katpadi Railway Station',
    String bus = 'Bus 18B',
    PassengerType passengerType = PassengerType.general,
  }) {
    return Ticket(
      id: id,
      routeId: 'vit-to-katpadi',
      routeName: 'VIT Main Gate → Katpadi',
      origin: Stop(id: 'o-$id', name: origin, area: 'origin area'),
      destination: Stop(
        id: 'd-$id',
        name: destination,
        area: 'destination area',
      ),
      busId: bus,
      passengerName: 'Passholder',
      passengerType: passengerType,
      fareQuote: FareQuote.fromPaise(
        basePaise: 2500,
        passengerType: passengerType,
        discountPercentage: 0,
      ),
      paymentMethod: PaymentMethod.upi,
      issuedAt: DateTime(2026, 10, 9, 10),
      validUntil: DateTime(2026, 10, 9, 14),
      qrCodeData: 'BUSBUDDY::secret-qr-$id',
      isDemo: isDemo,
    );
  }

  Map<String, Object?> draftWithSlots([
    Map<String, Map<String, Object?>>? overrides,
  ]) {
    final slots = <String, Map<String, Object?>>{
      'origin': {'value': 'vit-main-gate', 'source': 'passenger'},
      'destination': {
        'value': 'katpadi-railway-station',
        'source': 'recentActivity',
      },
      'bus': {'value': 'Bus 18B', 'source': 'appDefault'},
      'passengerName': {'value': 'Pavan', 'source': 'passenger'},
      'passengerType': {'value': 'student', 'source': 'profileDefault'},
      'paymentMethod': {'value': 'UPI', 'source': 'appDefault'},
    };
    overrides?.forEach((key, slot) {
      slots[key] = slot;
    });
    return {'slots': slots};
  }

  BookingContext buildFor({
    required AppSettingsController settings,
    required TicketController ticketController,
    Map<String, Map<String, Object?>>? slotOverrides,
  }) {
    return BookingContextBuilder.build(
      settings: settings,
      repository: _FakeStopRepository(knownStops),
      ticketController: ticketController,
      bookingDraft: draftWithSlots(slotOverrides),
    );
  }

  group('BookingContextBuilder', () {
    test('includesOnlyAllowlistedPersonalContextWhenEnabled', () {
      final settings = AppSettingsController.local();
      settings
        ..updateBookingPersonalization(true)
        ..updatePreferredPassengerName('Pavan')
        ..updateDefaultPassengerType(PassengerType.student)
        ..toggleSavedPlace('vit-main-gate', save: true);
      settings.savedPlaceStopIds = ['vit-main-gate'];
      final controller = TicketController(LocalTicketRepository());
      controller.addTicket(ticket(id: 'TKT-1'));

      final json = buildFor(
        settings: settings,
        ticketController: controller,
      ).toJson();

      expect(json.keys, containsAll(<String>[
        'profile',
        'communication',
        'savedPlaces',
        'recentTrips',
        'draft',
      ]));
      expect(json['profile'], {
        'preferredName': 'Pavan',
        'defaultPassengerType': 'student',
      });
      expect(
        (json['communication'] as Map).keys,
        unorderedEquals(<String>[
          'preferredLanguage',
          'voiceSpeed',
          'voiceConfirmations',
          'textSize',
          'highContrast',
        ]),
      );
      expect(json['savedPlaces'], [
        {'name': 'VIT Main Gate'},
      ]);
      final trips = json['recentTrips'] as List;
      expect(trips, hasLength(1));
      expect(
        (trips.single as Map).keys,
        unorderedEquals(<String>[
          'origin',
          'destination',
          'bus',
          'passengerType',
        ]),
      );
      expect((trips.single as Map)['bus'], 'Bus 18B');
    });

    test('omitsPersonalContextWhenOptedOut', () {
      final settings = AppSettingsController.local();
      // Even with a filled profile and saved places, opting out means the
      // tool response carries nothing but the current draft.
      settings
        ..updatePreferredPassengerName('Pavan')
        ..updateDefaultPassengerType(PassengerType.student)
        ..toggleSavedPlace('vit-main-gate', save: true);
      final controller = TicketController(LocalTicketRepository());
      controller.addTicket(ticket(id: 'TKT-1'));

      final json = buildFor(
        settings: settings,
        ticketController: controller,
      ).toJson();

      expect(json.keys, ['draft']);
      expect(json.containsKey('profile'), isFalse);
      expect(json.containsKey('communication'), isFalse);
      expect(json.containsKey('savedPlaces'), isFalse);
      expect(json.containsKey('recentTrips'), isFalse);
    });

    test('filtersDemoTicketsAndCapsRecentHistoryAtThree', () {
      final settings = AppSettingsController.local()
        ..updateBookingPersonalization(true);
      final controller = TicketController(LocalTicketRepository());
      // addTicket prepends, so the last added is newest-first. Five non-demo
      // tickets first, then two demo tickets that must never surface.
      for (var i = 1; i <= 5; i++) {
        controller.addTicket(
          ticket(id: 'TKT-ND$i', bus: 'Bus ND$i'),
        );
      }
      controller.addTicket(ticket(id: 'TKT-DEMO2', isDemo: true, bus: 'Bus D2'));
      controller.addTicket(ticket(id: 'TKT-DEMO1', isDemo: true, bus: 'Bus D1'));

      final json = buildFor(
        settings: settings,
        ticketController: controller,
      ).toJson();

      final trips = json['recentTrips'] as List;
      expect(trips, hasLength(3));
      expect(
        trips.map((t) => (t as Map)['bus']),
        ['Bus ND5', 'Bus ND4', 'Bus ND3'],
      );
      final encoded = jsonEncode(json);
      expect(encoded.contains('Bus D1'), isFalse);
      expect(encoded.contains('Bus D2'), isFalse);
    });

    test('skipsUnknownSavedStopIds', () {
      final settings = AppSettingsController.local()
        ..updateBookingPersonalization(true)
        ..updatePreferredPassengerName('Pavan');
      settings.savedPlaceStopIds = [
        'stale-stop-id',
        'vit-main-gate',
        'another-gone',
      ];
      final controller = TicketController(LocalTicketRepository());

      final json = buildFor(
        settings: settings,
        ticketController: controller,
      ).toJson();

      expect(json['savedPlaces'], [
        {'name': 'VIT Main Gate'},
      ]);
    });

    test('serializesDraftValuesWithTheirSource', () {
      final settings = AppSettingsController.local();
      final controller = TicketController(LocalTicketRepository());

      final json = buildFor(
        settings: settings,
        ticketController: controller,
        slotOverrides: {
          'origin': {'value': 'katpadi-bus-stand', 'source': 'passenger'},
        },
      ).toJson();

      final slots = (json['draft'] as Map)['slots'] as Map;
      expect(slots['origin'], {'value': 'katpadi-bus-stand', 'source': 'passenger'});
      for (final key in [
        'destination',
        'bus',
        'passengerName',
        'passengerType',
        'paymentMethod',
      ]) {
        expect(slots[key], isMap);
        expect((slots[key] as Map).keys, unorderedEquals(<String>['value', 'source']));
      }
      expect((slots['passengerType'] as Map)['source'], 'profileDefault');
    });

    test('redactsTicketAndSensitiveFields', () {
      final settings = AppSettingsController.local()
        ..updateBookingPersonalization(true)
        ..updatePreferredPassengerName('Pavan');
      final controller = TicketController(LocalTicketRepository());
      controller.addTicket(ticket(id: 'TKT-SECRET-1'));

      // A draft slot carrying an extra (credential-like) key must not survive
      // serialization: only value and source are allowlisted.
      final json = buildFor(
        settings: settings,
        ticketController: controller,
        slotOverrides: {
          'paymentMethod': {
            'value': 'UPI',
            'source': 'passenger',
            'credential': 'upi-pin-1234',
          },
        },
      ).toJson();

      final encoded = jsonEncode(json);
      // No ticket identifiers, QR payloads, fares, or timestamps leak.
      expect(encoded.contains('TKT-SECRET-1'), isFalse);
      expect(encoded.contains('BUSBUDDY::'), isFalse);
      expect(encoded.contains('secret-qr'), isFalse);
      expect(encoded.contains('farePaise'), isFalse);
      expect(encoded.contains('issuedAt'), isFalse);
      // The extra draft key is dropped; the slot keeps value + source only.
      final paymentSlot = ((json['draft'] as Map)['slots'] as Map)['paymentMethod'] as Map;
      expect(paymentSlot.keys, unorderedEquals(<String>['value', 'source']));
      expect(paymentSlot['value'], 'UPI');
      // History summaries carry exactly the four allowlisted fields.
      final trips = json['recentTrips'] as List;
      for (final t in trips) {
        expect(
          (t as Map).keys,
          unorderedEquals(<String>['origin', 'destination', 'bus', 'passengerType']),
        );
      }
    });
  });
}
