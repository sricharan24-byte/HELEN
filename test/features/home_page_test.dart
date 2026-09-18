/// Widget tests for the redesigned task-oriented HomePage matching master design reference.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/core/settings/app_settings_controller.dart';
import 'package:busbuddy/data/datasources/local_transport_data_source.dart';
import 'package:busbuddy/data/repositories/ticket_repository.dart';
import 'package:busbuddy/data/repositories/transport_repository.dart';
import 'package:busbuddy/features/home/home_page.dart';
import 'package:busbuddy/features/journey/journey_controller.dart';
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

void main() {
  setUpAll(stubMapTiles);
  setUp(() {
    AppSettingsController.instance.resetHomeScreenLayout();
  });

  // ── Header & Branding ────────────────────────────────────────────────
  group('Header & Branding', () {
    testWidgets('displays BusBuddy branding logo', (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      expect(find.text('Bus'), findsOneWidget);
      expect(find.text('Buddy'), findsOneWidget);
      expect(find.text('Travel Together, Go Further'), findsOneWidget);
    });

    testWidgets('displays active ticket greeting banner (Image 2)', (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      expect(find.text('Good morning, Pavan!'), findsOneWidget);
      expect(find.text("Here's your journey today."), findsOneWidget);
    });

    testWidgets('displays idle greeting banner & 6 cards when no active ticket (Image 1)', (tester) async {
      final ticketRepo = LocalTicketRepository();
      final ticketController = TicketController(ticketRepo);
      ticketController.cancelActiveTicket();

      await tester.pumpWidget(testApp(ticketController: ticketController));
      await tester.pumpAndSettle();

      expect(find.text('Good morning!'), findsOneWidget);
      expect(find.text('What would you like to do?'), findsOneWidget);
      expect(find.text('No active journey'), findsOneWidget);
    });
  });

  // ── My Journey Card ──────────────────────────────────────────────────
  group('My Journey Card', () {
    testWidgets('shows active journey details and status badge', (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      expect(find.text('My Journey'), findsOneWidget);
      expect(find.text('Bus 18B → Katpadi'), findsOneWidget);
      expect(find.text('On Track'), findsOneWidget);
      expect(find.text('3 stops'), findsOneWidget);
      expect(find.text('6 min'), findsOneWidget);
      expect(find.text('View Journey Details'), findsOneWidget);
    });
  });

  // ── Task Action Cards ────────────────────────────────────────────────
  group('Task Action Cards', () {
    testWidgets('shows 5 task-oriented action cards', (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      expect(find.text('Find a Place'), findsOneWidget);
      expect(find.text('My Tickets'), findsOneWidget);
      expect(find.text('Saved Places', skipOffstage: false), findsOneWidget);
      expect(find.text('Ask BusBuddy', skipOffstage: false), findsOneWidget);
      expect(find.text('Settings', skipOffstage: false), findsWidgets);
    });

    testWidgets('tapping Find a Place opens route search', (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Find a Place'));
      await tester.pumpAndSettle();

      expect(find.text('Where would you like to go?'), findsOneWidget);
    });
  });

  // ── Bottom Navigation Bar ─────────────────────────────────────────────
  group('Bottom Navigation', () {
    testWidgets('bottom navigation bar is removed for clean full-screen layout', (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      expect(find.byType(BottomNavigationBar), findsNothing);
    });
  });
}
