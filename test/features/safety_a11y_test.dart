import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/core/a11y/announcement_coordinator.dart';
import 'package:busbuddy/data/models/ticket_model.dart';
import 'package:busbuddy/data/models/transport_models.dart';
import 'package:busbuddy/data/repositories/emergency_contact_repository.dart';
import 'package:busbuddy/features/safety/safety_sharing_page.dart';

void main() {
  group('Astra Gate 12: Safety & Emergency Accessibility Tests', () {
    setUp(() {
      AnnouncementCoordinator.instance.resetForTesting();
    });

    testWidgets('renders Gate 12 non-voice emergency SOS and triggers urgent announcement', (tester) async {
      String? lastAnnouncement;
      AnnouncementPriority? lastPriority;

      AnnouncementCoordinator.instance.testAnnounceHandler = (message, priority) {
        lastAnnouncement = message;
        lastPriority = priority;
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const SafetySharingPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Find the SOS broadcast button
      final sosButton = find.text('BROADCAST SOS ALERT NOW');
      expect(sosButton, findsOneWidget);

      // Tap SOS button to open confirmation dialog
      await tester.tap(sosButton);
      await tester.pumpAndSettle();

      // Verify non-voice alternative explanation is displayed
      expect(find.textContaining('Non-voice alternative'), findsOneWidget);
      expect(find.text('Trigger SOS Alert?'), findsOneWidget);

      // Confirm SOS alert
      final recordSosButton = find.text('RECORD SIMULATED SOS');
      expect(recordSosButton, findsOneWidget);
      await tester.tap(recordSosButton);
      await tester.pumpAndSettle();

      // Verify urgent announcement was dispatched to AnnouncementCoordinator
      expect(lastAnnouncement, contains('Emergency SOS alert broadcasted'));
      expect(lastPriority, equals(AnnouncementPriority.urgent));
    });

    testWidgets('renders active ticket live sharing and contact action buttons with 48dp touch targets', (tester) async {
      final ticket = Ticket(
        id: 'TKT-TEST-99',
        routeId: 'vit-to-katpadi',
        routeName: 'VIT → Katpadi',
        origin: const Stop(id: 'vit', name: 'VIT Main Gate', area: 'Vellore'),
        destination: const Stop(id: 'katpadi', name: 'Katpadi Railway Station', area: 'Katpadi'),
        busId: 'Bus 23',
        passengerName: 'Pavan',
        passengerType: PassengerType.general,
        fareAmount: 15.0,
        paymentMethod: PaymentMethod.upi,
        issuedAt: DateTime.now(),
        validUntil: DateTime.now().add(const Duration(hours: 2)),
        qrCodeData: 'QR-TEST',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: SafetySharingPage(activeTicket: ticket),
        ),
      );
      await tester.pumpAndSettle();

      // Verify active trip section is rendered
      expect(find.text('ACTIVE TRIP LIVE SHARING'), findsOneWidget);
      expect(find.text('Bus Bus 23'), findsOneWidget);

      // Verify WhatsApp share button has adequate touch target height >= 48dp
      final shareBtnFinder = find.widgetWithText(OutlinedButton, 'Share Live Trip via WhatsApp / SMS');
      expect(shareBtnFinder, findsOneWidget);
      final shareBtnSize = tester.getSize(shareBtnFinder);
      expect(shareBtnSize.height, greaterThanOrEqualTo(48.0));

      // Verify emergency contacts phone buttons have >= 48x48dp bounds
      final phoneButtons = find.byIcon(Icons.phone);
      expect(phoneButtons, findsWidgets);
      final firstPhoneSize = tester.getSize(phoneButtons.first);
      expect(firstPhoneSize.width, greaterThanOrEqualTo(48.0));
      expect(firstPhoneSize.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('adding an emergency contact announces confirmation', (tester) async {
      String? announcedText;
      AnnouncementCoordinator.instance.testAnnounceHandler = (message, priority) {
        announcedText = message;
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const SafetySharingPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Add Contact button
      await tester.tap(find.text('Add Contact'));
      await tester.pumpAndSettle();

      // Check dialog content explaining Astra Gate 12
      expect(find.textContaining('Astra Gate 12: Emergency contacts'), findsOneWidget);

      // Enter name and phone
      await tester.enterText(find.widgetWithText(TextField, 'Contact Name / Title'), 'Security Desk');
      await tester.enterText(find.widgetWithText(TextField, 'Phone Number (+91)'), '9876543210');
      await tester.pumpAndSettle();

      // Tap Add Contact dialog submit button
      await tester.tap(find.widgetWithText(FilledButton, 'Add Contact'));
      await tester.pumpAndSettle();

      expect(announcedText, contains('Added emergency contact Security Desk'));
    });
  });
}
