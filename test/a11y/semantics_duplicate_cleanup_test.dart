import 'package:flutter/material.dart' hide Route;
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/core/a11y/accessible_button.dart';
import 'package:busbuddy/core/a11y/map_text_alternative_widget.dart';
import 'package:busbuddy/data/models/transport_models.dart';
import '../helpers/map_test_tiles.dart';

void main() {
  setUpAll(stubMapTiles);

  group('Astra BUS-P1-06: Clean Semantics & Duplicate Elimination Tests', () {
    testWidgets('MapTextAlternativeWidget has headingLevel 2 and atomic row semantics', (tester) async {
      final route = Route(
        id: 'route-test',
        displayName: 'VIT to Katpadi',
        orderedStopIds: ['stop-1', 'stop-2'],
        direction: 'North',
      );

      final busLoc = BusLocation(
        busId: 'BUS-01',
        routeId: 'route-test',
        latitude: 12.97,
        longitude: 79.15,
        speedKmh: 35.0,
        nextStopId: 'stop-2',
        nextStopName: 'Katpadi Station',
        etaMinutes: 8,
        timestamp: DateTime.now(),
        progressPercentage: 50,
      );

      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapTextAlternativeWidget(
              route: route,
              busLocation: busLoc,
              remainingStopCount: 2,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure heading semantics is present with level 2
      final headingFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.headingLevel == 2,
      );
      expect(headingFinder, findsOneWidget);

      // Ensure row semantics exclude inner text duplication
      final nextStopSemantics = find.byWidgetPredicate(
        (w) => w is Semantics && w.excludeSemantics && w.properties.label == 'Next Stop: Katpadi Station',
      );
      expect(nextStopSemantics, findsOneWidget);

      final etaSemantics = find.byWidgetPredicate(
        (w) => w is Semantics && w.excludeSemantics && w.properties.label == 'Estimated Arrival: 8 mins',
      );
      expect(etaSemantics, findsOneWidget);

      handle.dispose();
    });

    testWidgets('AccessibleButton uses excludeSemantics to prevent duplicate text readout', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibleButton(
              label: 'Confirm your transit pass purchase',
              onPressed: () {},
              child: const Text('Confirm Purchase'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buttonSemantics = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.excludeSemantics &&
            w.properties.button == true &&
            w.properties.label == 'Confirm your transit pass purchase',
      );
      expect(buttonSemantics, findsOneWidget);

      handle.dispose();
    });
  });
}
