import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/core/settings/app_settings_controller.dart';
import 'package:busbuddy/data/datasources/local_transport_data_source.dart';
import 'package:busbuddy/data/models/adaptive_shortcut.dart';
import 'package:busbuddy/data/repositories/ticket_repository.dart';
import 'package:busbuddy/data/repositories/transport_repository.dart';
import 'package:busbuddy/features/adaptive_ui/adaptive_shortcuts_modal.dart';
import 'package:busbuddy/features/adaptive_ui/adaptive_shortcuts_view.dart';
import 'package:busbuddy/features/adaptive_ui/adaptive_ui_service.dart';
import 'package:busbuddy/features/home/home_page.dart';
import 'package:busbuddy/features/journey/journey_controller.dart';
import 'package:busbuddy/features/settings/personalization_settings_page.dart';
import 'package:busbuddy/features/tickets/live_location_screen.dart';
import 'package:busbuddy/features/tickets/ticket_booking_suite_page.dart';
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
    AppSettingsController.instance.updateAdaptiveUi(true);
    AdaptiveUiService.instance.seedDemonstrationHabits();
  });

  tearDown(() {
    AppSettingsController.instance.updateAdaptiveUi(true);
    AdaptiveUiService.instance.seedDemonstrationHabits();
  });

  group('AdaptiveShortcutsView Widget', () {
    testWidgets('renders suggested shortcuts carousel when adaptiveUi is active', (tester) async {
      AdaptiveShortcut? executed;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: AdaptiveShortcutsView(
              onExecuteShortcut: (shortcut) => executed = shortcut,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Suggested for You'), findsOneWidget);
      expect(find.text('Manage'), findsOneWidget);
      expect(find.text('VIT → Katpadi Express'), findsOneWidget);
      expect(find.text('Track Bus 18B Live'), findsOneWidget);

      // Tap shortcut card
      await tester.tap(find.text('VIT → Katpadi Express'));
      await tester.pumpAndSettle();
      expect(executed?.title, 'VIT → Katpadi Express');
    });

    testWidgets('pin button updates shortcut status to accepted', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: AdaptiveShortcutsView(
              onExecuteShortcut: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find pin button by tooltip
      final pinButton = find.byTooltip('Pin Shortcut').first;
      await tester.tap(pinButton);
      await tester.pumpAndSettle();

      expect(AdaptiveUiService.instance.acceptedShortcuts.isNotEmpty, isTrue);
    });

    testWidgets('dismiss button removes shortcut from suggestions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: AdaptiveShortcutsView(
              onExecuteShortcut: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dismissButton = find.byTooltip('Dismiss').first;
      await tester.tap(dismissButton);
      await tester.pumpAndSettle();

      // Number of visible shortcuts decreased by 1
      expect(AdaptiveUiService.instance.visibleShortcuts.length, 2);
    });

    testWidgets('hides completely when AppSettingsController adaptiveUi toggle is false', (tester) async {
      AppSettingsController.instance.updateAdaptiveUi(false);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: AdaptiveShortcutsView(
              onExecuteShortcut: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Suggested for You'), findsNothing);
      expect(find.text('Manage'), findsNothing);
      expect(find.text('VIT → Katpadi Express'), findsNothing);
    });
  });

  group('AdaptiveShortcutsModal Management Sheet', () {
    testWidgets('opens modal and displays all active shortcuts with governance controls', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () => AdaptiveShortcutsModal.show(ctx),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Adaptive Shortcuts'), findsOneWidget);
      expect(find.text('Reset All Habits & Shortcuts'), findsOneWidget);
      expect(find.text('VIT → Katpadi Express'), findsOneWidget);
      expect(find.text('Track Bus 18B Live'), findsOneWidget);

      // Tap Reset All Habits & Shortcuts
      await tester.tap(find.text('Reset All Habits & Shortcuts'));
      await tester.pumpAndSettle();

      // Confirmation dialog pops up
      expect(find.text('Clear all learned shortcuts?'), findsOneWidget);
      await tester.tap(find.text('Clear All'));
      await tester.pumpAndSettle();

      // Everything cleared
      expect(AdaptiveUiService.instance.visibleShortcuts.isEmpty, isTrue);
      expect(find.text('No adaptive shortcuts yet'), findsOneWidget);
    });
  });

  group('HomePage Adaptive Shortcuts Integration', () {
    testWidgets('displays Suggested for You carousel on HomePage and executes 1-tap route shortcut', (tester) async {
      await tester.pumpWidget(testHomePageApp());
      await tester.pumpAndSettle();

      expect(find.text('Suggested for You'), findsOneWidget);
      expect(find.text('VIT → Katpadi Express'), findsOneWidget);

      // Tap the shortcut card
      await tester.tap(find.text('VIT → Katpadi Express'));
      await tester.pumpAndSettle();

      // Navigated to TicketBookingSuitePage
      expect(find.byType(TicketBookingSuitePage), findsOneWidget);
    });

    testWidgets('executes 1-tap live tracking shortcut navigating to LiveLocationScreen', (tester) async {
      await tester.pumpWidget(testHomePageApp());
      await tester.pumpAndSettle();

      expect(find.text('Track Bus 18B Live'), findsOneWidget);

      // Tap the live tracking shortcut
      await tester.tap(find.text('Track Bus 18B Live'));
      await tester.pumpAndSettle();

      // Navigated to LiveLocationScreen
      expect(find.byType(LiveLocationScreen), findsOneWidget);
    });
  });

  group('PersonalizationSettingsPage Integration', () {
    testWidgets('displays Manage Adaptive Shortcuts tile when enabled, toggling it hides tile', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PersonalizationSettingsPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Switch is on by default in setUp
      expect(find.text('Manage Adaptive Shortcuts'), findsOneWidget);

      // Tap Switch to disable Adaptive UI
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(AppSettingsController.instance.adaptiveUi, isFalse);
      expect(find.text('Manage Adaptive Shortcuts'), findsNothing);

      // Tap Switch to re-enable Adaptive UI
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(AppSettingsController.instance.adaptiveUi, isTrue);
      expect(find.text('Manage Adaptive Shortcuts'), findsOneWidget);
    });

    testWidgets('tapping Manage Adaptive Shortcuts tile opens AdaptiveShortcutsModal', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PersonalizationSettingsPage(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Manage Adaptive Shortcuts'));
      await tester.pumpAndSettle();

      expect(find.text('Adaptive Shortcuts'), findsOneWidget);
      expect(find.text('Reset All Habits & Shortcuts'), findsOneWidget);
    });
  });
}
