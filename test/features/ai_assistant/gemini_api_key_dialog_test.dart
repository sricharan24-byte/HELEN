import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/core/settings/app_settings_controller.dart';
import 'package:busbuddy/data/datasources/local_transport_data_source.dart';
import 'package:busbuddy/data/repositories/transport_repository.dart';
import 'package:busbuddy/data/repositories/ticket_repository.dart';
import 'package:busbuddy/features/journey/journey_controller.dart';
import 'package:busbuddy/features/tickets/ticket_controller.dart';
import 'package:busbuddy/main.dart';
import '../../helpers/map_test_tiles.dart';

// Regression test (Chunk 42 follow-up): saving an API key in the Gemini Live
// setup dialog used to crash the widget tree with the framework's
// `_dependents.isEmpty` teardown assert. Root cause: the function-based
// dialog disposed its TextEditingController via `showDialog(...).then(...)`,
// which fires the moment the pop begins while the dialog is still animating
// out; the save button's settings notifications then rebuilt the
// still-mounted TextField against the disposed controller, cascading into
// out-of-order subtree teardown. The dialog is now a StatefulWidget that owns
// and disposes its controller with its own State.
//
// NOTE: pumpAndSettle never settles on the Live screen (repeating pulse
// animation), so only fixed-duration pumps are used.
void main() {
  setUpAll(stubMapTiles);

  testWidgets(
    'saving an API key in the Gemini Live setup dialog does not corrupt the widget tree',
    (tester) async {
      addTearDown(() => AppSettingsController.instance.updateGeminiApiKey(''));

      final dataSource = LocalTransportDataSource();
      final repository = LocalTransportRepository(dataSource: dataSource);
      final journeyController = JourneyController(repository);
      final ticketController = TicketController(LocalTicketRepository());

      await tester.pumpWidget(
        MyApp(
          journeyController: journeyController,
          repository: repository,
          ticketController: ticketController,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Push the Gemini Live screen via the Ask BusBuddy home card.
      await tester.scrollUntilVisible(
        find.text('Ask BusBuddy'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(find.text('Ask BusBuddy'));
      await tester.pump();
      // Route transition + mic-start/speech animation timers.
      await tester.pump(const Duration(seconds: 6));

      // Open the setup dialog via the header API-key status box.
      await tester.tap(find.text('Connect'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Save & Connect'), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'test-key-123',
      );

      await tester.tap(find.text('Save & Connect'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 6));

      // Dialog dismissed, key stored, and the tree is intact (no framework
      // teardown asserts). The header status pill flips to the live badge —
      // now a bolt icon plus the 'GEMINI LIVE' text (emoji removed).
      expect(find.text('Save & Connect'), findsNothing);
      expect(find.byIcon(Icons.bolt), findsOneWidget);
      expect(find.text('GEMINI LIVE'), findsWidgets);
      expect(AppSettingsController.instance.geminiApiKey, 'test-key-123');
    },
  );
}
