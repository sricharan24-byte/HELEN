import 'fare.dart';
import 'ticket.dart';

/// Authoritative Fare Calculation Engine for BusBuddy.
///
/// Eliminates conflicting hardcoded fare models across UI, AI prompts, and booking dialogs:
/// - Full Corridor standard base fare (VIT Main Gate ↔ Katpadi Station): ₹20.0
/// - Short-hop base fare (1–3 stops): ₹15.0
/// - Medium-hop base fare (4–5 stops): ₹20.0
/// - Extended corridor base fare (6+ stops): ₹25.0
///
/// Concession rules:
/// - Student: 40% discount (0.6 multiplier, rounded to whole rupee)
/// - Senior Citizen: 40% discount (0.6 multiplier, rounded to whole rupee)
/// - General: Standard base fare (0% discount)
///
/// Standard Corridor (VIT ↔ Katpadi) summary:
/// - General: ₹20
/// - Student Concession: ₹12
/// - Senior Concession: ₹12
class FareEngine {
  const FareEngine._();

  /// Default base fare for the VIT ↔ Katpadi corridor.
  static const double standardCorridorBaseFare = 20.0;

  /// Concession discount fraction (40%).
  static const double concessionDiscountRate = 0.40;

  /// Calculates the fare given a base fare amount and passenger type.
  static Fare calculateFromBase({
    required double baseFare,
    required PassengerType passengerType,
  }) {
    final cleanBase = baseFare < 0 ? 0.0 : baseFare;
    return switch (passengerType) {
      PassengerType.general => Fare(
          amount: cleanBase,
          baseFare: cleanBase,
          passengerType: passengerType,
          discountPercentage: 0,
        ),
      PassengerType.student || PassengerType.senior => Fare(
          amount: (cleanBase * (1.0 - concessionDiscountRate)).roundToDouble(),
          baseFare: cleanBase,
          passengerType: passengerType,
          discountPercentage: 40,
        ),
    };
  }

  /// Calculates the standard VIT ↔ Katpadi corridor fare.
  static Fare calculateCorridorFare(PassengerType passengerType) {
    return calculateFromBase(
      baseFare: standardCorridorBaseFare,
      passengerType: passengerType,
    );
  }

  /// Calculates the fare based on the number of traversed stops.
  static Fare calculateByStopCount({
    required int stopCount,
    required PassengerType passengerType,
  }) {
    final double baseFare;
    if (stopCount <= 3) {
      baseFare = 15.0;
    } else if (stopCount <= 5) {
      baseFare = 20.0;
    } else {
      baseFare = 25.0;
    }
    return calculateFromBase(
      baseFare: baseFare,
      passengerType: passengerType,
    );
  }

  /// Calculates the fare between two stop indices along a route.
  static Fare calculateRouteFare({
    required int originIndex,
    required int destinationIndex,
    required PassengerType passengerType,
  }) {
    final stopsTraversed = (destinationIndex - originIndex).abs();
    return calculateByStopCount(
      stopCount: stopsTraversed,
      passengerType: passengerType,
    );
  }
}
