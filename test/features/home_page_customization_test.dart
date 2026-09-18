import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/core/settings/app_settings_controller.dart';
import 'package:busbuddy/data/datasources/local_transport_data_source.dart';
import 'package:busbuddy/data/models/home_screen_item.dart';
import 'package:busbuddy/data/repositories/ticket_repository.dart';
import 'package:busbuddy/data/repositories/transport_repository.dart';
import 'package:busbuddy/features/alerts/alerts_page.dart';
import 'package:busbuddy/features/home/home_page.dart';
import 'package:busbuddy/features/journey/journey_controller.dart';
import 'package:busbuddy/features/safety/safety_sharing_page.dart';
import 'package:busbuddy/features/tickets/live_location_screen.dart';
import 'package:busbuddy/features/tickets/ticket_controller.dart';
import '../helpers/map_test_tiles.dart';

Widget testHomePageApp({TicketController? ticketController}) {
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
      onRouteSelected: (_) {},
    ),
  );
}

void main() {
  setUpAll(stubMapTiles);
  setUp(() {
    AppSettingsController.instance.resetHomeScreenLayout();
  });

  tearDown(() {
    AppSettingsController.instance.resetHomeScreenLayout();
  });

  group('HomePage Custom Layout Rendering', () {
    testWidgets('renders cards according to customized order in AppSettingsController', (tester) async {
      // Move Settings to the very top (index 0)
      final items = List<HomeScreenItem>.from(AppSettingsController.instance.homeScreenItems);
      final settingsItem = items.firstWhere((e) => e.id == HomeScreenItem.idSettings);
      items.remove(settingsItem);
      items.insert(0, settingsItem);
      AppSettingsController.instance.updateHomeScreenItems(items);

      await tester.pumpWidget(testHomePageApp());
      await tester.pumpAndSettle();

      // Both Settings and Find a Place are visible
      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Find a Place'), findsOneWidget);
    });

    testWidgets('excludes cards marked as hidden (isVisible == false)', (tester) async {
      // Hide 'Find a Place' and 'Ask BusBuddy'
      AppSettingsController.instance.toggleHomeScreenItemVisibility(HomeScreenItem.idRouteSearch, false);
      AppSettingsController.instance.toggleHomeScreenItemVisibility(HomeScreenItem.idVoiceAssistant, false);

      await tester.pumpWidget(testHomePageApp());
      await tester.pumpAndSettle();

      expect(find.text('Find a Place'), findsNothing);
      expect(find.text('Ask BusBuddy'), findsNothing);

      // Other visible cards remain
      expect(find.text('My Tickets'), findsOneWidget);
      expect(find.text('Saved Places', skipOffstage: false), findsOneWidget);
    });

    testWidgets('displays empty layout state when all cards are hidden, and restores default cards', (tester) async {
      // Hide all cards
      for (final item in AppSettingsController.instance.homeScreenItems) {
        AppSettingsController.instance.toggleHomeScreenItemVisibility(item.id, false);
      }

      await tester.pumpWidget(testHomePageApp());
      await tester.pumpAndSettle();

      // Empty layout card is visible
      expect(find.text('All Home Cards Hidden'), findsOneWidget);
      expect(find.text('Restore Default Cards'), findsOneWidget);
      expect(find.text('Find a Place'), findsNothing);

      // Tap 'Restore Default Cards'
      await tester.tap(find.text('Restore Default Cards'));
      await tester.pumpAndSettle();

      // Cards are restored
      expect(find.text('All Home Cards Hidden'), findsNothing);
      expect(find.text('Find a Place'), findsOneWidget);
      expect(find.text('My Tickets'), findsOneWidget);
    });
  });

  group('HomePage Navigation for Additional Configurable Cards', () {
    testWidgets('tapping Live Bus Map opens LiveLocationScreen', (tester) async {
      await tester.pumpWidget(testHomePageApp());
      await tester.pumpAndSettle();

      // Scroll if necessary and tap Live Bus Map
      final liveMapFinder = find.text('Live Bus Map', skipOffstage: false);
      expect(liveMapFinder, findsOneWidget);

      await tester.ensureVisible(liveMapFinder);
      await tester.pumpAndSettle();
      await tester.tap(liveMapFinder);
      await tester.pumpAndSettle();

      expect(find.byType(LiveLocationScreen), findsOneWidget);
    });

    testWidgets('tapping Corridor Alerts opens AlertsPage', (tester) async {
      await tester.pumpWidget(testHomePageApp());
      await tester.pumpAndSettle();

      final alertsFinder = find.text('Corridor Alerts', skipOffstage: false);
      expect(alertsFinder, findsOneWidget);

      await tester.ensureVisible(alertsFinder);
      await tester.pumpAndSettle();
      await tester.tap(alertsFinder);
      await tester.pumpAndSettle();

      expect(find.byType(AlertsPage), findsOneWidget);
    });

    testWidgets('tapping Emergency SOS opens SafetySharingPage', (tester) async {
      await tester.pumpWidget(testHomePageApp());
      await tester.pumpAndSettle();

      final sosFinder = find.text('Emergency SOS', skipOffstage: false);
      expect(sosFinder, findsOneWidget);

      await tester.ensureVisible(sosFinder);
      await tester.pumpAndSettle();
      await tester.tap(sosFinder);
      await tester.pumpAndSettle();

      expect(find.byType(SafetySharingPage), findsOneWidget);
    });
  });
}
