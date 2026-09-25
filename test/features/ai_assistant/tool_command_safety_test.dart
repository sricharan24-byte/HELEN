import 'package:flutter_test/flutter_test.dart';
import 'package:busbuddy/domain/assistant/assistant_command.dart';
import 'package:busbuddy/features/ai_assistant/gemini_live_service.dart';

void main() {
  group('Assistant Command Safety Gateway Tests (BUS-P0-05)', () {
    test('strictly categorizes mutating and safety commands as requiresUserConfirmation', () {
      expect(AssistantCommandGateway.requiresConfirmation('emergency_sos'), isTrue);
      expect(AssistantCommandGateway.requiresConfirmation('share_location'), isTrue);
      expect(AssistantCommandGateway.requiresConfirmation('book_ticket'), isTrue);

      expect(AssistantCommandGateway.requiresConfirmation('track_bus'), isFalse);
      expect(AssistantCommandGateway.requiresConfirmation('search_route'), isFalse);
      expect(AssistantCommandGateway.requiresConfirmation('open_saved'), isFalse);
    });

    test('buildToolResponseContext returns requires_confirmation for confirmable actions', () {
      final sosContext = AssistantCommandGateway.buildToolResponseContext('emergency_sos');
      expect(sosContext['status'], equals('requires_confirmation'));
      expect(sosContext['requiresConfirmation'], isTrue);

      final bookContext = AssistantCommandGateway.buildToolResponseContext('book_ticket');
      expect(bookContext['status'], equals('requires_confirmation'));
      expect(bookContext['requiresConfirmation'], isTrue);

      final shareContext = AssistantCommandGateway.buildToolResponseContext('share_location');
      expect(shareContext['status'], equals('requires_confirmation'));
      expect(shareContext['requiresConfirmation'], isTrue);

      final trackContext = AssistantCommandGateway.buildToolResponseContext('track_bus');
      expect(trackContext['status'], equals('success'));
      expect(trackContext['requiresConfirmation'], isFalse);

      final routeContext = AssistantCommandGateway.buildToolResponseContext('search_route');
      expect(routeContext['status'], equals('success'));
      expect(routeContext['requiresConfirmation'], isFalse);
    });

    test('GeminiLiveService emits truthful gateway prompt without claiming premature completion', () {
      const service = GeminiLiveService();

      // SOS Emergency
      final sosResponse = service.processVoiceQuery('Emergency help! Call 112');
      expect(sosResponse.spokenResponse.toLowerCase(), contains('confirm'));
      expect(sosResponse.spokenResponse.toLowerCase(), isNot(contains('has been activated')));
      expect(sosResponse.spokenResponse.toLowerCase(), isNot(contains('already sent')));
      expect(sosResponse.actionType, equals('emergency_sos'));

      // Ticket Booking
      final bookingResponse = service.processVoiceQuery('I want to book a ticket');
      expect(bookingResponse.spokenResponse.toLowerCase(), contains('gateway'));
      expect(bookingResponse.spokenResponse.toLowerCase(), isNot(contains('ticket booked')));
      expect(bookingResponse.spokenResponse.toLowerCase(), isNot(contains('fare charged')));
      expect(bookingResponse.actionType, equals('book_ticket'));
    });

    test('gateway confirmation prompts use truthful button labels', () {
      final sosMeta = AssistantCommandGateway.getMetadata('emergency_sos');
      expect(sosMeta?.gatewayScreenPrompt, contains('Confirm SOS'));

      final bookMeta = AssistantCommandGateway.getMetadata('book_ticket');
      expect(bookMeta?.gatewayScreenPrompt, contains('Confirm Booking'));
    });
  });
}
