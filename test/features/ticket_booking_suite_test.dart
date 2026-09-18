import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busbuddy/data/repositories/ticket_repository.dart';
import 'package:busbuddy/features/tickets/ticket_controller.dart';
import 'package:busbuddy/features/tickets/ticket_booking_suite_page.dart';
import '../helpers/map_test_tiles.dart';

void main() {
  setUpAll(stubMapTiles);
  late LocalTicketRepository ticketRepo;
  late TicketController ticketController;

  setUp(() {
    ticketRepo = LocalTicketRepository();
    ticketController = TicketController(ticketRepo);
  });

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  testWidgets('TicketBookingSuitePage renders Step 1 (1. Booking) form & shortcuts', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestableWidget(TicketBookingSuitePage(ticketController: ticketController, showTopPrototypeTabs: true)));
    await tester.pumpAndSettle();

    // Verify Prototype Header Tabs when enabled
    expect(find.text('1. Booking'), findsOneWidget);
    expect(find.text('2. Results'), findsOneWidget);
    expect(find.text('3. Active Trip'), findsOneWidget);

    // Verify Title & Subtitle (Image 1)
    expect(find.text('Where would you like to go?'), findsOneWidget);
    expect(find.textContaining('Select your starting point and destination'), findsOneWidget);

    // Verify Input Cards
    expect(find.text('FROM'), findsOneWidget);
    expect(find.text('Current Location'), findsOneWidget);
    expect(find.text('TO'), findsOneWidget);
    expect(find.text('DATE'), findsOneWidget);
    expect(find.textContaining('Today,'), findsOneWidget);

    // Verify Primary Action & Shortcuts
    expect(find.text('Find Buses'), findsOneWidget);
    expect(find.text('Saved Places'), findsOneWidget);
    expect(find.text('Recent Trips'), findsOneWidget);
    expect(find.text('Ask BusBuddy'), findsOneWidget);
    expect(find.text('Speak your destination'), findsOneWidget);
  });

  testWidgets('Tapping Find Buses navigates to Step 2 (2. Results) showing available buses', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestableWidget(TicketBookingSuitePage(ticketController: ticketController)));
    await tester.pumpAndSettle();

    // Tap Find Buses button
    await tester.tap(find.text('Find Buses'));
    await tester.pumpAndSettle();

    // Verify Step 2 UI Elements (Image 2)
    expect(find.text('Available Buses'), findsOneWidget);
    expect(find.text('VIT Main Gate'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);

    // Verify Bus Cards (18B, 12A, 20C)
    expect(find.text('18B'), findsOneWidget);
    expect(find.text('Arriving Soon'), findsOneWidget);
    expect(find.text('4 minutes away'), findsOneWidget);
    expect(find.text('Select This Bus >'), findsOneWidget);

    expect(find.text('12A'), findsOneWidget);
    expect(find.text('In 12 min'), findsOneWidget);
    expect(find.text('12 minutes away'), findsOneWidget);

    expect(find.text('20C'), findsOneWidget);
    expect(find.text('In 18 min'), findsOneWidget);
    expect(find.text('18 minutes away'), findsOneWidget);
  });

  testWidgets('Selecting a bus navigates to Step 3 (3. Active Trip) showing journey tracker', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestableWidget(
      TicketBookingSuitePage(
        ticketController: ticketController,
        initialStepIndex: 1,
      ),
    ));
    await tester.pumpAndSettle();

    // Select Bus 18B to open checkout modal
    await tester.tap(find.text('Select This Bus >'));
    await tester.pumpAndSettle();

    // Verify checkout modal bottom sheet appears with passenger and payment options
    expect(find.text('Confirm Ticket & Pay'), findsOneWidget);
    expect(find.text('General'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('Senior'), findsOneWidget);

    // Tap Pay & Issue button to complete booking
    await tester.tap(find.textContaining('& Issue'));
    await tester.pumpAndSettle();

    // Verify Step 3 UI Elements (Image 3)
    expect(find.text('My Journey'), findsOneWidget);
    expect(find.text('You are going to'), findsOneWidget);
    expect(find.text('Katpadi Railway Station'), findsOneWidget);

    // Verify Tracker Metrics & Timeline
    expect(find.text('Bus 18B'), findsOneWidget);
    expect(find.text('On Track'), findsOneWidget);
    expect(find.text('Stops Remaining'), findsOneWidget);
    expect(find.textContaining('min'), findsWidgets);
    expect(find.text('Estimated Arrival'), findsOneWidget);

    // Verify Next Stop banner & Journey Assistant
    expect(find.textContaining('Old Katpadi'), findsAtLeastNWidgets(1));
    expect(find.text('Journey Assistant'), findsOneWidget);
    expect(find.text('Announcements are ON'), findsOneWidget);

    // Verify Quick Actions Grid
    expect(find.text('View Live Map'), findsOneWidget);
    expect(find.text('Repeat Last Instruction'), findsOneWidget);
    expect(find.text('Emergency Help'), findsOneWidget);
    expect(find.text('Need anything? Just ask.'), findsOneWidget);
  });
}
