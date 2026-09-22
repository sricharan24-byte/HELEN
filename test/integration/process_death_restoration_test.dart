import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:busbuddy/data/datasources/local_json_store.dart';
import 'package:busbuddy/data/datasources/local_transport_data_source.dart';
import 'package:busbuddy/data/models/ticket_model.dart';
import 'package:busbuddy/data/models/transport_models.dart';
import 'package:busbuddy/data/repositories/ticket_repository.dart';
import 'package:busbuddy/data/repositories/transport_repository.dart';
import 'package:busbuddy/features/journey/journey_controller.dart';
import 'package:busbuddy/features/tickets/ticket_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BUS-P1-10 Process Death Restoration Integration Tests', () {
    test('Simulating process death restores active tickets with exact data', () async {
      final store = await LocalJsonStore.open();

      // --- Process A: Original App Process ---
      final repoA = LocalTicketRepository();
      final controllerA = TicketController(repoA);
      await controllerA.hydrate(store);

      const origin = Stop(id: 'vit-main-gate', name: 'VIT Main Gate', area: 'VIT University');
      const destination = Stop(id: 'katpadi-railway-station', name: 'Katpadi Railway Station', area: 'Katpadi');
      const route = Route(
        id: 'vit-to-katpadi',
        displayName: 'VIT Main Gate → Katpadi',
        direction: 'Northbound',
        orderedStopIds: ['vit-main-gate', 'chittoor-bus-stop', 'katpadi-railway-station'],
      );

      final booked = controllerA.bookTicket(
        origin: origin,
        destination: destination,
        route: route,
        passengerName: 'Astra Tester',
        passengerType: PassengerType.student,
        paymentMethod: PaymentMethod.upi,
      );

      expect(controllerA.hasActiveTicket, isTrue);
      expect(controllerA.activeTicket!.id, equals(booked.id));
      await store.flush();

      // --- Process Death: Simulate OS killing the process and discarding memory ---
      controllerA.dispose();

      // --- Process B: Re-instantiating fresh app and controllers ---
      final repoB = LocalTicketRepository();
      final controllerB = TicketController(repoB);
      await controllerB.hydrate(store);

      expect(controllerB.hasActiveTicket, isTrue);
      final restoredTicket = controllerB.activeTicket!;
      expect(restoredTicket.id, equals(booked.id));
      expect(restoredTicket.passengerName, equals('Astra Tester'));
      expect(restoredTicket.origin.id, equals('vit-main-gate'));
      expect(restoredTicket.destination.id, equals('katpadi-railway-station'));
      expect(restoredTicket.fareQuote.finalPaise, equals(booked.fareQuote.finalPaise));
      expect(restoredTicket.status, equals(TicketStatus.active));
    });

    test('Expired tickets cleanly transition status on restoration without becoming active', () async {
      final store = await LocalJsonStore.open();

      // Seed a ticket that expired 1 hour ago
      final pastTime = DateTime.now().subtract(const Duration(hours: 1));
      final expiredTicket = Ticket(
        id: 'BB-EXPIRED-999',
        routeId: 'vit-to-katpadi',
        routeName: 'VIT → Katpadi',
        origin: const Stop(id: 'vit-main-gate', name: 'VIT Main Gate', area: 'VIT'),
        destination: const Stop(id: 'katpadi', name: 'Katpadi', area: 'Katpadi'),
        busId: 'Bus 18B',
        passengerName: 'Pavan',
        passengerType: PassengerType.general,
        fareQuote: FareQuote.fromPaise(
          basePaise: 1500,
          passengerType: PassengerType.general,
          discountPercentage: 0,
        ),
        paymentMethod: PaymentMethod.upi,
        issuedAt: pastTime.subtract(const Duration(hours: 3)),
        validUntil: pastTime,
        status: TicketStatus.active, // Stored as active prior to process death
        qrCodeData: 'BB-EXPIRED-999',
      );

      await store.write(LocalTicketRepository.storageKey, [expiredTicket.toJson()]);
      await store.flush();

      // Relaunch app process
      final repo = LocalTicketRepository();
      final controller = TicketController(repo);
      await controller.hydrate(store);

      // Active ticket should be null because validity elapsed
      expect(controller.hasActiveTicket, isFalse);
      expect(controller.activeTicket, isNull);

      // The ticket in history should now have expired status
      final found = controller.tickets.firstWhere((t) => t.id == 'BB-EXPIRED-999');
      expect(found.status, equals(TicketStatus.expired));
    });

    test('Simulating process death restores active journey session accurately', () async {
      final store = await LocalJsonStore.open();

      // --- Process A: User starts a journey ---
      final dataSourceA = LocalTransportDataSource();
      final transportRepoA = LocalTransportRepository(dataSource: dataSourceA);
      final journeyCtrlA = JourneyController(transportRepoA);
      await journeyCtrlA.hydrate(store);

      const origin = Stop(id: 'vit-main-gate', name: 'VIT Main Gate', area: 'VIT University');
      const destination = Stop(id: 'katpadi-railway-station', name: 'Katpadi Railway Station', area: 'Katpadi');
      final routes = transportRepoA.findRoutes(originId: origin.id, destinationId: destination.id);
      expect(routes, isNotEmpty);

      journeyCtrlA.selectOrigin(origin);
      journeyCtrlA.selectDestination(destination);
      journeyCtrlA.selectRoute(routes.first);
      journeyCtrlA.startJourney(busId: 'Bus 18B');

      expect(journeyCtrlA.state.phase, equals(JourneyPhase.active));
      expect(journeyCtrlA.state.activeSession, isNotNull);
      expect(journeyCtrlA.state.activeSession!.busId, equals('Bus 18B'));
      await store.flush();

      // --- Process Death: Simulate memory wipe ---
      journeyCtrlA.dispose();
      await transportRepoA.dispose();

      // --- Process B: Re-launch after process kill ---
      final dataSourceB = LocalTransportDataSource();
      final transportRepoB = LocalTransportRepository(dataSource: dataSourceB);
      final journeyCtrlB = JourneyController(transportRepoB);
      await journeyCtrlB.hydrate(store);

      expect(journeyCtrlB.state.phase, equals(JourneyPhase.active));
      expect(journeyCtrlB.state.origin?.id, equals('vit-main-gate'));
      expect(journeyCtrlB.state.destination?.id, equals('katpadi-railway-station'));
      expect(journeyCtrlB.state.selectedRoute?.id, equals(routes.first.id));
      expect(journeyCtrlB.state.activeSession, isNotNull);
      expect(journeyCtrlB.state.activeSession!.busId, equals('Bus 18B'));
      expect(journeyCtrlB.state.activeSession!.isCompleted, isFalse);

      // Successfully complete journey
      await journeyCtrlB.completeJourney();
      expect(journeyCtrlB.state.phase, equals(JourneyPhase.idle));
      await store.flush();

      // Relaunching again after completed journey yields idle
      final journeyCtrlC = JourneyController(transportRepoB);
      await journeyCtrlC.hydrate(store);
      expect(journeyCtrlC.state.phase, equals(JourneyPhase.idle));

      await transportRepoB.dispose();
    });
  });
}
