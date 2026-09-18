// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/data/datasources/local_transport_data_source.dart';
import 'package:busbuddy/data/repositories/ticket_repository.dart';
import 'package:busbuddy/data/repositories/transport_repository.dart';
import 'package:busbuddy/features/journey/journey_controller.dart';
import 'package:busbuddy/features/tickets/ticket_controller.dart';
import 'package:busbuddy/main.dart';
import 'helpers/map_test_tiles.dart';

void main() {
  setUpAll(stubMapTiles);
  testWidgets('BusBuddy app renders home page correctly', (WidgetTester tester) async {
    final dataSource = LocalTransportDataSource();
    final repository = LocalTransportRepository(dataSource: dataSource);
    final journeyController = JourneyController(repository);
    final ticketRepository = LocalTicketRepository();
    final ticketController = TicketController(ticketRepository);

    await tester.pumpWidget(
      MyApp(
        journeyController: journeyController,
        repository: repository,
        ticketController: ticketController,
      ),
    );
    await tester.pumpAndSettle();

    // Verify BusBuddy logo/title renders
    expect(find.text('Bus'), findsWidgets);
    expect(find.text('Buddy'), findsWidgets);
  });
}
