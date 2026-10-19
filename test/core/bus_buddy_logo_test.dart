import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busbuddy/core/theme/app_theme.dart';
import 'package:busbuddy/core/widgets/bus_buddy_logo.dart';

void main() {
  group('BusBuddyLogo Component Tests', () {
    testWidgets('renders Bus in the primary text color and Buddy in brand blue', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BusBuddyLogo(fontSize: 24),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final busFinder = find.text('Bus');
      final buddyFinder = find.text('Buddy');

      expect(busFinder, findsOneWidget);
      expect(buddyFinder, findsOneWidget);

      final Text busText = tester.widget(busFinder);
      final Text buddyText = tester.widget(buddyFinder);
      final colors = AppTheme.colors(
        tester.element(find.byType(BusBuddyLogo)),
      );

      expect(busText.style?.color, equals(colors.textPrimary));
      expect(busText.style?.fontWeight, equals(FontWeight.w800));
      expect(busText.style?.fontSize, equals(24));

      expect(buddyText.style?.color, equals(colors.actionPrimary));
      expect(buddyText.style?.fontWeight, equals(FontWeight.w800));
      expect(buddyText.style?.fontSize, equals(24));
    });

    testWidgets('renders subtitle with correct text when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BusBuddyLogo(
              fontSize: 20,
              subtitle: 'My Tickets',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bus'), findsOneWidget);
      expect(find.text('Buddy'), findsOneWidget);
      expect(find.text('My Tickets'), findsOneWidget);
    });
  });
}
