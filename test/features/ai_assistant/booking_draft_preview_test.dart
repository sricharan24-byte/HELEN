import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/data/datasources/local_transport_data_source.dart';
import 'package:busbuddy/data/models/transport_models.dart';
import 'package:busbuddy/data/repositories/transport_repository.dart';
import 'package:busbuddy/domain/ticketing/entities/fare_engine.dart';
import 'package:busbuddy/domain/ticketing/entities/ticket.dart';
import 'package:busbuddy/features/ai_assistant/app_automation_controller.dart';
import 'package:busbuddy/features/ai_assistant/booking_draft_preview.dart';

void main() {
  group('BookingDraftPreview', () {
    testWidgets('hiddenUntilTheAgentStartsWorking', (tester) async {
      final automation = AppAutomationController();
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: BookingDraftPreview(
          automation: automation,
        ))),
      );

      // A fresh draft has nothing to preview — the card must not pretend the
      // agent is working.
      expect(find.text('Booking draft'), findsNothing);
    });

    testWidgets('showsSlotsWithProvenanceChips', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1400);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final automation = AppAutomationController();
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: BookingDraftPreview(
          automation: automation,
        ))),
      );

      automation.handleToolCall('set_trip', {
        'origin': 'VIT Main Gate',
        'destination': 'Katpadi Railway Station',
      });
      await tester.pumpAndSettle();

      expect(find.text('Booking draft'), findsOneWidget);
      // Passenger choices are labelled as such.
      expect(find.text('You chose'), findsWidgets);
      expect(find.text('VIT Main Gate → Katpadi Railway Station'), findsOneWidget);
      // The bus, passenger, and payment fallbacks are honestly shown as
      // not-yet-chosen (value text + provenance chip each).
      expect(find.text('Not set yet'), findsNWidgets(6));
      // The header lists what is still missing (the Semantics summary says
      // "Still needed: …"; the visible header shows the label list).
      expect(find.text('bus, passenger type and payment method'), findsOneWidget);
      expect(find.textContaining('payment method'), findsOneWidget);
    });

    testWidgets('profileDefaultShowsAsYourDefault', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1400);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final automation = AppAutomationController();
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: BookingDraftPreview(
          automation: automation,
        ))),
      );

      automation.applyProfileDefaults(
        preferredName: 'Pavan',
        passengerType: PassengerType.student,
      );
      await tester.pumpAndSettle();

      expect(find.text('Your default'), findsOneWidget);
      expect(find.text('Student'), findsOneWidget);
      // The profile name is never presented as the ticket passenger.
      expect(find.textContaining('Pavan'), findsNothing);
    });

    testWidgets('suggestionBannerAcceptPromotes', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1600);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final automation = AppAutomationController();
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: BookingDraftPreview(
          automation: automation,
        ))),
      );

      automation.stageRecentTripSuggestion(
        origin: const Stop(
          id: 'vit-main-gate',
          name: 'VIT Main Gate',
          area: 'VIT',
        ),
        destination: const Stop(
          id: 'katpadi-railway-station',
          name: 'Katpadi Railway Station',
          area: 'Katpadi',
        ),
        busId: 'Bus 18B',
      );
      await tester.pumpAndSettle();

      // The banner names the suggestion source and offers deterministic
      // accept / dismiss controls. Trip and bus are both staged, so two
      // provenance chips read "Suggestion".
      expect(find.textContaining('Suggested from your recent trips'), findsOneWidget);
      expect(find.text('Suggestion'), findsNWidgets(2));

      await tester.tap(find.text('Use this trip'));
      await tester.pumpAndSettle();

      // Acceptance promotes the staged values: the banner is gone and the
      // trip is now a passenger choice.
      expect(find.textContaining('Suggested from your recent trips'), findsNothing);
      expect(find.text('You chose'), findsWidgets);
      expect(
        automation.slotSources['origin'],
        BookingValueSource.passenger,
      );
    });

    testWidgets('suggestionDismissRevertsToUnset', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1600);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final automation = AppAutomationController();
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: BookingDraftPreview(
          automation: automation,
        ))),
      );

      automation.stageRecentTripSuggestion(
        origin: const Stop(
          id: 'vit-main-gate',
          name: 'VIT Main Gate',
          area: 'VIT',
        ),
        destination: const Stop(
          id: 'katpadi-railway-station',
          name: 'Katpadi Railway Station',
          area: 'Katpadi',
        ),
        busId: 'Bus 18B',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(automation.slotSources['origin'], BookingValueSource.unset);
      expect(automation.slotSources['bus'], BookingValueSource.unset);
      // Nothing left in the draft at all: the card hides again entirely.
      expect(find.text('Booking draft'), findsNothing);
    });

    testWidgets('fareRendersExactFromPaise', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1400);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = LocalTransportRepository(
        dataSource: LocalTransportDataSource(),
      );
      final automation = AppAutomationController(repository: repository);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: BookingDraftPreview(
          automation: automation,
        ))),
      );

      automation.handleToolCall('set_trip', {
        'origin': 'VIT Main Gate',
        'destination': 'Katpadi Railway Station',
      });
      automation.handleToolCall('set_passenger', {'type': 'student'});
      await tester.pumpAndSettle();

      // The rendered estimate must equal FareEngine's integer-paise quote for
      // the same route hops and passenger type — no invented number.
      final route = repository
          .findRoutes(
            originId: 'vit-main-gate',
            destinationId: 'katpadi-railway-station',
          )
          .first;
      final originIdx = route.orderedStopIds.indexOf('vit-main-gate');
      final destIdx = route.orderedStopIds.indexOf('katpadi-railway-station');
      final expected = FareEngine.calculateByStopCount(
        stopCount: (destIdx - originIdx).abs(),
        passengerType: PassengerType.student,
      );
      expect(
        find.textContaining('Estimated fare ${expected.formattedAmount}'),
        findsOneWidget,
      );
    });
  });
}
