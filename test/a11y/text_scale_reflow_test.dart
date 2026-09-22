import 'package:flutter/material.dart' hide Route;
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/core/settings/app_settings_controller.dart';
import 'package:busbuddy/data/datasources/local_transport_data_source.dart';
import 'package:busbuddy/data/models/transport_models.dart';
import 'package:busbuddy/data/repositories/ticket_repository.dart';
import 'package:busbuddy/data/repositories/transport_repository.dart';
import 'package:busbuddy/features/ai_assistant/gemini_live_screen.dart';
import 'package:busbuddy/features/journey/journey_controller.dart';
import 'package:busbuddy/features/route_details/route_details_page.dart';
import 'package:busbuddy/features/route_search/route_search_page.dart';
import 'package:busbuddy/features/safety/safety_sharing_page.dart';
import 'package:busbuddy/features/saved/saved_page.dart';
import 'package:busbuddy/features/tickets/booking_checkout_dialog.dart';
import 'package:busbuddy/features/tickets/ticket_controller.dart';
import '../helpers/map_test_tiles.dart';

void main() {
  setUpAll(stubMapTiles);

  late LocalTransportRepository repository;
  late JourneyController journeyController;
  late LocalTicketRepository ticketRepository;
  late TicketController ticketController;
  late Route testRoute;

  setUp(() {
    AppSettingsController.instance.resetToDefaults();
    final dataSource = LocalTransportDataSource();
    repository = LocalTransportRepository(dataSource: dataSource);
    journeyController = JourneyController(repository);
    ticketRepository = LocalTicketRepository();
    ticketController = TicketController(ticketRepository);
    testRoute = repository.allRoutes.first;
  });

  Widget buildScaledContainer({
    required Widget child,
    required double textScaleFactor,
    Size size = const Size(360, 800),
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScaleFactor),
        ),
        child: Material(child: child),
      ),
    );
  }

  group('Astra BUS-P1-05: Responsive Reflow at 200–300% Text Scale', () {
    for (final scale in [2.0, 3.0]) {
      testWidgets('RouteSearchPage reflows cleanly at ${scale * 100}% text scale', (tester) async {
        await tester.pumpWidget(
          buildScaledContainer(
            textScaleFactor: scale,
            child: RouteSearchPage(
              controller: journeyController,
              repository: repository,
              onRouteSelected: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Choose starting stop'), findsOneWidget);
        expect(find.text('Choose destination stop'), findsOneWidget);
        expect(find.text('Search'), findsOneWidget);
      });

      testWidgets('RouteDetailsPage reflows cleanly at ${scale * 100}% text scale', (tester) async {
        journeyController.selectRoute(testRoute);
        await tester.pumpWidget(
          buildScaledContainer(
            textScaleFactor: scale,
            child: RouteDetailsPage(
              controller: journeyController,
              repository: repository,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text(testRoute.displayName), findsOneWidget);
        expect(find.text('Start this journey'), findsOneWidget);
      });

      testWidgets('BookingCheckoutDialog reflows cleanly at ${scale * 100}% text scale', (tester) async {
        final origin = repository.getStop(testRoute.orderedStopIds.first)!;
        final destination = repository.getStop(testRoute.orderedStopIds.last)!;

        await tester.pumpWidget(
          buildScaledContainer(
            textScaleFactor: scale,
            child: BookingCheckoutDialog(
              busId: '18B',
              routeName: testRoute.displayName,
              origin: origin,
              destination: destination,
              baseFare: 25.0,
              onTicketBooked: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Confirm Ticket & Pay'), findsOneWidget);
        expect(find.text('TOTAL FARE'), findsOneWidget);
      });

      testWidgets('SavedPage reflows cleanly at ${scale * 100}% text scale', (tester) async {
        await tester.pumpWidget(
          buildScaledContainer(
            textScaleFactor: scale,
            child: SavedPage(
              ticketController: ticketController,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Saved Passes & Favorites'), findsOneWidget);
      });

      testWidgets('SafetySharingPage reflows cleanly at ${scale * 100}% text scale', (tester) async {
        await tester.pumpWidget(
          buildScaledContainer(
            textScaleFactor: scale,
            child: SafetySharingPage(),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Safety & Emergency Sharing'), findsOneWidget);
        expect(find.text('BROADCAST SOS ALERT NOW'), findsOneWidget);
      });

      testWidgets('GeminiLiveScreen reflows cleanly at ${scale * 100}% text scale', (tester) async {
        await tester.pumpWidget(
          buildScaledContainer(
            textScaleFactor: scale,
            child: GeminiLiveScreen(
              ticketController: ticketController,
              repository: repository,
              journeyController: journeyController,
            ),
          ),
        );
        // The live visualizer runs continuous animation timers, so settle to a
        // bounded number of frames rather than waiting for quiescence.
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(find.text('GEMINI LIVE'), findsWidgets);
        expect(find.text('Where is my bus?'), findsOneWidget);
      });
    }
  });
}
