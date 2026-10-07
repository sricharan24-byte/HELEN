import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busbuddy/core/widgets/bus_buddy_logo.dart';

void main() {
  group('BusBuddyLogo Component Tests', () {
    testWidgets('renders Bus in white and Buddy in brand blue (#007AFF)', (tester) async {
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

      expect(busText.style?.color, equals(Colors.white));
      expect(busText.style?.fontWeight, equals(FontWeight.w900));
      expect(busText.style?.fontSize, equals(24));

      expect(buddyText.style?.color, equals(const Color(0xFF007AFF)));
      expect(buddyText.style?.fontWeight, equals(FontWeight.w900));
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
