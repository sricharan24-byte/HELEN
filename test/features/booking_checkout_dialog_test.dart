import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busbuddy/data/models/ticket_model.dart';
import 'package:busbuddy/data/models/transport_models.dart';
import 'package:busbuddy/features/tickets/booking_checkout_dialog.dart';

void main() {
  const origin = Stop(id: 'vit-main-gate', name: 'VIT Main Gate', area: 'VIT University');
  const destination = Stop(id: 'katpadi-railway-station', name: 'Katpadi Railway Station', area: 'Katpadi');

  testWidgets('BookingCheckoutDialog renders passenger options, payment options, and calculates student concession', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    Ticket? bookedTicket;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookingCheckoutDialog(
            busId: '18B',
            routeName: 'VIT → Katpadi',
            origin: origin,
            destination: destination,
            baseFare: 25.0,
            onTicketBooked: (t) {
              bookedTicket = t;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title and Subtitle
    expect(find.text('Confirm Ticket & Pay'), findsOneWidget);
    expect(find.textContaining('Bus 18B'), findsOneWidget);

    // Verify Default Passenger Type (General - ₹25) and Total Fare
    expect(find.text('General'), findsOneWidget);
    expect(find.text('TOTAL FARE'), findsOneWidget);

    // Select Student Passenger Type (40% concession => ₹15)
    await tester.tap(find.text('Student'));
    await tester.pumpAndSettle();

    // Select Wallet Payment Method
    await tester.tap(find.text('BusBuddy Wallet'));
    await tester.pumpAndSettle();

    // Enter passenger name (required for booking)
    await tester.enterText(find.byType(TextField), 'Pavan K');
    await tester.pumpAndSettle();

    // Tap Pay & Issue button
    await tester.tap(find.textContaining('& Issue'));
    await tester.pumpAndSettle();

    // Verify Ticket object was passed to callback with correct values.
    // Fare authority is FareEngine (BUS-P0-01): the 4-hop VIT ↔ Katpadi
    // corridor base is 2000 paise, so a 40% student concession issues
    // 1200 paise (₹12) regardless of the advisory baseFare hint.
    expect(bookedTicket, isNotNull);
    expect(bookedTicket!.busId, equals('18B'));
    expect(bookedTicket!.passengerName, equals('Pavan K'));
    expect(bookedTicket!.passengerType, equals(PassengerType.student));
    expect(bookedTicket!.paymentMethod, equals(PaymentMethod.wallet));
    expect(bookedTicket!.fareAmount, equals(12.0));
    expect(bookedTicket!.farePaise, equals(1200));
    expect(bookedTicket!.status, equals(TicketStatus.active));
  });

  testWidgets('BookingCheckoutDialog requires passenger name and blocks issue when empty', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    Ticket? bookedTicket;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookingCheckoutDialog(
            busId: '18B',
            routeName: 'VIT → Katpadi',
            origin: origin,
            destination: destination,
            baseFare: 25.0,
            onTicketBooked: (t) {
              bookedTicket = t;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify REQUIRED badge is shown
    expect(find.text('REQUIRED'), findsOneWidget);

    // Tap Pay & Issue without entering passenger name
    await tester.tap(find.textContaining('& Issue'));
    await tester.pumpAndSettle();

    // Verify ticket was NOT booked and error text is shown
    expect(bookedTicket, isNull);
    expect(find.text('Passenger name is required'), findsOneWidget);

    // Enter name
    await tester.enterText(find.byType(TextField), 'Aarav Sharma');
    await tester.pumpAndSettle();

    // Error text should disappear
    expect(find.text('Passenger name is required'), findsNothing);

    // Tap Pay & Issue now
    await tester.tap(find.textContaining('& Issue'));
    await tester.pumpAndSettle();

    // Verify ticket is now booked with entered name
    expect(bookedTicket, isNotNull);
    expect(bookedTicket!.passengerName, equals('Aarav Sharma'));
  });
}
