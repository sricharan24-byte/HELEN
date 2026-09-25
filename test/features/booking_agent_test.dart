import 'package:busbuddy/data/models/ticket_model.dart';
import 'package:busbuddy/domain/assistant/assistant_command.dart';
import 'package:busbuddy/features/ai_assistant/app_automation_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Voice task agent — book ticket flow (Live Gemini only)', () {
    test('gateway registry exposes parameterized booking tools', () {
      for (final name in [
        'set_trip',
        'select_bus',
        'set_passenger',
        'set_payment',
        'confirm_booking',
      ]) {
        expect(AssistantCommandGateway.getMetadata(name), isNotNull,
            reason: 'missing tool $name');
      }
      // Safety gates preserved: only confirm_booking is confirmable.
      expect(AssistantCommandGateway.requiresConfirmation('set_trip'), isFalse);
      expect(
          AssistantCommandGateway.requiresConfirmation('select_bus'), isFalse);
      expect(AssistantCommandGateway.requiresConfirmation('set_passenger'),
          isFalse);
      expect(AssistantCommandGateway.requiresConfirmation('set_payment'),
          isFalse);
      expect(AssistantCommandGateway.requiresConfirmation('confirm_booking'),
          isTrue);

      // OpenAPI serialization includes parameters for slot tools.
      final decl = AssistantCommandGateway.getMetadata('set_trip')!
          .toFunctionDeclaration();
      expect(decl['name'], equals('set_trip'));
      expect((decl['parameters'] as Map)['properties'], contains('origin'));
      expect((decl['parameters'] as Map)['properties'],
          contains('destination'));
    });

    test('full slot chain reaches gateway without issuing ticket', () {
      final automation = AppAutomationController();

      var r = automation.handleToolCall('set_trip', {
        'origin': 'VIT Main Gate',
        'destination': 'Katpadi Railway Station',
      });
      expect(automation.origin?.name, contains('VIT'));
      expect(automation.destination?.name, contains('Katpadi'));
      expect(r.missingSlots, contains('passenger'));

      r = automation.handleToolCall('select_bus', {'busId': '18B'});
      expect(automation.busId, contains('18B'));

      r = automation.handleToolCall('set_passenger', {'type': 'student'});
      expect(automation.passengerType, equals(PassengerType.student));

      r = automation.handleToolCall('set_payment', {'method': 'upi'});
      expect(automation.paymentMethod, equals(PaymentMethod.upi));

      final ready = automation.handleToolCall('confirm_booking', null);
      expect(ready.isComplete, isTrue);
      expect(ready.needsGateway, isTrue);
      expect(ready.actionType, equals('confirm_booking'));
      // No ticket issued by the agent itself: readiness only opens gateway.
      expect(ready.spokenHint.toLowerCase(), contains('confirm'));
    });

    test('confirm_booking reports missing slots instead of navigating', () {
      final automation = AppAutomationController();
      final ready = automation.handleToolCall('confirm_booking', null);
      expect(ready.isComplete, isFalse);
      expect(ready.missingSlots, isNotEmpty);
    });

    test('tool response context echoes args and preserves confirm gate', () {
      final ctx = AssistantCommandGateway.buildToolResponseContext(
        'set_trip',
        {'origin': 'VIT Main Gate'},
      );
      expect(ctx['status'], equals('success'));
      expect(ctx['requiresConfirmation'], isFalse);
      expect((ctx['appliedArgs'] as Map)['origin'], equals('VIT Main Gate'));

      final gate = AssistantCommandGateway.buildToolResponseContext(
        'confirm_booking',
        {'busId': 'Bus 18B'},
      );
      expect(gate['status'], equals('requires_confirmation'));
      expect(gate['requiresConfirmation'], isTrue);
    });
  });
}
