import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busbuddy/core/a11y/announcement_coordinator.dart';
import 'package:busbuddy/core/theme/app_theme.dart';
import 'package:busbuddy/data/datasources/local_transport_data_source.dart';
import 'package:busbuddy/data/repositories/transport_repository.dart';
import 'package:busbuddy/features/journey/journey_controller.dart';
import 'package:busbuddy/features/journey/journey_page.dart';
import 'package:busbuddy/features/route_details/route_details_page.dart';
import 'package:busbuddy/features/route_search/route_search_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AnnouncementCoordinator.instance.reset();
  });

  tearDown(() {
    AnnouncementCoordinator.instance.reset();
  });

  group('Vertical Slice Journey Flow (Astra Step 2.3)', () {
    testWidgets('Search -> Route Details -> Active Journey vertical flow works end-to-end', (tester) async {
      final dataSource = LocalTransportDataSource();
      final repository = LocalTransportRepository(dataSource: dataSource);
      final controller = JourneyController(repository);

      // Preload origin and destination
      final origin = repository.getStop('vit-main-gate')!;
      final destination = repository.getStop('katpadi-railway-station')!;
      controller.selectOrigin(origin);
      controller.selectDestination(destination);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: RouteSearchPage(
            controller: controller,
            repository: repository,
            onRouteSelected: (routeId) {
              // Navigates to RouteDetailsPage
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify origin and destination are shown
      expect(find.text('VIT Main Gate'), findsOneWidget);
      expect(find.text('Katpadi Railway Station'), findsOneWidget);

      // Tap Search
      final searchButton = find.widgetWithText(ElevatedButton, 'Search');
      expect(searchButton, findsOneWidget);
      await tester.tap(searchButton);
      await tester.pumpAndSettle();

      // Route results appear
      expect(find.text('VIT → Katpadi Railway Station'), findsWidgets);

      // Select the route result
      await tester.tap(find.text('VIT → Katpadi Railway Station').first);
      await tester.pumpAndSettle();

      // Push RouteDetailsPage
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.highContrast,
          home: RouteDetailsPage(
            controller: controller,
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Route Details rendered under High-Contrast theme
      expect(find.text('Route Details & Live GPS'), findsOneWidget);
      expect(find.text('LIVE GPS'), findsOneWidget);
      expect(find.text('Stops along this route'), findsOneWidget);

      // Start the journey
      final startButton = find.bySemanticsLabel('Start this journey');
      expect(startButton, findsOneWidget);
      await tester.ensureVisible(startButton);
      await tester.pumpAndSettle();
      await tester.tap(startButton);
      await tester.pumpAndSettle();

      // Now on JourneyPage
      expect(find.text('Journey active'), findsOneWidget);
      expect(controller.state.phase, JourneyPhase.active);
      expect(
        AnnouncementCoordinator.instance.visualStatusText.value,
        anyOf(contains('Journey started'), contains('Bus approaching')),
      );
    });
  });
}
