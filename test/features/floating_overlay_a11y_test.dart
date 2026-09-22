import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/core/a11y/announcement_coordinator.dart';
import 'package:busbuddy/core/settings/app_settings_controller.dart';
import 'package:busbuddy/data/datasources/local_transport_data_source.dart';
import 'package:busbuddy/data/repositories/ticket_repository.dart';
import 'package:busbuddy/data/repositories/transport_repository.dart';
import 'package:busbuddy/features/ai_assistant/floating_assistant_controller.dart';
import 'package:busbuddy/features/ai_assistant/floating_ai_assistant_overlay.dart';
import 'package:busbuddy/features/journey/journey_controller.dart';
import 'package:busbuddy/features/tickets/ticket_controller.dart';
import '../helpers/map_test_tiles.dart';

void main() {
  setUpAll(stubMapTiles);

  group('Floating AI Assistant Overlay Accessibility Tests', () {
    late FloatingAssistantController controller;

    setUp(() {
      AppSettingsController.instance.resetToDefaults();
      controller = FloatingAssistantController.instance;
      controller.resetForTesting();
      controller.initialize();
    });

    tearDown(() {
      controller.resetForTesting();
    });

    test('non-drag corner repositioning functions update position safely', () {
      const screenSize = Size(400, 800);
      const safeArea = EdgeInsets.only(top: 40, bottom: 20);

      // Move to top left
      controller.moveToTopLeft(screenSize, safeArea);
      expect(controller.position.dx, equals(16.0));
      expect(controller.position.dy, equals(56.0)); // 40 + 16

      // Move to top right
      controller.moveToTopRight(screenSize, safeArea);
      expect(controller.position.dx, equals(400.0 - 64.0 - 16.0));
      expect(controller.position.dy, equals(56.0));

      // Move to bottom left
      controller.moveToBottomLeft(screenSize, safeArea);
      expect(controller.position.dx, equals(16.0));
      expect(controller.position.dy, equals(800.0 - 20.0 - 150.0));

      // Move to bottom right (reset)
      controller.moveToBottomRight(screenSize, safeArea);
      expect(controller.position.dx, equals(400.0 - 64.0 - 20.0));
      expect(controller.position.dy, equals(800.0 - 20.0 - 64.0 - 90.0));
    });

    test('isSpeaking state synchronizes with AnnouncementCoordinator.isAudioPlaying', () {
      final coordinator = AnnouncementCoordinator.instance;
      expect(coordinator.isAudioPlaying, isFalse);

      controller.setSpeaking(true);
      expect(controller.isSpeaking, isTrue);
      expect(coordinator.isAudioPlaying, isTrue);

      controller.setSpeaking(false);
      expect(controller.isSpeaking, isFalse);
      expect(coordinator.isAudioPlaying, isFalse);
    });

    testWidgets('BlockSemantics is active when window is open, preventing background traversal', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      final dataSource = LocalTransportDataSource();
      final repository = LocalTransportRepository(dataSource: dataSource);
      final journeyController = JourneyController(repository);
      final ticketController = TicketController(LocalTicketRepository());

      controller.initialize(
        ticketCtrl: ticketController,
        repo: repository,
        journeyCtrl: journeyController,
      );

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: Scaffold(
            body: Stack(
              children: [
                const Center(child: Text('Background Content')),
                FloatingAiAssistantOverlay(
                  navigatorKey: navKey,
                  ticketController: ticketController,
                  repository: repository,
                  journeyController: journeyController,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Bubble is visible, window is closed (exclude the Navigator's own ModalBarrier
      // BlockSemantics by scoping the finder to the overlay widget)
      expect(
        find.descendant(
          of: find.byType(FloatingAiAssistantOverlay),
          matching: find.byType(BlockSemantics),
        ),
        findsNothing,
      );

      // Open window
      await tester.tap(find.byIcon(Icons.auto_awesome));
      await tester.pumpAndSettle();

      // Verify BlockSemantics barrier is scoped to the floating overlay window
      // (MaterialApp's own Navigator ModalBarrier also contains a BlockSemantics)
      final overlayBlockSemantics = find.descendant(
        of: find.byType(FloatingAiAssistantOverlay),
        matching: find.byType(BlockSemantics),
      );
      expect(overlayBlockSemantics, findsOneWidget);

      final blockSemanticsWidget = tester.widget<BlockSemantics>(overlayBlockSemantics);
      expect(blockSemanticsWidget.blocking, isTrue);

      // Verify controls have >= 48dp minimum hit targets
      // Close control uses a tooltip; asserted below via the icon finder.

      // Even if tooltip is not set, find by icon Icons.close
      final closeIconFinder = find.byIcon(Icons.close);
      expect(closeIconFinder, findsOneWidget);
      final closeSize = tester.getSize(find.ancestor(of: closeIconFinder, matching: find.byType(IconButton)));
      expect(closeSize.width, greaterThanOrEqualTo(48.0));
      expect(closeSize.height, greaterThanOrEqualTo(48.0));

      final sendIconFinder = find.byIcon(Icons.send);
      expect(sendIconFinder, findsOneWidget);
      final sendSize = tester.getSize(find.ancestor(of: sendIconFinder, matching: find.byType(IconButton)));
      expect(sendSize.width, greaterThanOrEqualTo(48.0));
      expect(sendSize.height, greaterThanOrEqualTo(48.0));

      // Clean up
      controller.closeWindow();
      await tester.pumpAndSettle();
    });
  });
}
