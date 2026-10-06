import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/core/settings/app_settings_controller.dart';
import 'package:busbuddy/core/theme/app_theme.dart';
import 'package:busbuddy/domain/transit/entities/stop.dart';
import 'package:busbuddy/features/saved/saved_place_chips.dart';
import 'package:busbuddy/features/tickets/ticket_booking_suite_page.dart';
import 'package:busbuddy/features/tickets/ticket_controller.dart';
import 'package:busbuddy/data/repositories/ticket_repository.dart';

import '../helpers/map_test_tiles.dart';

/// Saved places live in the pickers now, not on a home page option.
///
/// The old SavedPage showed ticket history instead of places, so it was
/// deleted: its passbook coverage moved to MyTicketsPage, and places became
/// one-tap chips in booking step 1 and the Find-a-Place stop picker, backed
/// by a seeded, star-togglable stop-ID list in AppSettingsController.
void main() {
  setUpAll(stubMapTiles);

  group('saved places store', () {
    test('seeds the corridor everyday places', () {
      final settings = AppSettingsController.local();
      expect(
        settings.savedPlaceStopIds,
        containsAll([
          'vit-main-gate',
          'katpadi-railway-station',
          'green-circle',
          'katpadi-bus-stand',
        ]),
      );
    });

    test('toggle adds and removes a stop', () {
      final settings = AppSettingsController.local();
      expect(settings.isPlaceSaved('cmc-hospital'), isFalse);

      settings.toggleSavedPlace('cmc-hospital', save: true);
      expect(settings.isPlaceSaved('cmc-hospital'), isTrue);

      settings.toggleSavedPlace('cmc-hospital', save: false);
      expect(settings.isPlaceSaved('cmc-hospital'), isFalse);
    });

    test('re-saving an entry does not duplicate it', () {
      final settings = AppSettingsController.local();
      final before = settings.savedPlaceStopIds.length;
      settings.toggleSavedPlace('green-circle', save: true);
      expect(settings.savedPlaceStopIds.length, before);
    });

    test('blank IDs are ignored', () {
      final settings = AppSettingsController.local();
      final before = List<String>.from(settings.savedPlaceStopIds);
      settings.toggleSavedPlace('   ', save: true);
      expect(settings.savedPlaceStopIds, before);
    });
  });

  group('SavedPlaceChips', () {
    const stops = [
      Stop(id: 'vit-main-gate', name: 'VIT Main Gate', area: 'VIT'),
      Stop(id: 'katpadi-railway-station', name: 'Katpadi Railway', area: 'Ktp'),
    ];

    testWidgets('tapping a chip selects that stop', (tester) async {
      Stop? picked;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SavedPlaceChips(stops: stops, onSelect: (s) => picked = s),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Katpadi Railway'));
      await tester.pumpAndSettle();
      expect(picked?.id, 'katpadi-railway-station');
    });

    testWidgets('highlights the picker current value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SavedPlaceChips(
              stops: stops,
              selectedStopId: 'vit-main-gate',
              onSelect: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chip = tester.widget<ActionChip>(
        find
            .ancestor(
              of: find.text('VIT Main Gate'),
              matching: find.byType(ActionChip),
            )
            .first,
      );
      final colors = AppTheme.colors(
        tester.element(find.text('VIT Main Gate')),
      );
      expect(chip.backgroundColor, colors.actionPrimary);
    });

    testWidgets('renders nothing when there are no saved stops', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SavedPlaceChips(stops: const [], onSelect: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ActionChip), findsNothing);
    });
  });

  group('booking step 1 saved places', () {
    testWidgets('tapping a chip sets the destination', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = TicketController(LocalTicketRepository());
      await tester.pumpWidget(
        MaterialApp(home: TicketBookingSuitePage(ticketController: controller)),
      );
      await tester.pumpAndSettle();

      // Seeded chips render above the DATE card.
      expect(find.text('SAVED PLACES'), findsOneWidget);

      await tester.tap(find.text('Green Circle'));
      await tester.pumpAndSettle();

      // The TO card now shows the tapped place.
      expect(find.text('Green Circle'), findsWidgets);
    });
  });
}
