import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/core/settings/app_settings_controller.dart';
import 'package:busbuddy/core/a11y/announcement_coordinator.dart';
import 'package:busbuddy/features/ai_assistant/audio_speech_engine.dart';
import 'package:busbuddy/data/datasources/local_transport_data_source.dart';
import 'package:busbuddy/data/models/ticket_model.dart';
import 'package:busbuddy/data/models/transport_models.dart';
import 'package:busbuddy/data/repositories/ticket_repository.dart';
import 'package:busbuddy/data/repositories/transport_repository.dart';
import 'package:busbuddy/features/ai_assistant/gemini_live_screen.dart';
import 'package:busbuddy/features/ai_assistant/gemini_live_service.dart';
import 'package:busbuddy/features/ai_assistant/gemini_live_transport.dart';
import 'package:busbuddy/features/ai_assistant/gemini_live_session.dart';
import 'package:busbuddy/features/tickets/ticket_booking_suite_page.dart';
import 'package:busbuddy/features/tickets/ticket_controller.dart';
import '../helpers/map_test_tiles.dart';

void main() {
  // GeminiLiveScreen mutes process-wide offline TTS while open: always start
  // each test unmuted so one test's screen never silences another's engine.
  setUp(() {
    AudioSpeechEngine.muteOfflineTts(false);
    AnnouncementCoordinator.instance.reset();
  });
  setUpAll(stubMapTiles);
  group('GeminiLiveService Unit Tests', () {
    const service = GeminiLiveService();

    test(
      'where is my bus query returns trackBus intent when active ticket exists',
      () {
        final ticket = Ticket(
          id: 'BB123456',
          routeId: 'vit-to-katpadi',
          routeName: 'VIT → Katpadi',
          origin: const Stop(id: 'vit', name: 'VIT Main Gate', area: 'Vellore'),
          destination: const Stop(
            id: 'katpadi',
            name: 'Katpadi Railway Station',
            area: 'Katpadi',
          ),
          busId: 'Bus 18B',
          passengerName: 'Pavan K',
          passengerType: PassengerType.student,
          fareQuote: FareQuote.fromPaise(
            basePaise: 1500,
            passengerType: PassengerType.student,
            discountPercentage: 40,
          ),
          paymentMethod: PaymentMethod.upi,
          issuedAt: DateTime.now(),
          validUntil: DateTime.now().add(const Duration(hours: 2)),
          qrCodeData: 'BB123456-VALID',
        );

        final response = service.processVoiceQuery(
          'Where is my bus?',
          activeTicket: ticket,
        );
        expect(response.intent, equals(GeminiLiveIntent.trackBus));
        expect(response.actionType, equals('track_bus'));
        expect(response.spokenResponse, contains('Bus 18B'));
      },
    );

    test(
      'where is my bus query prompts ticket booking when no active ticket exists',
      () {
        final response = service.processVoiceQuery('Where is my bus?');
        expect(response.intent, equals(GeminiLiveIntent.bookTicket));
        expect(response.actionType, equals('book_ticket'));
      },
    );

    test(
      'find a bus query returns searchRoute intent with available buses',
      () {
        final response = service.processVoiceQuery(
          'Find a bus from VIT to Katpadi',
        );
        expect(response.intent, equals(GeminiLiveIntent.searchRoute));
        expect(response.actionType, equals('search_route'));
        expect(response.spokenResponse, contains('Bus 18B'));
      },
    );

    test('emergency help query returns emergencySos intent', () {
      final response = service.processVoiceQuery(
        'Share my location emergency help',
      );
      expect(response.intent, equals(GeminiLiveIntent.emergencySos));
      expect(response.actionType, equals('emergency_sos'));
      expect(response.spokenResponse, contains('emergency location sharing'));
    });

    test('conversational queries with help do not trigger emergencySos', () {
      final r1 = service.processVoiceQuery('Can you help me find a bus?');
      expect(r1.intent, isNot(equals(GeminiLiveIntent.emergencySos)));

      final r2 = service.processVoiceQuery('Help me book a ticket');
      expect(r2.intent, isNot(equals(GeminiLiveIntent.emergencySos)));
    });

    test('saved places query routes to route search, where the chips live', () {
      final response = service.processVoiceQuery('Open my saved places');
      expect(response.intent, equals(GeminiLiveIntent.searchRoute));
      expect(response.actionType, equals('search_route'));
    });

    test('customize home screen query returns customizeHome intent', () {
      final response = service.processVoiceQuery(
        'Customize my home screen layout',
      );
      expect(response.intent, equals(GeminiLiveIntent.customizeHome));
      expect(response.actionType, equals('customize_home'));
      expect(response.spokenResponse, contains('Home Screen customization'));
    });

    test('reset home screen query returns resetHome intent', () {
      final response = service.processVoiceQuery('Reset my home screen layout');
      expect(response.intent, equals(GeminiLiveIntent.resetHome));
      expect(response.actionType, equals('reset_home'));
      expect(
        response.spokenResponse,
        contains('reset your home screen layout'),
      );
    });

    test(
      'spoken responses do not contain robotic "Gemini Live:" prefix and sound natural',
      () {
        final q1 = service.processVoiceQuery('Where is my bus?');
        final q2 = service.processVoiceQuery('Find a bus from VIT to Katpadi');
        final q3 = service.processVoiceQuery('Book a ticket');
        final q4 = service.processVoiceQuery('Emergency SOS help');
        final q5 = service.processVoiceQuery('Open my saved places');
        final q6 = service.processVoiceQuery('What can you do?');

        for (final resp in [q1, q2, q3, q4, q5, q6]) {
          expect(
            resp.spokenResponse.startsWith('Gemini Live:'),
            isFalse,
            reason: 'Robotic prefix should be removed: ${resp.spokenResponse}',
          );
          expect(resp.spokenResponse.isNotEmpty, isTrue);
        }
      },
    );

    test(
      'voice settings default to Aoede and can be configured with official voices',
      () {
        final controller = AppSettingsController.instance;
        controller.resetToDefaults();
        expect(controller.geminiVoice, equals('Aoede'));

        controller.updateGeminiVoice('Kore');
        expect(controller.geminiVoice, equals('Kore'));

        controller.updateGeminiVoice('Charon');
        expect(controller.geminiVoice, equals('Charon'));

        controller.resetToDefaults();
        expect(controller.geminiVoice, equals('Aoede'));
      },
    );
  });

  group('GeminiLiveScreen Widget Tests', () {
    testWidgets(
      'renders Gemini Live screen with header, visualizer orb, and prompt chips',
      (tester) async {
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

        expect(find.textContaining('Gemini Live key not set'), findsOneWidget);
        expect(find.text('Where is my bus?'), findsWidgets);
        expect(find.text('Find a bus from VIT to Katpadi'), findsOneWidget);
      },
    );

    testWidgets('tapping prompt chip processes voice query and updates output', (
      tester,
    ) async {
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

  group('booking personalization integration (Live tool results)', () {
    late _RecordingTransport transport;
    late LocalTransportRepository repository;
    late TicketController ticketController;

    Ticket nonDemoTicket(String id, String bus) => Ticket(
          id: id,
          routeId: 'vit-to-katpadi',
          routeName: 'VIT Main Gate → Katpadi',
          origin: const Stop(
            id: 'vit-main-gate',
            name: 'VIT Main Gate',
            area: 'VIT University',
          ),
          destination: const Stop(
            id: 'katpadi-railway-station',
            name: 'Katpadi Railway Station',
            area: 'Katpadi',
          ),
          busId: bus,
          passengerName: 'Passholder',
          passengerType: PassengerType.general,
          fareQuote: FareQuote.fromPaise(
            basePaise: 2500,
            passengerType: PassengerType.general,
            discountPercentage: 0,
          ),
          paymentMethod: PaymentMethod.upi,
          issuedAt: DateTime(2026, 10, 9, 10),
          validUntil: DateTime(2026, 10, 9, 14),
          qrCodeData: 'BUSBUDDY::secret-qr-$id',
          isDemo: false,
        );

    setUp(() {
      GeminiLiveSession.testValidateOverride = (key) async => null;
      AppSettingsController.instance.updateGeminiApiKey('test-key');
      AppSettingsController.instance.updateBookingPersonalization(false);
      AppSettingsController.instance.updatePreferredPassengerName('');
      AppSettingsController.instance.updateDefaultPassengerType(null);
      AppSettingsController.instance.savedPlaceStopIds = ['vit-main-gate'];
      repository = LocalTransportRepository(
        dataSource: LocalTransportDataSource(),
      );
      ticketController = TicketController(LocalTicketRepository());
    });

    tearDown(() {
      GeminiLiveSession.testValidateOverride = null;
      AppSettingsController.instance.updateGeminiApiKey('');
      AppSettingsController.instance.updateBookingPersonalization(false);
      AppSettingsController.instance.updatePreferredPassengerName('');
      AppSettingsController.instance.updateDefaultPassengerType(null);
    });

    Future<void> pumpConnectedScreen(WidgetTester tester) async {
      transport = _RecordingTransport();
      await tester.pumpWidget(
        MaterialApp(
          home: GeminiLiveScreen(
            transportFactory: () => transport,
            repository: repository,
            ticketController: ticketController,
          ),
        ),
      );
      await tester.pump();
      transport.serverSay!('{"setupComplete":{}}');
      // Let the gated mic path run and its silent-cycle guard settle so no
      // timer is left pending later.
      await tester.pump(const Duration(milliseconds: 4300));
    }

    List<Map<dynamic, dynamic>> toolOutputs() => transport.frames
        .map((f) => jsonDecode(f) as Map<String, dynamic>)
        .where((m) => m.containsKey('toolResponse'))
        .expand(
          (m) => (m['toolResponse'] as Map)['functionResponses'] as List,
        )
        .map((fr) => (fr as Map)['response']['output'] as Map)
        .toList();

    void serverSayToolCall(
      String id,
      String name, [
      Map<String, dynamic> args = const {},
    ]) {
      transport.serverSay!(jsonEncode({
        'toolCall': {
          'functionCalls': [
            {'id': id, 'name': name, 'args': args},
          ],
        },
      }));
    }

    testWidgets('bookingUsesOptedInContextAndNamesSuggestionSource', (
      tester,
    ) async {
      AppSettingsController.instance
        ..updateBookingPersonalization(true)
        ..updatePreferredPassengerName('Pavan')
        ..updateDefaultPassengerType(PassengerType.student);
      ticketController.addTicket(nonDemoTicket('TKT-ND9', 'Bus ND9'));

      await pumpConnectedScreen(tester);
      serverSayToolCall('bc-1', 'get_booking_context');
      await tester.pump();

      final output = toolOutputs().last;
      expect(output['success'], isTrue);
      final context = output['bookingContext'] as Map;
      // Profile fields arrive only because personalization is opted in.
      expect((context['profile'] as Map)['preferredName'], 'Pavan');
      expect(
        (context['profile'] as Map)['defaultPassengerType'],
        'student',
      );
      // The recent trip is suggested and NAMED as a suggestion through the
      // slot provenance, never as a passenger choice.
      expect(
        ((context['draft'] as Map)['slots'] as Map)['destination'],
        {'value': 'Katpadi Railway Station', 'source': 'recentActivity'},
      );
      expect(
        ((context['draft'] as Map)['slots'] as Map)['passengerType'],
        {'value': 'student', 'source': 'profileDefault'},
      );
      final trips = context['recentTrips'] as List;
      expect((trips.single as Map)['bus'], 'Bus ND9');

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    });

    testWidgets('optedOutBookingSendsNoProfileOrHistoryContext', (tester) async {
      AppSettingsController.instance
        ..updatePreferredPassengerName('Pavan')
        ..updateDefaultPassengerType(PassengerType.student);
      ticketController.addTicket(nonDemoTicket('TKT-ND9', 'Bus ND9'));

      await pumpConnectedScreen(tester);
      serverSayToolCall('bc-2', 'get_booking_context');
      await tester.pump();

      final output = toolOutputs().last;
      expect(output['success'], isTrue);
      final context = output['bookingContext'] as Map;
      // Opted out: nothing but the current draft facts.
      expect(context.keys, ['draft']);
      expect(
        context.toString().contains('Pavan'),
        isFalse,
        reason: 'the preferred name must never leak when opted out',
      );

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    });

    testWidgets('bookingCorrectionUpdatesVisibleDraft', (tester) async {
      await pumpConnectedScreen(tester);
      serverSayToolCall('t-1', 'set_trip', {
        'origin': 'VIT Main Gate',
        'destination': 'Katpadi Railway Station',
      });
      await tester.pump();
      serverSayToolCall('t-2', 'set_trip', {'origin': 'Katpadi Bus Stand'});
      await tester.pump();
      serverSayToolCall('bc-3', 'get_booking_context');
      await tester.pump();

      final context = toolOutputs().last['bookingContext'] as Map;
      final slots = (context['draft'] as Map)['slots'] as Map;
      // The correction replaced both the value and its provenance.
      expect(slots['origin'], {
        'value': 'Katpadi Bus Stand',
        'source': 'passenger',
      });

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    });

    testWidgets('checkoutWaitsForExplicitPaymentMethod', (tester) async {
      await pumpConnectedScreen(tester);
      serverSayToolCall('t-1', 'set_trip', {
        'origin': 'VIT Main Gate',
        'destination': 'Katpadi Railway Station',
      });
      await tester.pump();
      serverSayToolCall('b-1', 'select_bus', {'busId': '18B'});
      await tester.pump();
      serverSayToolCall('p-1', 'set_passenger', {
        'type': 'student',
        'name': 'Pavan',
      });
      await tester.pump();

      // The passenger never chose a payment method — confirm must not open
      // checkout even though the UPI fallback value sits in the draft.
      serverSayToolCall('c-1', 'confirm_booking');
      await tester.pump();

      final output = toolOutputs().last;
      expect(output['success'], isFalse);
      expect((output['missingSlots'] as List), contains('payment'));
      expect(output['draftComplete'], isFalse);
      expect(output['requiresConfirmation'], isFalse);
      expect(find.byType(TicketBookingSuitePage), findsNothing);

      // Only an explicit payment choice completes the booking.
      serverSayToolCall('pay-1', 'set_payment', {'method': 'card'});
      await tester.pump();
      serverSayToolCall('c-2', 'confirm_booking');
      await tester.pump();
      final ready = toolOutputs().last;
      expect(ready['draftComplete'], isTrue);
      expect(ready['requiresConfirmation'], isTrue);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    });
  });
}

/// Records every frame the screen's session sends and lets the test speak as
/// the Gemini server (same shape as the fake in key_connect_gate_test.dart).
class _RecordingTransport implements GeminiLiveTransport {
  final frames = <String>[];
  bool _open = false;
  void Function(String message)? serverSay;

  @override
  bool get isConnected => _open;

  @override
  void connect(
    String url, {
    required void Function() onOpen,
    required void Function(String message) onMessage,
    required void Function(Object error) onError,
    required void Function(int? code, String? reason) onClose,
  }) {
    _open = true;
    serverSay = onMessage;
    onOpen();
  }

  @override
  void send(String data) => frames.add(data);

  @override
  void close() => _open = false;
}
