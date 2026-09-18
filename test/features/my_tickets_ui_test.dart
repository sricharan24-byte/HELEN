import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busbuddy/data/repositories/ticket_repository.dart';
import 'package:busbuddy/features/tickets/ticket_controller.dart';
import 'package:busbuddy/features/tickets/my_tickets_page.dart';

void main() {
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

  testWidgets('MyTicketsPage renders Current Ticket tab with active card & quick actions', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableWidget(MyTicketsPage(ticketController: ticketController)));
    await tester.pumpAndSettle();

    // Verify Title & Tabs
    expect(find.text('My Tickets'), findsOneWidget);
    expect(find.text('Current Ticket'), findsOneWidget);
    expect(find.text('Previous Tickets'), findsOneWidget);

    // Verify Active Ticket Card Details (Image 1)
    expect(find.text('Bus 18B'), findsOneWidget);
    expect(find.text('VIT Main Gate → Katpadi'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('Today, 6 Sep 2025'), findsOneWidget);
    expect(find.text('10:30 AM'), findsOneWidget);
    expect(find.text('₹25'), findsOneWidget);
    expect(find.text('Ticket ID: BB184256'), findsOneWidget);
    expect(find.text('Valid Ticket'), findsOneWidget);

    // Verify Buttons & Quick Actions
    expect(find.text('View Ticket'), findsOneWidget);
    expect(find.text('Share Ticket'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Ask BusBuddy'), findsOneWidget);
  });

  testWidgets('MyTicketsPage tab switching shows Previous Tickets history list', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableWidget(MyTicketsPage(ticketController: ticketController)));
    await tester.pumpAndSettle();

    // Tap Previous Tickets tab
    await tester.tap(find.text('Previous Tickets'));
    await tester.pumpAndSettle();

    // Verify past tickets are listed (Image 3)
    expect(find.text('Bus 12A'), findsAtLeastNWidgets(1));
    expect(find.text('2 Sep 2025, 08:15 AM'), findsOneWidget);
    expect(find.text('Bus 20C'), findsOneWidget);
    expect(find.text('25 Aug 2025, 11:20 AM'), findsOneWidget);
    expect(find.text('Get details about a previous ticket'), findsOneWidget);
  });

  testWidgets('Tapping View Ticket opens TicketDetailsPage with Valid banner & QR Code pass', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestableWidget(MyTicketsPage(ticketController: ticketController)));
    await tester.pumpAndSettle();

    // Tap View Ticket button
    await tester.tap(find.text('View Ticket'));
    await tester.pumpAndSettle();

    // Verify Ticket Details Page UI elements (Image 2)
    expect(find.text('Ticket Details'), findsOneWidget);
    expect(find.text('Valid Ticket'), findsOneWidget);
    expect(find.text('Show this ticket while boarding'), findsOneWidget);
    expect(find.text('Passenger: Pavan K'), findsOneWidget);
    expect(find.text('BB184256'), findsAtLeastNWidgets(1));
    expect(find.text('Scan this QR code while boarding'), findsOneWidget);
    expect(find.text('Important'), findsOneWidget);
  });
}
