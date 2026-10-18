import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/core/theme/app_theme.dart';
import 'package:busbuddy/data/datasources/local_transport_data_source.dart';
import 'package:busbuddy/data/repositories/ticket_repository.dart';
import 'package:busbuddy/data/repositories/transport_repository.dart';
import 'package:busbuddy/features/journey/journey_controller.dart';
import 'package:busbuddy/features/navigation/app_navigation_shell.dart';
import 'package:busbuddy/features/navigation/more_page.dart';
import 'package:busbuddy/features/settings/settings_page.dart';
import 'package:busbuddy/features/tickets/my_tickets_page.dart';
import 'package:busbuddy/features/tickets/ticket_booking_suite_page.dart';
import 'package:busbuddy/features/tickets/ticket_controller.dart';

import '../helpers/map_test_tiles.dart';

Future<void> pumpShell(WidgetTester tester, {TextScaler? textScaler}) async {
  final repository = LocalTransportRepository(
    dataSource: LocalTransportDataSource(),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      builder: textScaler == null
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
      home: AppNavigationShell(
        controller: JourneyController(repository),
        repository: repository,
        ticketController: TicketController(LocalTicketRepository()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(stubMapTiles);

  testWidgets('shell shows four destinations and builds each on first visit', (
    tester,
  ) async {
    await pumpShell(tester);

    for (final label in ['Home', 'Plan', 'Tickets', 'More']) {
      expect(find.text(label), findsOneWidget);
    }

    // Destinations are built lazily — nothing but Home exists up front.
    expect(find.byType(TicketBookingSuitePage), findsNothing);
    expect(find.byType(MyTicketsPage), findsNothing);
    expect(find.byType(MorePage), findsNothing);

    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    expect(find.byType(TicketBookingSuitePage), findsOneWidget);

    await tester.tap(find.text('Tickets'));
    await tester.pumpAndSettle();
    expect(find.byType(MyTicketsPage), findsOneWidget);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.byType(MorePage), findsOneWidget);
    expect(find.text('Safety & Contacts'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(MorePage), matching: find.text('Settings')),
      findsOneWidget,
    );
  });

  testWidgets('switching destinations preserves in-progress state', (
    tester,
  ) async {
    await pumpShell(tester);

    await tester.tap(find.text('Tickets'));
    await tester.pumpAndSettle();
    final ticketsState = tester.state(find.byType(MyTicketsPage));

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tickets'));
    await tester.pumpAndSettle();

    expect(tester.state(find.byType(MyTicketsPage)), same(ticketsState));
  });

  testWidgets('back pops the destination stack, then returns to Home', (
    tester,
  ) async {
    await pumpShell(tester);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(MorePage), matching: find.text('Settings')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);

    // First back: pop the detail page inside the More destination.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsNothing);
    expect(find.byType(MorePage), findsOneWidget);

    // Second back: More root cannot pop, so the shell returns to Home.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
  });

  testWidgets('shell renders at 360dp with 300% text scaling without layout '
      'errors', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpShell(tester, textScaler: const TextScaler.linear(3.0));

    expect(find.byType(NavigationBar), findsOneWidget);
    // Walk every destination at this scale; any overflow or clip the shell
    // composition caused fails the test through the error reporter.
    for (final label in ['Plan', 'Tickets', 'More']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
  });
}
