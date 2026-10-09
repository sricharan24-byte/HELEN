import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/core/a11y/announcement_coordinator.dart';
import 'package:busbuddy/data/datasources/local_transport_data_source.dart';
import 'package:busbuddy/data/models/ticket_model.dart';
import 'package:busbuddy/data/repositories/ticket_repository.dart';
import 'package:busbuddy/data/repositories/transport_repository.dart';
import 'package:busbuddy/features/journey/live_location_screen.dart';
import 'package:busbuddy/features/tickets/ticket_controller.dart';
import '../helpers/map_test_tiles.dart';

void main() {
  setUpAll(stubMapTiles);
  // AnnouncementCoordinator is a process-wide singleton with a duplicate
  // debounce: reset before every test so one test's announcements never
  // suppress another's.
  setUp(AnnouncementCoordinator.instance.reset);
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
    expect(find.text('NEXT STOP'), findsNWidgets(2));

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

  testWidgets('LiveLocationScreen renders small map window, seat details, corridor stops, and End Trip', (tester) async {
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

    // Small map window header and expand button
    expect(find.text('LIVE MAP WINDOW'), findsOneWidget);
    expect(find.text('Expand Map'), findsWidgets);

    // Seat details card
    expect(find.text('SEAT DETAILS'), findsOneWidget);
    expect(find.textContaining('Seat '), findsWidgets);
    expect(find.text('PASSENGER'), findsOneWidget);
    expect(find.text('SEAT TYPE'), findsOneWidget);
    expect(find.text('Pavan'), findsOneWidget);

    // Corridor stops timeline
    expect(find.text('CORRIDOR STOPS'), findsOneWidget);
    expect(find.textContaining('stops'), findsWidgets);

    // End trip feature button
    expect(find.text('End Trip Now'), findsOneWidget);
  });

  testWidgets('LiveLocationScreen toggles map from small window to full screen and collapses back', (tester) async {
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

    // In window mode
    expect(find.text('LIVE MAP WINDOW'), findsOneWidget);
    expect(find.text('SEAT DETAILS'), findsOneWidget);

    // Tap Expand button to go full screen
    await tester.tap(find.text('Expand Map').first);
    await tester.pumpAndSettle();

    // Now in full screen mode: Exit button is visible, seat details hidden
    expect(find.text('Exit Full Screen'), findsOneWidget);
    expect(find.textContaining('Full Screen Map'), findsOneWidget);
    expect(find.text('SEAT DETAILS'), findsNothing);

    // Tap Exit Full Screen to return to window mode
    await tester.tap(find.text('Exit Full Screen'));
    await tester.pumpAndSettle();

    // Back to window mode
    expect(find.text('LIVE MAP WINDOW'), findsOneWidget);
    expect(find.text('SEAT DETAILS'), findsOneWidget);
  });

  testWidgets('LiveLocationScreen End Trip button opens confirmation and completes trip', (tester) async {
    final dataSource = LocalTransportDataSource();
    final repository = LocalTransportRepository(dataSource: dataSource);
    final ticketRepo = LocalTicketRepository();
    final ticketController = TicketController(ticketRepo);

    final ticket = ticketRepo.bookTicket(
      origin: dataSource.allStops.first,
      destination: dataSource.allStops.last,
      route: dataSource.allRoutes.first,
      passengerName: 'Pavan',
      passengerType: PassengerType.general,
      paymentMethod: PaymentMethod.upi,
    );
    ticketController.addTicket(ticket);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: LiveLocationScreen(
          ticket: ticket,
          repository: repository,
          ticketController: ticketController,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap End Trip Now button (scroll into view: content is taller than
    // the 800x600 test viewport).
    await tester.ensureVisible(find.text('End Trip Now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End Trip Now'));
    await tester.pumpAndSettle();

    // Confirmation dialog is shown
    expect(find.text('End Current Trip?'), findsOneWidget);
    expect(find.text('Continue Trip'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'End Trip'), findsOneWidget);

    // Tap End Trip in the confirmation dialog
    await tester.tap(find.widgetWithText(FilledButton, 'End Trip'));
    await tester.pumpAndSettle();

    // Ticket is completed
    expect(ticketRepo.activeTicket?.id, isNot(ticket.id));
  });

  testWidgets('LiveLocationScreen dispatches stop announcements and supports manual audio trigger and mute toggle', (tester) async {
    final announced = <String>[];
    AnnouncementCoordinator.instance.speechSpeaker = announced.add;
    addTearDown(AnnouncementCoordinator.instance.reset);

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

    // Verify stop announcement was dispatched
    expect(
      announced.any((m) => m.contains('Next stop') || m.contains('Arriving at')),
      isTrue,
      reason: 'Should announce initial upcoming stop',
    );

    // Tap speaker icon button on next stop card (scroll into view: the
    // metric card sits below the 800x600 test viewport fold).
    announced.clear();
    final speakerBtn = find.byTooltip('Announce stop aloud');
    expect(speakerBtn, findsOneWidget);
    await tester.ensureVisible(speakerBtn);
    await tester.pumpAndSettle();
    await tester.tap(speakerBtn);
    await tester.pump();
    expect(
      announced.any((m) => m.contains('Next stop') || m.contains('Arriving at')),
      isTrue,
      reason: 'Should announce when speaker button is pressed',
    );

    // Mute announcements
    final muteBtn = find.byTooltip('Mute voice announcements');
    expect(muteBtn, findsOneWidget);
    await tester.tap(muteBtn);
    await tester.pump();

    // Verify button flipped to unmute
    expect(find.byTooltip('Unmute voice announcements'), findsOneWidget);
  });
}
