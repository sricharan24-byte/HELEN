import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busbuddy/data/datasources/local_transport_data_source.dart';
import 'package:busbuddy/data/models/ticket_model.dart';
import 'package:busbuddy/data/repositories/ticket_repository.dart';
import 'package:busbuddy/features/tickets/ticket_controller.dart';
import 'package:busbuddy/features/tickets/my_tickets_page.dart';

void main() {
  late LocalTicketRepository ticketRepo;
  late TicketController ticketController;

  setUp(() {
    ticketRepo = LocalTicketRepository();
    ticketController = TicketController(ticketRepo);
    // Fresh installs start ticketless: book the ticket under test.
    final dataSource = LocalTransportDataSource();
    final route = dataSource.allRoutes.firstWhere(
      (r) => r.id == 'vit-to-katpadi',
      orElse: () => dataSource.allRoutes.first,
    );
    ticketController.bookTicket(
      origin: dataSource.stopById('vit-main-gate')!,
      destination: dataSource.stopById('katpadi-railway-station')!,
      route: route,
      passengerName: 'Pavan K',
    );
  });

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(home: child);
  }

  testWidgets(
    'MyTicketsPage renders Current Ticket tab with active card & quick actions',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(MyTicketsPage(ticketController: ticketController)),
      );
      await tester.pumpAndSettle();

      final active = ticketController.activeTicket!;
      final now = DateTime.now();
      final expectedDate =
          'Today, ${now.day} ${_monthName(now.month)} ${now.year}';

      // Verify Title & Tabs
      expect(find.text('My Tickets'), findsOneWidget);
      expect(find.text('Current Ticket'), findsOneWidget);
      expect(find.text('Previous Tickets'), findsOneWidget);

      // Verify Active Ticket Card Details for the booked ticket
      expect(find.text(active.busId), findsOneWidget);
      expect(
        find.text('${active.origin.name} → ${active.destination.name}'),
        findsOneWidget,
      );
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text(expectedDate), findsOneWidget);
      expect(find.text('₹20'), findsOneWidget);
      expect(find.text('Ticket ID: ${active.id}'), findsOneWidget);
      expect(find.text('Valid Ticket'), findsOneWidget);

      // Verify Buttons & Quick Actions
      expect(find.text('View Ticket'), findsOneWidget);
      expect(find.text('Cancel Ticket'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Share Ticket'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Share Ticket'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
      expect(find.text('Ask BusBuddy'), findsOneWidget);
    },
  );

  testWidgets(
    'Cancel Ticket button cancels the active ticket with confirmation',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(MyTicketsPage(ticketController: ticketController)),
      );
      await tester.pumpAndSettle();

      final ticketId = ticketController.activeTicket!.id;
      await tester.ensureVisible(find.text('Cancel Ticket'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel Ticket'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel this ticket?'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Cancel Ticket'));
      await tester.pumpAndSettle();

      final stored = ticketController.tickets.firstWhere(
        (t) => t.id == ticketId,
      );
      expect(stored.status, TicketStatus.cancelled);
    },
  );

  testWidgets(
    'MyTicketsPage tab switching shows Previous Tickets history list',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(MyTicketsPage(ticketController: ticketController)),
      );
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
    },
  );

  testWidgets(
    'Tapping View Ticket opens TicketDetailsPage with Valid banner & QR Code pass',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildTestableWidget(MyTicketsPage(ticketController: ticketController)),
      );
      await tester.pumpAndSettle();

      final active = ticketController.activeTicket!;

      // Tap View Ticket button
      await tester.tap(find.text('View Ticket'));
      await tester.pumpAndSettle();

      // Verify Ticket Details Page UI elements
      expect(find.text('Ticket Details'), findsOneWidget);
      expect(find.text('Valid Ticket'), findsOneWidget);
      expect(find.text('Show this ticket while boarding'), findsOneWidget);
      expect(find.text('Passenger: Pavan K'), findsOneWidget);
      expect(find.text(active.id), findsAtLeastNWidgets(1));
      expect(find.text('Scan this QR code while boarding'), findsOneWidget);
      expect(find.text('Important'), findsOneWidget);
    },
  );
}

String _monthName(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[month - 1];
}
