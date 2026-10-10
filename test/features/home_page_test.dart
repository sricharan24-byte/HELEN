/// Widget tests for the redesigned task-oriented HomePage matching master design reference.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/core/settings/app_settings_controller.dart';
import 'package:busbuddy/data/datasources/local_transport_data_source.dart';
import 'package:busbuddy/data/repositories/ticket_repository.dart';
import 'package:busbuddy/data/repositories/transport_repository.dart';
import 'package:busbuddy/domain/ticketing/entities/fare_engine.dart';
import 'package:busbuddy/domain/ticketing/entities/ticket.dart';
import 'package:busbuddy/features/home/home_page.dart';
import 'package:busbuddy/features/journey/journey_controller.dart';
import 'package:busbuddy/features/journey/live_location_screen.dart';
import 'package:busbuddy/features/tickets/ticket_controller.dart';
import '../helpers/map_test_tiles.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Widget testApp({
  void Function(String routeId)? onRouteSelected,
  TicketController? ticketController,
}) {
  final dataSource = LocalTransportDataSource();
  final repository = LocalTransportRepository(dataSource: dataSource);
  final controller = JourneyController(repository);

  final ticketRepo = LocalTicketRepository();
  final tController = ticketController ?? TicketController(ticketRepo);

  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: HomePage(
      controller: controller,
      repository: repository,
      ticketController: tController,
      onRouteSelected: onRouteSelected ?? (_) {},
    ),
  );
}

/// Fresh installs start ticketless, so tests needing an active ticket book
/// one explicitly instead of relying on a pre-booked seed.
/// The caller owns the returned controller: dispose it in a tearDown so the
/// expiry timer never outlives the test.
TicketController bookCorridorTicketController() {
  final dataSource = LocalTransportDataSource();
  final route = dataSource.allRoutes.firstWhere(
    (r) => r.id == 'vit-to-katpadi',
    orElse: () => dataSource.allRoutes.first,
  );
  final ticketController = TicketController(LocalTicketRepository());
  ticketController.bookTicket(
    origin: dataSource.stopById('vit-main-gate')!,
    destination: dataSource.stopById('katpadi-railway-station')!,
    route: route,
    passengerName: 'Pavan K',
  );
  return ticketController;
}

void main() {
  setUpAll(stubMapTiles);
  setUp(AppSettingsController.instance.resetHomeScreenLayout);

  // ── Header & Branding ────────────────────────────────────────────────
  group('Header & Branding', () {
    testWidgets('displays BusBuddy branding logo', (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      expect(find.text('Bus'), findsOneWidget);
      expect(find.text('Buddy'), findsOneWidget);
      expect(find.text('Travel Together, Go Further'), findsOneWidget);
    });

    testWidgets('displays active ticket greeting banner (Image 2)', (
      tester,
    ) async {
      final ticketController = bookCorridorTicketController();
      await tester.pumpWidget(testApp(ticketController: ticketController));
      await tester.pumpAndSettle();

      expect(find.text('Good morning, Pavan!'), findsOneWidget);
      expect(find.text("Here's your journey today."), findsOneWidget);
      // The booking armed an expiry Timer: dispose before the body ends
      // (testWidgets verifies timers before teardowns run).
      ticketController.dispose();
    });

    testWidgets(
      'displays idle greeting banner when no active ticket (Image 1)',
      (tester) async {
        final ticketRepo = LocalTicketRepository();
        final ticketController = TicketController(ticketRepo);
        ticketController.cancelActiveTicket();

        await tester.pumpWidget(testApp(ticketController: ticketController));
        await tester.pumpAndSettle();

        expect(find.text('Good morning!'), findsOneWidget);
        expect(find.text('What would you like to do?'), findsOneWidget);
        // 'My Journey' option was removed from the home screen options.
        expect(find.text('No active journey'), findsNothing);
      },
    );
  });

  // ── My Journey Card ──────────────────────────────────────────────────
  group('My Journey Card', () {
    testWidgets('shows active journey details and status badge', (
      tester,
    ) async {
      final ticketController = bookCorridorTicketController();
      await tester.pumpWidget(testApp(ticketController: ticketController));
      await tester.pumpAndSettle();

      final active = ticketController.activeTicket!;
      expect(find.text('My Journey'), findsOneWidget);
      expect(
        find.text('${active.busId} → ${active.destination.name}'),
        findsOneWidget,
      );
      expect(find.text('On Track'), findsOneWidget);
      expect(find.text('3 stops'), findsOneWidget);
      expect(find.text('6 min'), findsOneWidget);
      expect(find.text('View Journey Details'), findsOneWidget);
      // The booking armed an expiry Timer: dispose before the body ends
      // (testWidgets verifies timers before teardowns run).
      ticketController.dispose();
    });

    testWidgets('tapping View Journey Details opens LiveLocationScreen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final ticketController = bookCorridorTicketController();
      await tester.pumpWidget(testApp(ticketController: ticketController));
      await tester.pumpAndSettle();

      await tester.tap(find.text('View Journey Details'));
      await tester.pumpAndSettle();

      expect(find.byType(LiveLocationScreen), findsOneWidget);
      // The booking armed an expiry Timer: dispose before the body ends
      // (testWidgets verifies timers before teardowns run).
      ticketController.dispose();
    });

    testWidgets('hides active journey card immediately when ticket completes', (
      tester,
    ) async {
      final ticketController = bookCorridorTicketController();
      await tester.pumpWidget(testApp(ticketController: ticketController));
      await tester.pumpAndSettle();

      expect(find.text('My Journey'), findsOneWidget);

      ticketController.completeActiveTrip(reason: 'Reached destination');
      await tester.pumpAndSettle();

      expect(find.text('My Journey'), findsNothing);
      expect(find.text('Good morning!'), findsOneWidget);
      expect(find.text('What would you like to do?'), findsOneWidget);
    });

    testWidgets(
      'hides active journey card when multiple bookings occurred and trip completes',
      (tester) async {
        final ticketController = bookCorridorTicketController();
        // Second booking
        final dataSource = LocalTransportDataSource();
        final route = dataSource.allRoutes.first;
        ticketController.bookTicket(
          origin: dataSource.stopById('vit-main-gate')!,
          destination: dataSource.stopById('katpadi-railway-station')!,
          route: route,
          passengerName: 'Pavan K',
        );

        await tester.pumpWidget(testApp(ticketController: ticketController));
        await tester.pumpAndSettle();

        expect(find.text('My Journey'), findsOneWidget);

        ticketController.completeActiveTrip(reason: 'Trip ended');
        await tester.pumpAndSettle();

        expect(find.text('My Journey'), findsNothing);
        expect(ticketController.hasActiveTicket, isFalse);
      },
    );

    testWidgets(
      'hides active journey card when ticket validity window has elapsed',
      (tester) async {
        final dataSource = LocalTransportDataSource();
        final route = dataSource.allRoutes.first;
        final ticketRepo = LocalTicketRepository();
        final ticketController = TicketController(ticketRepo);

        final pastTicket = Ticket(
          id: 'BB-EXPIRED-TEST',
          routeId: route.id,
          routeName: route.displayName,
          origin: dataSource.stopById('vit-main-gate')!,
          destination: dataSource.stopById('katpadi-railway-station')!,
          busId: '18B',
          passengerName: 'Pavan',
          passengerType: PassengerType.general,
          fareQuote: FareEngine.calculateCorridorFare(PassengerType.general),
          paymentMethod: PaymentMethod.upi,
          issuedAt: DateTime.now().subtract(const Duration(hours: 5)),
          validUntil: DateTime.now().subtract(const Duration(minutes: 1)),
          status: TicketStatus.active,
          qrCodeData: 'TEST',
        );
        ticketRepo.addTicket(pastTicket);

        await tester.pumpWidget(testApp(ticketController: ticketController));
        await tester.pumpAndSettle();

        expect(find.text('My Journey'), findsNothing);
        expect(find.text('Good morning!'), findsOneWidget);
        expect(ticketController.hasActiveTicket, isFalse);
      },
    );
  });

  // ── Task Action Cards ────────────────────────────────────────────────
  group('Task Action Cards', () {
    testWidgets('shows 4 task-oriented action cards', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 2000);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      expect(find.text('Find a Place'), findsOneWidget);
      expect(find.text('My Tickets'), findsOneWidget);
      // Saved places left the home page for one-tap chips in the pickers.
      expect(find.text('Saved Places'), findsNothing);
      expect(find.text('Ask BusBuddy'), findsOneWidget);
      expect(find.text('Settings'), findsWidgets);
    });

    testWidgets('tapping Find a Place opens route search', (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Find a Place'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Find a Place'));
      await tester.pumpAndSettle();

      expect(find.text('Where would you like to go?'), findsOneWidget);
    });
  });

  // ── Bottom Navigation Bar ─────────────────────────────────────────────
  group('Bottom Navigation', () {
    testWidgets(
      'bottom navigation bar is removed for clean full-screen layout',
      (tester) async {
        await tester.pumpWidget(testApp());
        await tester.pumpAndSettle();

        expect(find.byType(BottomNavigationBar), findsNothing);
      },
    );
  });
}
