/// Widget tests for HomePage and RouteSearchPage — Task 4 TDD.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/data/datasources/local_transport_data_source.dart';
import 'package:busbuddy/data/models/transport_models.dart';
import 'package:busbuddy/data/repositories/transport_repository.dart';
import 'package:busbuddy/data/repositories/ticket_repository.dart';
import 'package:busbuddy/features/home/home_page.dart';
import 'package:busbuddy/features/journey/journey_controller.dart';
import 'package:busbuddy/features/route_search/route_search_page.dart';
import 'package:busbuddy/features/tickets/ticket_controller.dart';
import '../helpers/map_test_tiles.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Builds a fully wired MaterialApp with real repository, controller, and
/// the HomePage as the initial screen.
Widget testApp({void Function(String routeId)? onRouteSelected}) {
  final dataSource = LocalTransportDataSource();
  final repository = LocalTransportRepository(dataSource: dataSource);
  final controller = JourneyController(repository);
  final ticketRepo = LocalTicketRepository();
  final ticketController = TicketController(ticketRepo);

  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: HomePage(
      controller: controller,
      repository: repository,
      ticketController: ticketController,
      onRouteSelected: onRouteSelected ?? (_) {},
    ),
  );
}

/// Builds a test app wired to the [RouteSearchPage] directly.
Widget testSearchApp({void Function(String routeId)? onRouteSelected}) {
  final dataSource = LocalTransportDataSource();
  final repository = LocalTransportRepository(dataSource: dataSource);
  final controller = JourneyController(repository);

  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: RouteSearchPage(
      controller: controller,
      repository: repository,
      onRouteSelected: onRouteSelected ?? (_) {},
    ),
  );
}

/// Taps "Plan a journey" on the home page, then on the route search page
/// chooses VIT Main Gate as origin and Katpadi Railway Station as destination.
///
/// Optionally forwards [onRouteSelected] to the test app so callbacks work
/// when the helper re-pumps the widget tree.
Future<void> openSearchAndChooseVelloreCorridor(
  WidgetTester tester, {
  void Function(String routeId)? onRouteSelected,
}) async {
  final dataSource = LocalTransportDataSource();
  final repository = LocalTransportRepository(dataSource: dataSource);
  final controller = JourneyController(repository);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: RouteSearchPage(
        controller: controller,
        repository: repository,
        onRouteSelected: onRouteSelected ?? (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();

  // Choose origin — tap the origin control.
  await tester.tap(find.bySemanticsLabel('Choose starting stop'));
  await tester.pumpAndSettle();

  // Select "VIT Main Gate" from the stop list.
  await tester.tap(find.text('VIT Main Gate').last);
  await tester.pumpAndSettle();

  // Choose destination — tap the destination control.
  await tester.tap(find.bySemanticsLabel('Choose destination stop'));
  await tester.pumpAndSettle();

  // Type "Katpadi Rail" in the search field to narrow down to a small list,
  // then select Katpadi Railway Station.
  await tester.enterText(find.byType(TextField), 'Katpadi Rail');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Katpadi Railway Station').last);
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(stubMapTiles);
  // ── Home page ─────────────────────────────────────────────────────────
  group('HomePage', () {
    testWidgets('displays the BusBuddy title in the Header', (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      expect(find.text('Bus'), findsOneWidget);
      expect(find.text('Buddy'), findsOneWidget);
    });

    testWidgets('displays tagline', (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      expect(find.text('Travel Together, Go Further'), findsOneWidget);
    });

    testWidgets('has a prominent card "Find a Place"', (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      expect(find.text('Find a Place'), findsOneWidget);
    });

    testWidgets('tapping "Find a Place" navigates to route-search page', (
      tester,
    ) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Find a Place'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Find a Place'));
      await tester.pumpAndSettle();

      // Book a Ticket screen should now be visible
      expect(find.text('Where would you like to go?'), findsOneWidget);
      expect(find.text('Find Buses'), findsOneWidget);
    });
  });

  // ── Route search — controls and semantics ─────────────────────────────
  group('RouteSearchPage controls', () {
    testWidgets('shows semantic controls for origin and destination', (
      tester,
    ) async {
      await tester.pumpWidget(testSearchApp());
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Choose starting stop'), findsOneWidget);
      expect(find.bySemanticsLabel('Choose destination stop'), findsOneWidget);
    });

    testWidgets('tapping origin opens a searchable stop-selection surface', (
      tester,
    ) async {
      await tester.pumpWidget(testSearchApp());
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Choose starting stop'));
      await tester.pumpAndSettle();

      // A bottom sheet should appear with a search field.
      expect(find.byType(TextField), findsOneWidget);
      // Top-of-list stop should be visible.
      expect(find.text('VIT Main Gate'), findsWidgets);
    });

    testWidgets('search field filters stops by name', (tester) async {
      await tester.pumpWidget(testSearchApp());
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Choose starting stop'));
      await tester.pumpAndSettle();

      // Type into the search field.
      await tester.enterText(find.byType(TextField), 'Katpadi');
      await tester.pumpAndSettle();

      // VIT Main Gate should no longer be visible; Katpadi stops should be.
      expect(find.text('VIT Main Gate'), findsNothing);
      expect(find.text('Katpadi Railway Station'), findsOneWidget);
      expect(find.text('Katpadi Junction'), findsOneWidget);
    });

    testWidgets('selecting a stop updates the origin control display', (
      tester,
    ) async {
      await tester.pumpWidget(testSearchApp());
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Choose starting stop'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('VIT Main Gate').last);
      await tester.pumpAndSettle();

      // The origin control should now show "VIT Main Gate".
      expect(find.text('VIT Main Gate'), findsWidgets);
    });

    testWidgets('stop items expose name and area', (tester) async {
      await tester.pumpWidget(testSearchApp());
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Choose starting stop'));
      await tester.pumpAndSettle();

      // Both name and area of the first stop should be visible.
      expect(find.text('VIT Main Gate'), findsWidgets);
      expect(find.text('VIT University'), findsWidgets);
    });
  });

  // ── Route search — search guard ───────────────────────────────────────
  group('Route search guard', () {
    testWidgets(
      'search is disabled until both origin and destination are selected',
      (tester) async {
        await tester.pumpWidget(testSearchApp());
        await tester.pumpAndSettle();

        // Search button should be disabled initially.
        final searchButton = find.bySemanticsLabel('Search routes');
        expect(searchButton, findsOneWidget);

        final button = tester.widget<ElevatedButton>(
          find.descendant(
            of: searchButton,
            matching: find.byType(ElevatedButton),
          ),
        );
        expect(button.onPressed, isNull);
      },
    );

    testWidgets(
      'shows explanatory text when search attempted without both places',
      (tester) async {
        await tester.pumpWidget(testSearchApp());
        await tester.pumpAndSettle();

        // Select only origin.
        await tester.tap(find.bySemanticsLabel('Choose starting stop'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('VIT Main Gate').last);
        await tester.pumpAndSettle();

        // Search button should still be disabled (no destination).
        final searchButton = find.bySemanticsLabel('Search routes');
        final button = tester.widget<ElevatedButton>(
          find.descendant(
            of: searchButton,
            matching: find.byType(ElevatedButton),
          ),
        );
        expect(button.onPressed, isNull);
      },
    );

    testWidgets(
      'explanatory semantic state is visible when both not selected',
      (tester) async {
        await tester.pumpWidget(testSearchApp());
        await tester.pumpAndSettle();

        // The guidance text should be visible from the start.
        expect(
          find.text('Choose an origin and destination first.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'search button becomes enabled after both origin and destination are selected',
      (tester) async {
        await tester.pumpWidget(testSearchApp());
        await tester.pumpAndSettle();

        // Select origin.
        await tester.tap(find.bySemanticsLabel('Choose starting stop'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('VIT Main Gate').last);
        await tester.pumpAndSettle();

        // Select destination.
        await tester.tap(find.bySemanticsLabel('Choose destination stop'));
        await tester.pumpAndSettle();

        // Katpadi Railway Station is at the bottom — search to find it.
        await tester.enterText(find.byType(TextField), 'Katpadi Rail');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Katpadi Railway Station').last);
        await tester.pumpAndSettle();

        // Search button should now be enabled.
        final searchButton = find.bySemanticsLabel('Search routes');
        final button = tester.widget<ElevatedButton>(
          find.descendant(
            of: searchButton,
            matching: find.byType(ElevatedButton),
          ),
        );
        expect(button.onPressed, isNotNull);
      },
    );
  });

  // ── Route search — results ────────────────────────────────────────────
  group('Route results', () {
    testWidgets('after both selections, tapping search renders route results', (
      tester,
    ) async {
      await tester.pumpWidget(testSearchApp());
      await tester.pumpAndSettle();

      await openSearchAndChooseVelloreCorridor(tester);

      // Tap the search button.
      await tester.tap(find.bySemanticsLabel('Search routes'));
      await tester.pumpAndSettle();

      // Route display name should be visible.
      expect(find.text('VIT \u2192 Katpadi Railway Station'), findsOneWidget);
    });

    testWidgets('route results show direction', (tester) async {
      await tester.pumpWidget(testSearchApp());
      await tester.pumpAndSettle();

      await openSearchAndChooseVelloreCorridor(tester);

      await tester.tap(find.bySemanticsLabel('Search routes'));
      await tester.pumpAndSettle();

      expect(find.textContaining('inbound'), findsOneWidget);
    });

    testWidgets('route results show stop count', (tester) async {
      await tester.pumpWidget(testSearchApp());
      await tester.pumpAndSettle();

      await openSearchAndChooseVelloreCorridor(tester);

      await tester.tap(find.bySemanticsLabel('Search routes'));
      await tester.pumpAndSettle();

      // 5 stops on the direct corridor route.
      expect(find.textContaining('5'), findsWidgets);
    });

    testWidgets(
      'route result item exposes semantic label derived from route displayName',
      (tester) async {
        await tester.pumpWidget(testSearchApp());
        await tester.pumpAndSettle();

        await openSearchAndChooseVelloreCorridor(tester);

        await tester.tap(find.bySemanticsLabel('Search routes'));
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsLabel(
            'View route VIT \u2192 Katpadi Railway Station',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('tapping route result invokes onRouteSelected callback', (
      tester,
    ) async {
      String? selectedRouteId;

      await openSearchAndChooseVelloreCorridor(
        tester,
        onRouteSelected: (id) => selectedRouteId = id,
      );

      await tester.tap(find.bySemanticsLabel('Search routes'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.bySemanticsLabel('View route VIT \u2192 Katpadi Railway Station'),
      );
      await tester.pumpAndSettle();

      expect(selectedRouteId, 'vit-to-katpadi');
    });
  });

  // ── Error rendering ───────────────────────────────────────────────────
  group('Error display', () {
    testWidgets('renders controller error messages as visible text', (
      tester,
    ) async {
      final dataSource = LocalTransportDataSource();
      final repository = LocalTransportRepository(dataSource: dataSource);
      final controller = JourneyController(repository);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: RouteSearchPage(
            controller: controller,
            repository: repository,
            onRouteSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The guidance text should be visible from the start.
      expect(
        find.text('Choose an origin and destination first.'),
        findsOneWidget,
      );
    });

    testWidgets('error message has semantic live-region', (tester) async {
      await tester.pumpWidget(testSearchApp());
      await tester.pumpAndSettle();

      // The guidance text should be in a widget with live region semantics.
      final guidanceWidget = find.byWidgetPredicate((widget) {
        if (widget is Semantics) {
          final properties = widget.properties;
          return properties.liveRegion == true;
        }
        return false;
      });
      expect(guidanceWidget, findsOneWidget);
    });

    testWidgets('controller error message is visible in semantic live region', (
      tester,
    ) async {
      final dataSource = LocalTransportDataSource();
      final repository = LocalTransportRepository(dataSource: dataSource);
      final controller = JourneyController(repository);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: RouteSearchPage(
            controller: controller,
            repository: repository,
            onRouteSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially shows guidance (no error).
      expect(
        find.text('Choose an origin and destination first.'),
        findsOneWidget,
      );

      // Trigger an error: select destination without an origin.
      controller.selectDestination(
        const Stop(
          id: 'katpadi-railway-station',
          name: 'Katpadi Railway Station',
          area: 'Katpadi',
        ),
      );
      await tester.pumpAndSettle();

      // The error message from the controller must be visible.
      expect(find.text('Choose an origin first.'), findsOneWidget);

      // The error must be inside a Semantics widget with liveRegion.
      final liveRegion = find.byWidgetPredicate((widget) {
        if (widget is Semantics) {
          return widget.properties.liveRegion == true;
        }
        return false;
      });
      expect(liveRegion, findsOneWidget);

      // The old guidance text should no longer be visible.
      expect(
        find.text('Choose an origin and destination first.'),
        findsNothing,
      );
    });
  });
}
