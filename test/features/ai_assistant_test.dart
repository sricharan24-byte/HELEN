import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/data/datasources/local_transport_data_source.dart';
import 'package:busbuddy/data/repositories/ticket_repository.dart';
import 'package:busbuddy/data/repositories/transport_repository.dart';
import 'package:busbuddy/features/ai_assistant/ai_assistant_dialog.dart';
import 'package:busbuddy/features/ai_assistant/ai_assistant_service.dart';
import 'package:busbuddy/features/tickets/ticket_controller.dart';

void main() {
  group('AiAssistantService', () {
    test('returns bus schedule info for timing queries', () {
      final service = AiAssistantService();
      final response = service.processQuery('When is the next bus?');

      expect(response.text, contains('departing'));
      expect(response.actionLabel, isNotNull);
    });

    test('returns fare discount breakdown for fare queries', () {
      final service = AiAssistantService();
      final response = service.processQuery('How much is student ticket fare?');

      expect(response.text, contains('Student Pass: ₹12'));
      expect(response.actionType, 'book_ticket');
    });
  });

  group('AiAssistantDialog Widget', () {
    testWidgets('renders title, suggestion chips, and mic button', (tester) async {
      final dataSource = LocalTransportDataSource();
      final repository = LocalTransportRepository(dataSource: dataSource);
      final ticketRepo = LocalTicketRepository();
      final ticketController = TicketController(ticketRepo);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: AiAssistantDialog(
              ticketController: ticketController,
              repository: repository,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Talk to BusBuddy AI'), findsOneWidget);
      expect(find.text('Next bus to Katpadi'), findsOneWidget);
      expect(find.text('Student fare price'), findsOneWidget);
    });
  });
}
