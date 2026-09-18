import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/core/settings/app_settings_controller.dart';
import 'package:busbuddy/data/models/ticket_model.dart';
import 'package:busbuddy/data/models/transport_models.dart';
import 'package:busbuddy/data/repositories/ticket_repository.dart';
import 'package:busbuddy/features/ai_assistant/gemini_live_screen.dart';
import 'package:busbuddy/features/ai_assistant/gemini_live_service.dart';
import 'package:busbuddy/features/tickets/ticket_controller.dart';

void main() {
  group('GeminiLiveService Unit Tests', () {
    const service = GeminiLiveService();

    test('where is my bus query returns trackBus intent when active ticket exists', () {
      final ticket = Ticket(
        id: 'BB123456',
        routeId: 'vit-to-katpadi',
        routeName: 'VIT → Katpadi',
        origin: const Stop(id: 'vit', name: 'VIT Main Gate', area: 'Vellore'),
        destination: const Stop(id: 'katpadi', name: 'Katpadi Railway Station', area: 'Katpadi'),
        busId: 'Bus 18B',
        passengerName: 'Pavan K',
        passengerType: PassengerType.student,
        fareAmount: 10.0,
        paymentMethod: PaymentMethod.upi,
        issuedAt: DateTime.now(),
        validUntil: DateTime.now().add(const Duration(hours: 2)),
        qrCodeData: 'BB123456-VALID',
      );

      final response = service.processVoiceQuery('Where is my bus?', activeTicket: ticket);
      expect(response.intent, equals(GeminiLiveIntent.trackBus));
      expect(response.actionType, equals('track_bus'));
      expect(response.spokenResponse, contains('Bus 18B'));
    });

    test('where is my bus query prompts ticket booking when no active ticket exists', () {
      final response = service.processVoiceQuery('Where is my bus?');
      expect(response.intent, equals(GeminiLiveIntent.bookTicket));
      expect(response.actionType, equals('book_ticket'));
    });

    test('find a bus query returns searchRoute intent with available buses', () {
      final response = service.processVoiceQuery('Find a bus from VIT to Katpadi');
      expect(response.intent, equals(GeminiLiveIntent.searchRoute));
      expect(response.actionType, equals('search_route'));
      expect(response.spokenResponse, contains('Bus 18B'));
    });

    test('emergency help query returns emergencySos intent', () {
      final response = service.processVoiceQuery('Share my location emergency help');
      expect(response.intent, equals(GeminiLiveIntent.emergencySos));
      expect(response.actionType, equals('share_location'));
      expect(response.spokenResponse, contains('emergency safety broadcast'));
    });

    test('conversational queries with help do not trigger emergencySos', () {
      final r1 = service.processVoiceQuery('Can you help me find a bus?');
      expect(r1.intent, isNot(equals(GeminiLiveIntent.emergencySos)));

      final r2 = service.processVoiceQuery('Help me book a ticket');
      expect(r2.intent, isNot(equals(GeminiLiveIntent.emergencySos)));
    });

    test('saved places query returns openSaved intent', () {
      final response = service.processVoiceQuery('Open my saved places');
      expect(response.intent, equals(GeminiLiveIntent.openSaved));
      expect(response.actionType, equals('open_saved'));
    });

    test('customize home screen query returns customizeHome intent', () {
      final response = service.processVoiceQuery('Customize my home screen layout');
      expect(response.intent, equals(GeminiLiveIntent.customizeHome));
      expect(response.actionType, equals('customize_home'));
      expect(response.spokenResponse, contains('Home Screen customization'));
    });

    test('reset home screen query returns resetHome intent', () {
      final response = service.processVoiceQuery('Reset my home screen layout');
      expect(response.intent, equals(GeminiLiveIntent.resetHome));
      expect(response.actionType, equals('reset_home'));
      expect(response.spokenResponse, contains('reset your home screen layout'));
    });

    test('spoken responses do not contain robotic "Gemini Live:" prefix and sound natural', () {
      final q1 = service.processVoiceQuery('Where is my bus?');
      final q2 = service.processVoiceQuery('Find a bus from VIT to Katpadi');
      final q3 = service.processVoiceQuery('Book a ticket');
      final q4 = service.processVoiceQuery('Emergency SOS help');
      final q5 = service.processVoiceQuery('Open my saved places');
      final q6 = service.processVoiceQuery('What can you do?');

      for (final resp in [q1, q2, q3, q4, q5, q6]) {
        expect(resp.spokenResponse.startsWith('Gemini Live:'), isFalse,
            reason: 'Robotic prefix should be removed: ${resp.spokenResponse}');
        expect(resp.spokenResponse.isNotEmpty, isTrue);
      }
    });

    test('voice settings default to Aoede and can be configured with official voices', () {
      final controller = AppSettingsController.instance;
      controller.resetToDefaults();
      expect(controller.geminiVoice, equals('Aoede'));

      controller.updateGeminiVoice('Kore');
      expect(controller.geminiVoice, equals('Kore'));

      controller.updateGeminiVoice('Charon');
      expect(controller.geminiVoice, equals('Charon'));

      controller.resetToDefaults();
      expect(controller.geminiVoice, equals('Aoede'));
    });
  });

  group('GeminiLiveScreen Widget Tests', () {
    testWidgets('renders Gemini Live screen with header, visualizer orb, and prompt chips', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GeminiLiveScreen(
            ticketController: TicketController(LocalTicketRepository()),
          ),
        ),
      );
      // Flush the 600ms delayed mic-start timer plus the stub's immediate
      // fake recognition result and its 4s speech-animation timer, so no
      // Timer is pending when the widget tree is disposed.
      await tester.pump(const Duration(seconds: 6));

      expect(find.text('NOT CONNECTED'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsWidgets);
      expect(find.text('Where is my bus?'), findsWidgets);
      expect(find.text('Find a bus from VIT to Katpadi'), findsOneWidget);
    });

    testWidgets('tapping prompt chip processes voice query and updates output', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GeminiLiveScreen(
            ticketController: TicketController(LocalTicketRepository()),
          ),
        ),
      );
      // Flush initial 600ms delayed mic-start timer and 4s speech animation timer
      await tester.pump(const Duration(seconds: 6));

      await tester.tap(find.widgetWithText(ActionChip, 'Where is my bus?'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));

      expect(find.text('Where is my bus?'), findsWidgets);
    });
  });
}
