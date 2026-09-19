import 'package:flutter/material.dart' hide Route;
import 'package:flutter_test/flutter_test.dart';
import 'package:busbuddy/core/a11y/accessible_button.dart';
import 'package:busbuddy/core/a11y/map_text_alternative_widget.dart';
import 'package:busbuddy/core/a11y/status_banner.dart';
import 'package:busbuddy/core/tokens/app_spacing.dart';
import 'package:busbuddy/core/tokens/status_level.dart';
import 'package:busbuddy/data/models/transport_models.dart';

void main() {
  group('AccessibleButton (Astra Gate 4)', () {
    testWidgets('enforces 48dp minimum touch target and semantic label when enabled', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibleButton(
              onPressed: () => tapped = true,
              label: 'Confirm Booking',
              child: const Text('Confirm'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buttonFinder = find.byType(AccessibleButton);
      expect(buttonFinder, findsOneWidget);
      final size = tester.getSize(buttonFinder);
      expect(size.height, greaterThanOrEqualTo(AppSpacing.minTouchTarget));

      expect(find.bySemanticsLabel('Confirm Booking'), findsOneWidget);

      await tester.tap(buttonFinder);
      expect(tapped, isTrue);
    });

    testWidgets('announces disabledReason when disabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AccessibleButton(
              onPressed: null,
              label: 'Proceed to Payment',
              disabledReason: 'Please select a passenger type first',
              child: Text('Pay Now'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('Proceed to Payment, disabled: Please select a passenger type first'),
        findsOneWidget,
      );
    });
  });

  group('StatusBanner (Astra Gate 6 & WCAG 1.4.1)', () {
    testWidgets('displays icon, message, and semantic prefix', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBanner(
              message: 'Bus arriving in 3 minutes',
              level: StatusLevel.warning,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bus arriving in 3 minutes'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is Semantics && (w.properties.label?.contains('Warning: Bus arriving in 3 minutes') ?? false)),
        findsOneWidget,
      );
    });
  });

  group('MapTextAlternativeWidget (Astra Gate 8 — Map Equivalence)', () {
    testWidgets('provides accessible text alternative for all map telemetry', (tester) async {
      const route = Route(
        id: 'route-18b',
        displayName: 'Route 18B',
        direction: 'Inbound',
        orderedStopIds: ['s1', 's2', 's3', 's4'],
      );

      final busLocation = BusLocation(
        busId: 'BUS-18B',
        routeId: 'route-18b',
        latitude: 12.97,
        longitude: 79.15,
        speedKmh: 36.0,
        nextStopId: 's2',
        nextStopName: 'Green Circle',
        etaMinutes: 5,
        timestamp: DateTime.now(),
        progressPercentage: 0.4,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapTextAlternativeWidget(
              route: route,
              busLocation: busLocation,
              remainingStopCount: 2,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Live Bus Status (Map Alternative)'), findsOneWidget);
      expect(find.text('Green Circle'), findsOneWidget);
      expect(find.text('5 mins'), findsOneWidget);
      expect(find.text('36 km/h • 2 stops remaining'), findsOneWidget);
    });
  });
}
