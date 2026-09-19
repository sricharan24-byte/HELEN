import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/data/datasources/local_transport_data_source.dart';
import 'package:busbuddy/data/repositories/ticket_repository.dart';
import 'package:busbuddy/data/repositories/transport_repository.dart';
import 'package:busbuddy/features/settings/accessibility_settings_page.dart';
import 'package:busbuddy/features/settings/home_screen_customization_page.dart';
import 'package:busbuddy/features/settings/personalization_settings_page.dart';
import 'package:busbuddy/features/settings/settings_page.dart';
import 'package:busbuddy/features/settings/voice_assistant_settings_page.dart';
import 'package:busbuddy/features/tickets/ticket_controller.dart';
import '../helpers/map_test_tiles.dart';

void main() {
  setUpAll(stubMapTiles);
  group('AccessibilitySettingsPage', () {
    testWidgets('renders hero header, dark cards, tip box, and Ask BusBuddy button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AccessibilitySettingsPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Accessibility'), findsWidgets);
      expect(find.text('Adjust the app to make it easier to use.'), findsOneWidget);
      expect(find.text('Text Size'), findsOneWidget);
      expect(find.text('High Contrast'), findsOneWidget);
      expect(find.text('Voice & TalkBack'), findsOneWidget);
      expect(find.text('Haptic Feedback'), findsOneWidget);
      expect(find.text('Simplified Navigation'), findsOneWidget);
      expect(find.text('Screen Reader Hints', skipOffstage: false), findsOneWidget);
      expect(find.text('Tip', skipOffstage: false), findsOneWidget);
      expect(find.text('Ask BusBuddy', skipOffstage: false), findsOneWidget);
    });

    testWidgets('tapping Text Size opens bottom sheet selector', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AccessibilitySettingsPage(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Text Size'));
      await tester.pumpAndSettle();

      expect(find.text('Select Text Size'), findsOneWidget);
      expect(find.text('Extra Large'), findsOneWidget);
    });
  });

  group('PersonalizationSettingsPage', () {
    testWidgets('renders green hero header, white cards, learning info box, and Ask BusBuddy button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PersonalizationSettingsPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Personalization'), findsWidgets);
      expect(find.text('Customize your experience and choose what you see.'), findsOneWidget);
      expect(find.text('Customize Home Screen'), findsOneWidget);
      expect(find.text('Adaptive UI'), findsOneWidget);
      expect(find.textContaining('BusBuddy learns your frequently used features'), findsOneWidget);
      expect(find.text('Default Starting Screen'), findsOneWidget);
      expect(find.text('Reset My Layout', skipOffstage: false), findsOneWidget);
      expect(find.text('Ask BusBuddy', skipOffstage: false), findsOneWidget);
    });

    testWidgets('tapping Default Starting Screen opens starting screen selector', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PersonalizationSettingsPage(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Default Starting Screen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Default Starting Screen'));
      await tester.pumpAndSettle();

      expect(find.text('Live Tracking'), findsOneWidget);
    });

    testWidgets('tapping Customize Home Screen opens HomeScreenCustomizationPage', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PersonalizationSettingsPage(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Customize Home Screen'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreenCustomizationPage), findsOneWidget);
    });
  });

  group('VoiceAssistantSettingsPage', () {
    testWidgets('renders purple mic hero header, light cards, dark example box, and Ask BusBuddy button', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 2400);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: VoiceAssistantSettingsPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Voice Assistant'), findsWidgets);
      expect(find.text('Set up how you interact with BusBuddy using voice.'), findsOneWidget);
      expect(find.text('Preferred Language'), findsOneWidget);
      expect(find.text('Voice Speed'), findsOneWidget);
      expect(find.text('Wake Phrase'), findsOneWidget);
      expect(find.text('Voice Confirmations'), findsOneWidget);
      expect(find.text('Gemini Live Voice'), findsOneWidget);
      expect(find.text('Example'), findsOneWidget);
      expect(find.text('"Find a bus to Katpadi"'), findsOneWidget);
      expect(find.text('Ask BusBuddy'), findsOneWidget);
    });

    testWidgets('tapping Preferred Language opens language picker', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VoiceAssistantSettingsPage(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Preferred Language'));
      await tester.pumpAndSettle();

      expect(find.text('Tamil'), findsOneWidget);
      expect(find.text('Hindi'), findsOneWidget);
    });
  });

  group('SettingsPage Hub', () {
    testWidgets('renders master settings hub with navigation options', (tester) async {
      final dataSource = LocalTransportDataSource();
      final repository = LocalTransportRepository(dataSource: dataSource);
      final ticketRepo = LocalTicketRepository();
      final ticketController = TicketController(ticketRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(
            repository: repository,
            ticketController: ticketController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Accessibility Settings'), findsOneWidget);
      expect(find.text('Personalization Settings'), findsOneWidget);
      expect(find.text('Voice Assistant Settings'), findsOneWidget);
      expect(find.text('Emergency Contacts & SOS'), findsOneWidget);
    });

    testWidgets('tapping Accessibility Settings opens AccessibilitySettingsPage', (tester) async {
      final dataSource = LocalTransportDataSource();
      final repository = LocalTransportRepository(dataSource: dataSource);
      final ticketRepo = LocalTicketRepository();
      final ticketController = TicketController(ticketRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(
            repository: repository,
            ticketController: ticketController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Accessibility Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Adjust the app to make it easier to use.'), findsOneWidget);
    });
  });
}
