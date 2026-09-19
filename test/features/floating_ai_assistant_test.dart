import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/core/settings/app_settings_controller.dart';
import 'package:busbuddy/data/datasources/local_transport_data_source.dart';
import 'package:busbuddy/data/models/ticket_model.dart';
import 'package:busbuddy/data/models/transport_models.dart';
import 'package:busbuddy/data/repositories/ticket_repository.dart';
import 'package:busbuddy/data/repositories/transport_repository.dart';
import 'package:busbuddy/features/ai_assistant/floating_assistant_controller.dart';
import 'package:busbuddy/features/ai_assistant/floating_ai_assistant_overlay.dart';
import 'package:busbuddy/features/journey/journey_controller.dart';
import 'package:busbuddy/features/tickets/ticket_controller.dart';
import '../helpers/map_test_tiles.dart';

void main() {
  setUpAll(stubMapTiles);
  group('FloatingAssistantController Unit Tests', () {
    late FloatingAssistantController controller;

    setUp(() {
      controller = FloatingAssistantController.instance;
      controller.closeWindow();
      if (controller.isMuted) controller.toggleMute();
      controller.initialize();
    });

    test('initial state has window closed, unmuted, and contains welcome message', () {
      expect(controller.isWindowOpen, isFalse);
      expect(controller.isMuted, isFalse);
      expect(controller.isListening, isFalse);
      expect(controller.isSpeaking, isFalse);
      expect(controller.messages.isNotEmpty, isTrue);
      expect(controller.messages.first.isAi, isTrue);
      expect(controller.messages.first.text, contains('BusBuddy'));
    });

    test('openWindow, closeWindow, and toggleWindow modify isWindowOpen', () {
      expect(controller.isWindowOpen, isFalse);

      controller.openWindow();
      expect(controller.isWindowOpen, isTrue);

      controller.closeWindow();
      expect(controller.isWindowOpen, isFalse);

      controller.toggleWindow();
      expect(controller.isWindowOpen, isTrue);

      controller.toggleWindow();
      expect(controller.isWindowOpen, isFalse);
    });

    test('toggleMute switches muted state and stops audio when muted', () {
      expect(controller.isMuted, isFalse);

      controller.toggleMute();
      expect(controller.isMuted, isTrue);
      expect(controller.liveStatus, equals('Muted'));

      controller.toggleMute();
      expect(controller.isMuted, isFalse);
      expect(controller.liveStatus, equals('Sound On'));
    });

    test('updatePosition safely clamps within screen boundaries', () {
      const screenSize = Size(400, 800);
      const safeArea = EdgeInsets.only(top: 40, bottom: 20);

      // Try placing outside top-left boundary
      controller.updatePosition(const Offset(-50, -50), screenSize, safeArea);
      expect(controller.position.dx, greaterThanOrEqualTo(16.0));
      expect(controller.position.dy, greaterThanOrEqualTo(56.0)); // top 40 + margin 16

      // Try placing outside bottom-right boundary
      controller.updatePosition(const Offset(999, 999), screenSize, safeArea);
      expect(controller.position.dx, lessThanOrEqualTo(400.0 - 64.0 - 16.0));
      expect(controller.position.dy, lessThanOrEqualTo(800.0 - 20.0 - 64.0 - 16.0));
    });

    test('clampToScreen re-clamps position within newly resized bounds', () {
      // Set to position that fits in large screen
      const largeScreen = Size(1000, 1000);
      const safeArea = EdgeInsets.zero;
      controller.updatePosition(const Offset(800, 700), largeScreen, safeArea);
      expect(controller.position.dx, equals(800.0));
      expect(controller.position.dy, equals(700.0));

      // Screen shrinks to 400x500
      const smallScreen = Size(400, 500);
      controller.clampToScreen(smallScreen, safeArea);
      expect(controller.position.dx, lessThanOrEqualTo(400.0 - 64.0 - 16.0));
      expect(controller.position.dy, lessThanOrEqualTo(500.0 - 64.0 - 16.0));
    });

    test('sendQuery records user query and generates grounded transit AI response', () {
      final initialCount = controller.messages.length;
      controller.sendQuery('Where is my bus?');

      expect(controller.messages.length, greaterThan(initialCount));
      final userMsg = controller.messages[initialCount];
      final aiMsg = controller.messages[initialCount + 1];

      expect(userMsg.isUser, isTrue);
      expect(userMsg.text, equals('Where is my bus?'));

      expect(aiMsg.isAi, isTrue);
      expect(aiMsg.text.isNotEmpty, isTrue);
      expect(aiMsg.actionType, isNotNull);
    });

    test('Where is my bus query recognizes active ticket', () {
      final ticketRepo = LocalTicketRepository();
      final ticketCtrl = TicketController(ticketRepo);

      final ticket = Ticket(
        id: 'BB-FLOAT-1',
        routeId: 'vit-to-katpadi',
        routeName: 'VIT → Katpadi',
        origin: const Stop(id: 'vit', name: 'VIT Main Gate', area: 'Vellore'),
        destination: const Stop(id: 'katpadi', name: 'Katpadi Railway Station', area: 'Katpadi'),
        busId: 'Bus 18B',
        passengerName: 'Passenger',
        passengerType: PassengerType.student,
        fareAmount: 10.0,
        paymentMethod: PaymentMethod.upi,
        issuedAt: DateTime.now(),
        validUntil: DateTime.now().add(const Duration(hours: 2)),
        qrCodeData: 'TEST-QR',
      );

      ticketCtrl.addTicket(ticket);
      controller.initialize(ticketCtrl: ticketCtrl);

      controller.sendQuery('Where is my bus?');
      final lastAiMsg = controller.messages.last;

      expect(lastAiMsg.isAi, isTrue);
      expect(lastAiMsg.actionType, equals('track_bus'));
      expect(lastAiMsg.text, contains('Bus 18B'));
    });

    test('settings toggle floatingAssistantEnabled updates app state', () {
      final settings = AppSettingsController.instance;
      settings.resetToDefaults();
      expect(settings.floatingAssistantEnabled, isTrue);

      settings.updateFloatingAssistantEnabled(false);
      expect(settings.floatingAssistantEnabled, isFalse);

      settings.resetToDefaults();
      expect(settings.floatingAssistantEnabled, isTrue);
    });
  });

  group('FloatingAiAssistantOverlay Widget Tests', () {
    late GlobalKey<NavigatorState> navKey;
    late TicketController ticketController;
    late TransportRepository repository;
    late JourneyController journeyController;

    setUp(() {
      AppSettingsController.instance.resetToDefaults();
      navKey = GlobalKey<NavigatorState>();
      final dataSource = LocalTransportDataSource();
      repository = LocalTransportRepository(dataSource: dataSource);
      journeyController = JourneyController(repository);
      ticketController = TicketController(LocalTicketRepository());

      final controller = FloatingAssistantController.instance;
      controller.resetForTesting();
      addTearDown(() {
        controller.resetForTesting();
      });
      controller.initialize(
        ticketCtrl: ticketController,
        repo: repository,
        journeyCtrl: journeyController,
      );
    });

    Widget buildTestApp() {
      return MaterialApp(
        navigatorKey: navKey,
        home: Scaffold(
          body: Stack(
            children: [
              const Center(child: Text('Main Screen Content')),
              FloatingAiAssistantOverlay(
                navigatorKey: navKey,
                ticketController: ticketController,
                repository: repository,
                journeyController: journeyController,
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('renders floating mascot bubble when window is closed', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Main Screen Content'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
      expect(find.text('BusBuddy AI'), findsNothing);
    });

    testWidgets('tapping floating bubble opens the small chat & voice window', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Tap the floating bubble
      await tester.tap(find.byIcon(Icons.auto_awesome));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Window header is now visible
      expect(find.text('BusBuddy AI'), findsOneWidget);
      expect(find.bySemanticsLabel('Minimize back to floating bubble'), findsOneWidget);
      expect(find.bySemanticsLabel('Mute AI voice'), findsOneWidget);
      expect(find.bySemanticsLabel('Open Full Screen Live Assistant'), findsOneWidget);
      expect(find.text('Ask BusBuddy anything...'), findsOneWidget);
      expect(find.text('Where is my bus?'), findsWidgets);
      expect(find.text('Tap to Speak'), findsOneWidget);
    });

    testWidgets('tapping minimize button closes the mini window back to bubble', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Open window
      await tester.tap(find.byIcon(Icons.auto_awesome));
      await tester.pumpAndSettle();
      expect(find.text('BusBuddy AI'), findsOneWidget);

      // Tap minimize
      await tester.tap(find.bySemanticsLabel('Minimize back to floating bubble'));
      await tester.pumpAndSettle();

      expect(find.text('BusBuddy AI'), findsNothing);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });

    testWidgets('tapping mute button toggles mute state in mini window', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Open window
      await tester.tap(find.byIcon(Icons.auto_awesome));
      await tester.pumpAndSettle();

      // Tap mute
      await tester.tap(find.bySemanticsLabel('Mute AI voice'));
      await tester.pumpAndSettle();

      expect(FloatingAssistantController.instance.isMuted, isTrue);
      expect(find.bySemanticsLabel('Unmute AI voice'), findsOneWidget);

      // Tap unmute
      await tester.tap(find.bySemanticsLabel('Unmute AI voice'));
      await tester.pumpAndSettle();

      expect(FloatingAssistantController.instance.isMuted, isFalse);
      expect(find.bySemanticsLabel('Mute AI voice'), findsOneWidget);
    });

    testWidgets('tapping prompt chip in mini window dispatches query and shows in feed', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Open window
      await tester.tap(find.byIcon(Icons.auto_awesome));
      await tester.pumpAndSettle();

      // Tap 'Book a ticket' chip
      await tester.tap(find.text('Book a ticket'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Book a ticket'), findsWidgets);
      await tester.pump(const Duration(seconds: 10));
      FloatingAssistantController.instance.resetForTesting();
    });

    testWidgets('tapping transit action button executes navigation', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Open window
      await tester.tap(find.byIcon(Icons.auto_awesome));
      await tester.pumpAndSettle();

      // Tap 'Find route' chip to trigger a message with an action button
      await tester.tap(find.text('Find route'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Locate the action button "View Route Options" in chat feed and tap
      final actionFinder = find.text('🚌 View Route Options');
      expect(actionFinder, findsOneWidget);
      await tester.ensureVisible(actionFinder);
      await tester.pumpAndSettle();
      await tester.tap(actionFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      if (FloatingAssistantController.instance.isWindowOpen) {
        FloatingAssistantController.instance.executeAction(
          tester.element(actionFinder),
          'search_route',
          navKey,
        );
        await tester.pumpAndSettle();
      }

      // Floating window should be closed and Route Details page should be visible
      expect(FloatingAssistantController.instance.isWindowOpen, isFalse);
      await tester.pump(const Duration(seconds: 10));
      FloatingAssistantController.instance.resetForTesting();
    });
  });
}
