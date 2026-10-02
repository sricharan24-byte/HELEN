import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/data/datasources/local_transport_data_source.dart';
import 'package:busbuddy/data/models/ticket_model.dart';
import 'package:busbuddy/data/repositories/ticket_repository.dart';
import 'package:busbuddy/data/repositories/transport_repository.dart';
import 'package:busbuddy/features/tickets/live_location_screen.dart';
import '../helpers/map_test_tiles.dart';

void main() {
  setUpAll(stubMapTiles);
  testWidgets('LiveLocationScreen renders map, vehicle stats, and emergency share button', (tester) async {
    final dataSource = LocalTransportDataSource();
    final repository = LocalTransportRepository(dataSource: dataSource);
    final ticketRepo = LocalTicketRepository();

    final ticket = ticketRepo.bookTicket(
      origin: dataSource.allStops.first,
      destination: dataSource.allStops.last,
      route: dataSource.allRoutes.first,
      passengerName: 'Pavan',
      passengerType: PassengerType.general,
      paymentMethod: PaymentMethod.upi,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: LiveLocationScreen(
          ticket: ticket,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify app bar title
    expect(find.textContaining('Live Location'), findsWidgets);

    // Verify vehicle stats metrics labels
    expect(find.text('SPEED'), findsOneWidget);
    expect(find.text('ETA TO NEXT'), findsOneWidget);
    expect(find.text('NEXT STOP'), findsOneWidget);

    // Verify driver info card
    expect(find.textContaining('Driver: M. Ramanathan'), findsOneWidget);

    // Verify emergency safety share button
    expect(find.text('Share Live Location with Emergency Contacts'), findsOneWidget);
  });

  testWidgets('LiveLocationScreen shows refresh action and live-data timestamp', (tester) async {
    final dataSource = LocalTransportDataSource();
    final repository = LocalTransportRepository(dataSource: dataSource);
    final ticketRepo = LocalTicketRepository();

    final ticket = ticketRepo.bookTicket(
      origin: dataSource.allStops.first,
      destination: dataSource.allStops.last,
      route: dataSource.allRoutes.first,
      passengerName: 'Pavan',
      passengerType: PassengerType.general,
      paymentMethod: PaymentMethod.upi,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: LiveLocationScreen(
          ticket: ticket,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Refresh action is labeled for screen readers and meets touch targets.
    expect(find.byTooltip('Refresh live location'), findsOneWidget);

    // Stream ticks quickly: either live Updated time or waiting placeholder.
    final updated = find.textContaining('Updated ');
    final waiting = find.text('Waiting for live data…');
    expect(
      updated.evaluate().isNotEmpty || waiting.evaluate().isNotEmpty,
      isTrue,
      reason: 'Expected an Updated timestamp or the waiting placeholder',
    );
  });
}
