import 'package:flutter/material.dart' hide Route;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/core/di/service_locator.dart';
import 'package:busbuddy/data/datasources/local_transport_data_source.dart';
import 'package:busbuddy/data/models/ticket_model.dart';
import 'package:busbuddy/data/models/transport_models.dart';
import 'package:busbuddy/data/repositories/ticket_repository.dart';
import 'package:busbuddy/data/repositories/transport_repository.dart';
import 'package:busbuddy/domain/transit/entities/telemetry_state.dart';
import 'package:busbuddy/features/journey/journey_controller.dart';
import 'package:busbuddy/features/tickets/ticket_booking_suite_page.dart';
import 'package:busbuddy/features/tickets/ticket_controller.dart';

import '../helpers/map_test_tiles.dart';

/// Trip lifecycle: journey starts on purchase, bus terminates at the
/// destination, arrival completes the ticket, and cancellation is honored.
void main() {
  setUpAll(stubMapTiles);

  group('Ticket journey lifecycle (repository + controller)', () {
    late LocalTransportDataSource dataSource;
    late LocalTicketRepository ticketRepo;
    late TicketController ticketController;

    setUp(() {
      dataSource = LocalTransportDataSource();
      ticketRepo = LocalTicketRepository();
      ticketController = TicketController(ticketRepo);
    });

    Ticket bookCorridorTicket() {
      final route = dataSource.allRoutes.firstWhere(
        (r) => r.id == 'vit-to-katpadi',
        orElse: () => dataSource.allRoutes.first,
      );
      final origin = dataSource.stopById('vit-main-gate')!;
      final destination = dataSource.stopById('katpadi-railway-station')!;
      return ticketRepo.bookTicket(
        origin: origin,
        destination: destination,
        route: route,
        passengerName: 'Rider',
        passengerType: PassengerType.general,
        paymentMethod: PaymentMethod.upi,
      );
    }

    test('completeTicket expires the active ticket on journey completion', () {
      final ticket = bookCorridorTicket();
      expect(ticketRepo.activeTicket?.id, ticket.id);

      ticketRepo.completeTicket(ticket.id);

      // The completed ticket leaves the active slot (a seeded demo ticket
      // remains active underneath — production booking puts the new ticket
      // at index 0, which is what activeTicket resolves).
      expect(ticketRepo.activeTicket?.id, isNot(ticket.id));
      final stored = ticketRepo.allTickets.firstWhere((t) => t.id == ticket.id);
      expect(stored.status, TicketStatus.expired);
    });

    test('completeTicket is a no-op for unknown ids and terminal tickets', () {
      final ticket = bookCorridorTicket();
      expect(
        () => ticketRepo.completeTicket('BB-DOES-NOT-EXIST'),
        returnsNormally,
      );
      ticketRepo.completeTicket(ticket.id);
      // Second completion must not throw or regress the terminal state.
      ticketRepo.completeTicket(ticket.id, reason: 'duplicate arrival');
      final stored = ticketRepo.allTickets.firstWhere((t) => t.id == ticket.id);
      expect(stored.status, TicketStatus.expired);
    });

    test('completeActiveTrip completes and cancelActiveTicket cancels', () {
      final first = bookCorridorTicket();
      ticketController.completeActiveTrip();
      expect(ticketController.activeTicket?.id, isNot(first.id));
      final completed = ticketController.tickets.firstWhere(
        (t) => t.id == first.id,
      );
      expect(completed.status, TicketStatus.expired);

      final ticket = bookCorridorTicket();
      ticketController.cancelActiveTicket();
      expect(ticketController.activeTicket?.id, isNot(ticket.id));
      final stored = ticketController.tickets.firstWhere(
        (t) => t.id == ticket.id,
      );
      expect(stored.status, TicketStatus.cancelled);
    });

    test(
      'stopJourney tears down engines and the next stream restarts',
      () async {
        final repo = LocalTransportRepository(dataSource: dataSource);
        final first = await repo
            .streamBusLocation('18B', 'vit-to-katpadi')
            .first;
        expect(first.busId, '18B');

        await repo.stopJourney('18B', 'vit-to-katpadi');
        // Unknown journeys are safe no-ops.
        await repo.stopJourney('NOPE', 'no-route');

        final restarted = await repo
            .streamBusLocation('18B', 'vit-to-katpadi')
            .first;
        expect(restarted.busId, '18B');
        await repo.dispose();
      },
    );
  });

  group('TicketBookingSuitePage trip actions', () {
    late LocalTicketRepository ticketRepo;
    late TicketController ticketController;

    setUp(() {
      ticketRepo = LocalTicketRepository();
      ticketController = TicketController(ticketRepo);
    });

    Future<void> bookAndReachActiveTrip(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: TicketBookingSuitePage(ticketController: ticketController),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Find Buses'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select This Bus >'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('& Issue'));
      await tester.pumpAndSettle();

      expect(find.text('My Journey'), findsOneWidget);
    }

    testWidgets('buying a ticket starts the journey session', (tester) async {
      final journeyController = JourneyController(
        AppServiceLocator.instance.transportRepository,
      );
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: TicketBookingSuitePage(
            ticketController: ticketController,
            journeyController: journeyController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Find Buses'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select This Bus >'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('& Issue'));
      await tester.pumpAndSettle();

      expect(find.text('My Journey'), findsOneWidget);
      expect(journeyController.state.phase, JourneyPhase.active);
      expect(
        journeyController.state.activeSession?.destination.name,
        'Katpadi Railway Station',
      );
      journeyController.dispose();
    });

    testWidgets('End Trip Early expires the ticket and resets the flow', (
      tester,
    ) async {
      await bookAndReachActiveTrip(tester);
      final ticketId = ticketController.activeTicket!.id;

      await tester.ensureVisible(find.text('End Trip Early'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('End Trip Early'));
      await tester.pumpAndSettle();

      expect(find.text('End trip early?'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'End Trip'));
      await tester.pumpAndSettle();

      final stored = ticketController.tickets.firstWhere(
        (t) => t.id == ticketId,
      );
      expect(stored.status, TicketStatus.expired);
      expect(find.text('Where would you like to go?'), findsOneWidget);
    });

    testWidgets('Cancel Ticket cancels with confirmation', (tester) async {
      await bookAndReachActiveTrip(tester);
      final ticketId = ticketController.activeTicket!.id;

      await tester.ensureVisible(find.text('Cancel Ticket'));
      await tester.pumpAndSettle();
      // The card button (dialog not open yet, so exactly one match).
      await tester.tap(find.text('Cancel Ticket'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel this ticket?'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Cancel Ticket'));
      await tester.pumpAndSettle();

      final stored = ticketController.tickets.firstWhere(
        (t) => t.id == ticketId,
      );
      expect(stored.status, TicketStatus.cancelled);
      expect(find.text('Where would you like to go?'), findsOneWidget);
    });

    testWidgets('bus marker moves as live positions stream in', (tester) async {
      await bookAndReachActiveTrip(tester);

      Marker busMarker() {
        final layer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
        return layer.markers.firstWhere((m) => m.width == 44);
      }

      // The embedded Active Trip map renders the live bus icon (regression:
      // the map used to receive no positions, so no bus ever appeared).
      final before = busMarker().point;
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      final after = busMarker().point;

      expect(
        after.latitude != before.latitude ||
            after.longitude != before.longitude,
        isTrue,
        reason:
            'bus marker should advance along the route, '
            'was $before still $after after 5s',
      );
    });

    testWidgets('arrival banner appears when the bus stream terminates', (
      tester,
    ) async {
      final dataSource = LocalTransportDataSource();
      AppServiceLocator.instance.overrideForTesting(
        transportRepo: _TerminalTransportRepository(dataSource),
      );
      addTearDown(AppServiceLocator.instance.resetForTesting);

      await bookAndReachActiveTrip(tester);
      final ticketId = ticketController.activeTicket!.id;

      expect(find.textContaining('Reached the destination'), findsOneWidget);
      expect(find.text('End Trip'), findsOneWidget);

      await tester.ensureVisible(find.text('End Trip'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('End Trip'));
      await tester.pumpAndSettle();
      final dialogConfirm = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('End Trip'),
      );
      expect(dialogConfirm, findsOneWidget);
      await tester.tap(dialogConfirm);
      await tester.pumpAndSettle();

      final stored = ticketController.tickets.firstWhere(
        (t) => t.id == ticketId,
      );
      expect(stored.status, TicketStatus.expired);
    });
  });
}

/// Fake repository whose bus stream emits a single terminal position and
/// closes, simulating destination arrival without waiting out the demo clock.
class _TerminalTransportRepository implements TransportRepository {
  _TerminalTransportRepository(this._dataSource);

  final LocalTransportDataSource _dataSource;

  @override
  List<Stop> findStops(String query) => _dataSource.searchStops(query);

  @override
  List<Route> findRoutes({
    required String originId,
    required String destinationId,
  }) {
    final results = <Route>[];
    for (final route in _dataSource.allRoutes) {
      if (route.stopsBetween(originId, destinationId).isNotEmpty) {
        results.add(route);
      }
    }
    return results;
  }

  @override
  Stop? getStop(String stopId) => _dataSource.stopById(stopId);

  @override
  List<Route> get allRoutes => _dataSource.allRoutes;

  @override
  Stream<BusLocation> streamBusLocation(
    String busId,
    String routeId, {
    String? originStopId,
    String? destinationStopId,
  }) {
    final terminal = BusLocation(
      busId: busId,
      routeId: routeId,
      latitude: 12.972,
      longitude: 79.136,
      speedKmh: 0,
      nextStopId: 'katpadi-railway-station',
      nextStopName: 'Katpadi Railway Station',
      etaMinutes: 0,
      timestamp: DateTime.now(),
      progressPercentage: 1.0,
    );
    return Stream<BusLocation>.fromIterable([terminal]);
  }

  @override
  Stream<TelemetrySnapshot> streamTelemetry(String busId, String routeId) {
    return const Stream.empty();
  }

  @override
  Future<void> stopJourney(String busId, String routeId) async {}
}
