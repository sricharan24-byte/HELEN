import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/core/theme/app_theme.dart';
import 'package:busbuddy/data/datasources/local_transport_data_source.dart';
import 'package:busbuddy/data/repositories/ticket_repository.dart';
import 'package:busbuddy/data/repositories/transport_repository.dart';
import 'package:busbuddy/features/journey/journey_controller.dart';
import 'package:busbuddy/features/home/home_page.dart';
import 'package:busbuddy/features/navigation/app_navigation_shell.dart';
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

  testWidgets('shell removes bottom navigation and top More option', (
    tester,
  ) async {
    await pumpShell(tester);

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byTooltip('More'), findsNothing);
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

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byTooltip('More'), findsNothing);
  });
}
