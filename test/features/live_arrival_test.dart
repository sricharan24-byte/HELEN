import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/data/datasources/local_transport_data_source.dart';
import 'package:busbuddy/data/models/ticket_model.dart';
import 'package:busbuddy/data/models/transport_models.dart' hide Route;
import 'package:busbuddy/data/models/transport_models.dart' as models;
import 'package:busbuddy/data/repositories/ticket_repository.dart';
import 'package:busbuddy/data/repositories/transport_repository.dart';
import 'package:busbuddy/domain/transit/entities/telemetry_state.dart';
import 'package:busbuddy/features/journey/live_location_screen.dart';
import 'package:busbuddy/features/tickets/ticket_controller.dart';

import '../helpers/map_test_tiles.dart';

/// Destination arrival on the live map.
///
/// The stream ending (or 100% progress) must pop a "Destination Reached"
/// dialog, expire the ticket, show a 10-second "closing in Ns" countdown,
/// and return the passenger to the home page — automatically or via
/// "Back to Home now".
void main() {
  setUpAll(stubMapTiles);

  late LocalTicketRepository ticketRepo;
  late TicketController ticketController;
  late LocalTransportDataSource dataSource;
  late _TerminalTransportRepository repository;

  setUp(() {
    ticketRepo = LocalTicketRepository();
    ticketController = TicketController(ticketRepo);
    dataSource = LocalTransportDataSource();
    repository = _TerminalTransportRepository(dataSource);
  });

  /// Books a live corridor ticket and returns it.
  Ticket bookCorridorTicket() {
    final route = dataSource.allRoutes.firstWhere(
      (r) => r.id == 'vit-to-katpadi',
      orElse: () => dataSource.allRoutes.first,
    );
    return ticketController.bookTicket(
      origin: dataSource.stopById('vit-main-gate')!,
      destination: dataSource.stopById('katpadi-railway-station')!,
      route: route,
      passengerName: 'Pavan K',
    );
  }

  /// First route is a plain home page; the button pushes the live map.
  Widget testApp(Ticket ticket) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () {
                unawaited(Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LiveLocationScreen(
                      ticket: ticket,
                      repository: repository,
                      ticketController: ticketController,
                    ),
                  ),
                ));
              },
              child: const Text('Open live map'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openLiveMap(WidgetTester tester, Ticket ticket) async {
    await tester.pumpWidget(testApp(ticket));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open live map'));
    // Fixed pumps only: the arrival countdown is a periodic timer, so
    // pumpAndSettle would never settle once it starts.
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('live map destination arrival', () {
    testWidgets('shows the arrival dialog and expires the ticket', (
      tester,
    ) async {
      final ticket = bookCorridorTicket();
      await openLiveMap(tester, ticket);

      expect(find.text('Destination Reached'), findsOneWidget);
      expect(
        find.textContaining('Your ticket has expired.'),
        findsOneWidget,
      );
      expect(find.textContaining('Live map closing in'), findsOneWidget);

      final stored = ticketController.tickets.firstWhere(
        (t) => t.id == ticket.id,
      );
      expect(stored.status, TicketStatus.expired);
      expect(ticketController.activeTicket, isNull);
    });

    testWidgets('countdown ticks down, then returns home automatically', (
      tester,
    ) async {
      final ticket = bookCorridorTicket();
      await openLiveMap(tester, ticket);

      expect(find.textContaining('closing in 10 sec'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      expect(find.textContaining('closing in 6 sec'), findsOneWidget);

      // Past the 10-second mark with margin (the countdown starts a fraction
      // after t=0 on a post-frame callback). The countdown timer is cancelled
      // by the return itself, so settling here is safe.
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();

      // The countdown starts a fraction after t=0 (post-frame dialog), so
      // allow a margin past the 10-second mark.
      await tester.pump(const Duration(seconds: 7));
      await tester.pump();

      // Dialog and live map are gone; the first (home) route is showing.
      expect(find.text('Destination Reached'), findsNothing);
      expect(find.text('Live Location'), findsNothing);
      expect(find.text('Open live map'), findsOneWidget);
    });

    testWidgets('"Back to Home now" returns immediately', (tester) async {
      final ticket = bookCorridorTicket();
      await openLiveMap(tester, ticket);

      expect(find.text('Destination Reached'), findsOneWidget);
      await tester.tap(find.text('Back to Home now'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Destination Reached'), findsNothing);
      expect(find.text('Open live map'), findsOneWidget);
      final stored = ticketController.tickets.firstWhere(
        (t) => t.id == ticket.id,
      );
      expect(stored.status, TicketStatus.expired);
    });
  });
}

/// Repository whose bus stream emits one terminal position and closes,
/// simulating destination arrival without waiting out the demo clock.
class _TerminalTransportRepository implements TransportRepository {
  _TerminalTransportRepository(this._dataSource);

  final LocalTransportDataSource _dataSource;

  @override
  List<Stop> findStops(String query) => _dataSource.searchStops(query);

  @override
  List<models.Route> findRoutes({
    required String originId,
    required String destinationId,
  }) {
    final results = <models.Route>[];
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
  List<models.Route> get allRoutes => _dataSource.allRoutes;

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
