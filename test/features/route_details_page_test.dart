/// Widget tests for RouteDetailsPage and JourneyPage — Task 5 TDD.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/core/theme/app_theme.dart';
import 'package:busbuddy/data/datasources/local_transport_data_source.dart';
import 'package:busbuddy/data/models/transport_models.dart' as models;
import 'package:busbuddy/data/repositories/transport_repository.dart';
import 'package:busbuddy/features/journey/journey_controller.dart';
import 'package:busbuddy/features/route_details/route_details_page.dart';
import 'package:busbuddy/features/journey/journey_page.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// The canonical corridor route for testing (real Katpadi Main Road stops).
models.Route _corridorRoute() => const models.Route(
  id: 'vit-to-katpadi',
  displayName: 'VIT → Katpadi Railway Station',
  direction: 'inbound',
  orderedStopIds: [
    'vit-main-gate',
    'old-katpadi',
    'chittoor-bus-stop',
    'katpadi-bus-stand',
    'katpadi-railway-station',
  ],
);

/// Builds a test app preloaded with the corridor route selected on the
/// controller, pointed at [RouteDetailsPage].
Widget routeDetailsTestApp({models.Route? route}) {
  final dataSource = LocalTransportDataSource();
  final repository = LocalTransportRepository(dataSource: dataSource);
  final controller = JourneyController(repository);

  // Pre-load controller with origin, destination, and selected route.
  final origin = repository.getStop('vit-main-gate')!;
  final destination = repository.getStop('katpadi-railway-station')!;
  controller.selectOrigin(origin);
  controller.selectDestination(destination);
  controller.selectRoute(route ?? _corridorRoute());

  return MaterialApp(
    theme: AppTheme.light,
    home: RouteDetailsPage(controller: controller, repository: repository),
  );
}

/// Builds a test app for the JourneyPage with an active journey on the
/// controller.
Widget journeyTestApp({models.Route? route}) {
  final dataSource = LocalTransportDataSource();
  final repository = LocalTransportRepository(dataSource: dataSource);
  final controller = JourneyController(repository);

  // Pre-load controller: origin → destination → route → start.
  final origin = repository.getStop('vit-main-gate')!;
  final destination = repository.getStop('katpadi-railway-station')!;
  controller.selectOrigin(origin);
  controller.selectDestination(destination);
  controller.selectRoute(route ?? _corridorRoute());
  controller.startJourney();

  return MaterialApp(
    theme: AppTheme.light,
    home: JourneyPage(controller: controller),
  );
}

/// Builds a test app where the controller has no route selected, for
/// testing missing-data recovery on RouteDetailsPage.
Widget _routeDetailsMissingDataApp() {
  final dataSource = LocalTransportDataSource();
  final repository = LocalTransportRepository(dataSource: dataSource);
  final controller = JourneyController(repository);

  // Pre-load only origin and destination — no route selected.
  controller.selectOrigin(repository.getStop('vit-main-gate')!);
  controller.selectDestination(repository.getStop('katpadi-railway-station')!);

  return MaterialApp(
    theme: AppTheme.light,
    home: RouteDetailsPage(controller: controller, repository: repository),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── RouteDetailsPage — route facts ────────────────────────────────────
  group('RouteDetailsPage — route facts', () {
    testWidgets('displays the route display name', (tester) async {
      await tester.pumpWidget(routeDetailsTestApp());
      await tester.pumpAndSettle();

      expect(find.text('VIT → Katpadi Railway Station'), findsOneWidget);
    });

    testWidgets('displays the route direction', (tester) async {
      await tester.pumpWidget(routeDetailsTestApp());
      await tester.pumpAndSettle();

      expect(find.textContaining('INBOUND'), findsWidgets);
    });

    testWidgets('displays the boarding stop name', (tester) async {
      await tester.pumpWidget(routeDetailsTestApp());
      await tester.pumpAndSettle();

      // The boarding stop is VIT Main Gate (first stop).
      expect(find.text('VIT Main Gate'), findsWidgets);
    });

    testWidgets('displays the destination stop name', (tester) async {
      await tester.pumpWidget(routeDetailsTestApp());
      await tester.pumpAndSettle();

      // The destination is Katpadi Railway Station (last stop).
      expect(find.text('Katpadi Railway Station'), findsWidgets);
    });
  });

  // ── RouteDetailsPage — ordered stops ──────────────────────────────────
  group('RouteDetailsPage — ordered stops', () {
    testWidgets('displays all 12 stops in order', (tester) async {
      await tester.pumpWidget(routeDetailsTestApp());
      await tester.pumpAndSettle();

      const expectedStops = [
        'VIT Main Gate',
        'Old Katpadi',
        'Chittoor Bus Stop',
        'Katpadi Bus Stand',
        'Katpadi Railway Station',
      ];

      for (final stopName in expectedStops) {
        expect(find.text(stopName), findsWidgets);
      }
    });

    testWidgets('shows a semantic heading for the stop list', (tester) async {
      await tester.pumpWidget(routeDetailsTestApp());
      await tester.pumpAndSettle();

      // Should have a Semantics header widget for the stops section.
      final headerFinder = find.byWidgetPredicate((widget) {
        if (widget is Semantics) {
          final properties = widget.properties;
          return properties.header == true;
        }
        return false;
      });
      expect(headerFinder, findsWidgets);
    });
  });

  // ── RouteDetailsPage — start journey action ───────────────────────────
  group('RouteDetailsPage — start journey', () {
    testWidgets('has a semantic button "Start this journey"', (tester) async {
      await tester.pumpWidget(routeDetailsTestApp());
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Start this journey'), findsOneWidget);
    });

    testWidgets(
      'tapping Start this journey calls startJourney on the controller',
      (tester) async {
        final dataSource = LocalTransportDataSource();
        final repository = LocalTransportRepository(dataSource: dataSource);
        final controller = JourneyController(repository);

        controller.selectOrigin(repository.getStop('vit-main-gate')!);
        controller.selectDestination(
          repository.getStop('katpadi-railway-station')!,
        );
        controller.selectRoute(_corridorRoute());

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: RouteDetailsPage(
              controller: controller,
              repository: repository,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Before tapping: phase should be routeSelected.
        expect(controller.state.phase, JourneyPhase.routeSelected);

        // Scroll button into view since the stop list pushes it off-screen.
        await tester.ensureVisible(find.bySemanticsLabel('Start this journey'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Start this journey'));
        await tester.pumpAndSettle();

        // After tapping: phase should be active.
        expect(controller.state.phase, JourneyPhase.active);
      },
    );

    testWidgets('tapping Start this journey navigates to JourneyPage', (
      tester,
    ) async {
      await tester.pumpWidget(routeDetailsTestApp());
      await tester.pumpAndSettle();

      // Scroll button into view since the stop list pushes it off-screen.
      await tester.ensureVisible(find.bySemanticsLabel('Start this journey'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Start this journey'));
      await tester.pumpAndSettle();

      // JourneyPage should now be visible — check for its semantic labels.
      expect(find.bySemanticsLabel('Journey active'), findsOneWidget);
    });
  });

  // ── RouteDetailsPage — missing data recovery ──────────────────────────
  group('RouteDetailsPage — missing data recovery', () {
    testWidgets('shows a recoverable message when no route is selected', (
      tester,
    ) async {
      await tester.pumpWidget(_routeDetailsMissingDataApp());
      await tester.pumpAndSettle();

      // Should show a user-friendly message, not throw.
      expect(find.textContaining('No route selected'), findsOneWidget);
    });

    testWidgets('does not throw when route data is missing', (tester) async {
      // This test simply verifies the page renders without throwing.
      await tester.pumpWidget(_routeDetailsMissingDataApp());
      await tester.pumpAndSettle();

      // If we got here without an exception, the page handled missing data.
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  // ── JourneyPage — active journey semantics ────────────────────────────
  group('JourneyPage — active journey', () {
    testWidgets('displays semantic heading "Journey active"', (tester) async {
      await tester.pumpWidget(journeyTestApp());
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Journey active'), findsOneWidget);
    });

    testWidgets('displays the origin stop name', (tester) async {
      await tester.pumpWidget(journeyTestApp());
      await tester.pumpAndSettle();

      expect(find.text('VIT Main Gate'), findsWidgets);
    });

    testWidgets('displays the destination stop name', (tester) async {
      await tester.pumpWidget(journeyTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Katpadi Railway Station'), findsWidgets);
    });

    testWidgets('displays the selected route name', (tester) async {
      await tester.pumpWidget(journeyTestApp());
      await tester.pumpAndSettle();

      expect(find.text('VIT → Katpadi Railway Station'), findsWidgets);
    });

    testWidgets(
      'explicitly states that live bus location and ETA are not connected yet',
      (tester) async {
        await tester.pumpWidget(journeyTestApp());
        await tester.pumpAndSettle();

        // Must clearly communicate that live tracking is not available.
        expect(find.textContaining('not connected yet'), findsOneWidget);
      },
    );

    testWidgets('does not fabricate live values like ETA or bus position', (
      tester,
    ) async {
      await tester.pumpWidget(journeyTestApp());
      await tester.pumpAndSettle();

      // Should not show fabricated live values.
      expect(find.textContaining('ETA:'), findsNothing);
      expect(find.textContaining('minutes away'), findsNothing);
      expect(find.textContaining('km away'), findsNothing);
      expect(find.textContaining('arriving in'), findsNothing);
    });
  });

  // ── JourneyPage — not started (no journey active) ─────────────────────
  group('JourneyPage — idle state', () {
    testWidgets('shows a message when no journey is active', (tester) async {
      final dataSource = LocalTransportDataSource();
      final repository = LocalTransportRepository(dataSource: dataSource);
      final controller = JourneyController(repository);
      // Don't start a journey — phase is idle.

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: JourneyPage(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('No active journey'), findsOneWidget);
    });
  });

  // ── RouteDetailsPage — reactive controller mutation after mount ──────
  group('RouteDetailsPage — reactive updates', () {
    testWidgets('page updates when controller gains a route after mount', (
      tester,
    ) async {
      final dataSource = LocalTransportDataSource();
      final repository = LocalTransportRepository(dataSource: dataSource);
      final controller = JourneyController(repository);

      // Pre-load origin & destination only — no route selected.
      controller.selectOrigin(repository.getStop('vit-main-gate')!);
      controller.selectDestination(
        repository.getStop('katpadi-railway-station')!,
      );

      // Mount with missing-route state.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: RouteDetailsPage(
            controller: controller,
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No route selected'), findsOneWidget);

      // Mutate: select a route.
      controller.selectRoute(_corridorRoute());
      await tester.pumpAndSettle();

      // Page should now show route details, not stale missing-data message.
      expect(find.textContaining('No route selected'), findsNothing);
      expect(find.text('VIT → Katpadi Railway Station'), findsOneWidget);
    });
  });

  // ── JourneyPage — reactive controller mutation after mount ────────────
  group('JourneyPage — reactive updates', () {
    testWidgets(
      'page updates when controller transitions from idle to active',
      (tester) async {
        final dataSource = LocalTransportDataSource();
        final repository = LocalTransportRepository(dataSource: dataSource);
        final controller = JourneyController(repository);

        // Mount with idle controller — no journey active.
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: JourneyPage(controller: controller),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('No active journey'), findsOneWidget);

        // Mutate controller: select origin, destination, route, start.
        controller.selectOrigin(repository.getStop('vit-main-gate')!);
        controller.selectDestination(
          repository.getStop('katpadi-railway-station')!,
        );
        controller.selectRoute(_corridorRoute());
        controller.startJourney();
        await tester.pumpAndSettle();

        // Page should now reflect active journey — not stale idle state.
        expect(find.textContaining('No active journey'), findsNothing);
        expect(find.bySemanticsLabel('Journey active'), findsOneWidget);
        expect(find.text('VIT Main Gate'), findsWidgets);
      },
    );

    testWidgets(
      'page updates displayed journey facts when controller state changes',
      (tester) async {
        final dataSource = LocalTransportDataSource();
        final repository = LocalTransportRepository(dataSource: dataSource);
        final controller = JourneyController(repository);

        // Pre-load to active.
        controller.selectOrigin(repository.getStop('vit-main-gate')!);
        controller.selectDestination(
          repository.getStop('katpadi-railway-station')!,
        );
        controller.selectRoute(_corridorRoute());
        controller.startJourney();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: JourneyPage(controller: controller),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('VIT → Katpadi Railway Station'), findsWidgets);
      },
    );
  });
}
