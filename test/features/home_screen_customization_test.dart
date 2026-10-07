import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/core/settings/app_settings_controller.dart';
import 'package:busbuddy/data/models/home_screen_item.dart';
import 'package:busbuddy/features/settings/home_screen_customization_page.dart';

Widget testCustomizationApp() {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: const HomeScreenCustomizationPage(),
  );
}

void main() {
  setUp(AppSettingsController.instance.resetHomeScreenLayout);

  group('HomeScreenCustomizationPage Rendering', () {
    testWidgets(
      'renders header branding, guidance hero, tip box, and all 6 items',
      (tester) async {
        await tester.pumpWidget(testCustomizationApp());
        await tester.pumpAndSettle();

        // App bar is a single reflow-safe page title (the two-line
        // 'Bus'+'Buddy' brand Column overflowed at 300% text scale).
        expect(find.text('Customize Home Screen'), findsOneWidget);
        expect(find.text('Customize Your Home'), findsOneWidget);
        expect(
          find.textContaining('Drag cards using ≡ to reorder'),
          findsOneWidget,
        );
        expect(find.textContaining('5 of 5 visible'), findsOneWidget);

        // Verify all 5 default items are displayed (Saved Places moved to the
        // booking pickers; My Journey, Live Bus Map, and Corridor Alerts removed)
        expect(find.text('Find a Place'), findsOneWidget);
        expect(find.text('My Tickets'), findsOneWidget);
        expect(find.text('Saved Places'), findsNothing);
        expect(find.text('Ask BusBuddy'), findsOneWidget);
        expect(find.text('My Journey'), findsNothing);
        expect(find.text('Live Bus Map'), findsNothing);
        expect(find.text('Corridor Alerts'), findsNothing);
        expect(find.text('Emergency SOS'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);

        // Verify action buttons
        expect(find.text('Reset Layout'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
      },
    );
  });

  group('HomeScreenCustomizationPage Interactions', () {
    testWidgets(
      'toggling visibility switch updates controller and card state',
      (tester) async {
        await tester.pumpWidget(testCustomizationApp());
        await tester.pumpAndSettle();

        // Find switch for 'Find a Place'
        final switches = find.byType(Switch);
        expect(switches, findsWidgets);

        // Tap the first switch to toggle visibility to false
        await tester.tap(switches.first);
        await tester.pumpAndSettle();

        final firstItem = AppSettingsController.instance.homeScreenItems.first;
        expect(firstItem.id, HomeScreenItem.idRouteSearch);
        expect(firstItem.isVisible, false);

        // Shows 'Hidden' badge
        expect(find.text('Hidden'), findsOneWidget);
        expect(find.textContaining('4 of 5 visible'), findsOneWidget);

        // Toggle back to true
        await tester.tap(switches.first);
        await tester.pumpAndSettle();

        expect(
          AppSettingsController.instance.homeScreenItems.first.isVisible,
          true,
        );
        expect(find.textContaining('5 of 5 visible'), findsOneWidget);
      },
    );

    testWidgets('move down and move up buttons reorder items correctly', (
      tester,
    ) async {
      await tester.pumpWidget(testCustomizationApp());
      await tester.pumpAndSettle();

      final itemsBefore = AppSettingsController.instance.homeScreenItems;
      expect(itemsBefore[0].id, HomeScreenItem.idRouteSearch);
      expect(itemsBefore[1].id, HomeScreenItem.idSafety);

      // Tap the Move Down button for the first item
      final moveDownButtons = find.byTooltip('Move Down');
      expect(moveDownButtons, findsWidgets);

      await tester.tap(moveDownButtons.first);
      await tester.pumpAndSettle();

      final itemsAfter = AppSettingsController.instance.homeScreenItems;
      expect(itemsAfter[0].id, HomeScreenItem.idSafety);
      expect(itemsAfter[1].id, HomeScreenItem.idRouteSearch);

      // Now tap Move Up on the second card to restore. The first card's
      // Move Up control is intentionally disabled (already at the top), so
      // target the enabled control belonging to the second card.
      final moveUpButtons = find.byTooltip('Move Up');
      expect(moveUpButtons, findsWidgets);

      await tester.tap(moveUpButtons.at(1));
      await tester.pumpAndSettle();

      final itemsRestored = AppSettingsController.instance.homeScreenItems;
      expect(itemsRestored[0].id, HomeScreenItem.idRouteSearch);
      expect(itemsRestored[1].id, HomeScreenItem.idSafety);
    });

    testWidgets('reset layout button restores default order and visibility', (
      tester,
    ) async {
      await tester.pumpWidget(testCustomizationApp());
      await tester.pumpAndSettle();

      // Modify order and hide an item
      AppSettingsController.instance.reorderHomeScreenItem(0, 3);
      AppSettingsController.instance.toggleHomeScreenItemVisibility(
        HomeScreenItem.idMyTickets,
        false,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('4 of 5 visible'), findsOneWidget);

      // Tap reset layout button
      await tester.tap(find.text('Reset Layout'));
      await tester.pumpAndSettle();

      final items = AppSettingsController.instance.homeScreenItems;
      expect(items[0].id, HomeScreenItem.idRouteSearch);
      expect(items.every((e) => e.isVisible), isTrue);
      expect(find.textContaining('5 of 5 visible'), findsOneWidget);
    });

    testWidgets('tapping Done button pops the screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const HomeScreenCustomizationPage(),
                ),
              ),
              child: const Text('Open Customization'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Customization'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreenCustomizationPage), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreenCustomizationPage), findsNothing);
    });
  });
}
