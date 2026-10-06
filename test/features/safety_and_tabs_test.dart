import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/data/datasources/local_transport_data_source.dart';
import 'package:busbuddy/data/repositories/ticket_repository.dart';
import 'package:busbuddy/data/repositories/transport_repository.dart';
import 'package:busbuddy/features/alerts/alerts_page.dart';
import 'package:busbuddy/features/home/home_page.dart';
import 'package:busbuddy/features/journey/journey_controller.dart';
import 'package:busbuddy/features/safety/safety_sharing_page.dart';
import 'package:busbuddy/features/settings/settings_page.dart';
import 'package:busbuddy/features/tickets/my_tickets_page.dart';
import 'package:busbuddy/features/tickets/ticket_controller.dart';

void main() {
  group('Safety & Emergency Sharing Page', () {
    testWidgets('renders SOS button and trusted contacts', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const SafetySharingPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Safety & Emergency Sharing'), findsOneWidget);
      expect(find.text('BROADCAST SOS ALERT NOW'), findsOneWidget);
      expect(find.text('TRUSTED EMERGENCY CONTACTS'), findsOneWidget);
      expect(find.textContaining('Parent / Guardian'), findsOneWidget);
    });
  });

  group('Bottom Navigation Tabs', () {
    testWidgets('AlertsPage renders live alerts', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const AlertsPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Live Corridor Alerts'), findsOneWidget);
      expect(find.textContaining('Bus TN-23-BUS-42 On Time'), findsOneWidget);
    });

    testWidgets(
      'MyTicketsPage renders the active pass (SavedPage was removed)',
      (tester) async {
        final ticketRepo = LocalTicketRepository();
        final ticketController = TicketController(ticketRepo);
        // Fresh installs start ticketless: book the pass under test.
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

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: MyTicketsPage(ticketController: ticketController),
          ),
        );
        await tester.pumpAndSettle();

        // The deleted SavedPage showed this same ticket history; My Tickets is
        // the only passbook now.
        expect(find.text('My Tickets'), findsOneWidget);
        expect(find.text('ACTIVE'), findsOneWidget);
      },
    );

    testWidgets('SettingsPage renders accessibility switches', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const SettingsPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Settings & Preferences'), findsOneWidget);
      expect(find.text('Accessibility Settings'), findsOneWidget);
      expect(find.text('Personalization Settings'), findsOneWidget);
    });

    testWidgets('HomePage opens SettingsPage via Settings action card', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final dataSource = LocalTransportDataSource();
      final repository = LocalTransportRepository(dataSource: dataSource);
      final controller = JourneyController(repository);
      final ticketRepo = LocalTicketRepository();
      final ticketController = TicketController(ticketRepo);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: HomePage(
            controller: controller,
            repository: repository,
            ticketController: ticketController,
            onRouteSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Settings card
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      expect(find.text('Settings & Preferences'), findsOneWidget);
    });
  });
}
