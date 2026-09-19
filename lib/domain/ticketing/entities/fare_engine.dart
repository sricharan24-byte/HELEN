import 'fare.dart';
import 'ticket.dart';

/// Authoritative Fare Calculation Engine for BusBuddy.
///
/// Implements exact integer paise arithmetic (1 Rupee = 100 Paise) per Astra audit P0.1.
///
/// Authoritative Precedence & Tier Table:
/// 1. Zero Hops (origin == destination):
///    - Throws [ArgumentError] / Invalid sequence. Same-stop ticketing is invalid.
/// 2. Standard Corridor (VIT Main Gate ↔ Katpadi Station):
///    - Traverses 4 hops (5 stops): Base fare 2000 paise (₹20.0).
///    - Rule ID: `RULE_CORRIDOR_V1`
/// 3. Short-hop (1 to 3 hops):
///    - Base fare 1500 paise (₹15.0).
///    - Rule ID: `RULE_HOP_SHORT_V1`
/// 4. Medium-hop (4 to 5 hops):
///    - Base fare 2000 paise (₹20.0).
///    - Rule ID: `RULE_HOP_MEDIUM_V1`
/// 5. Extended corridor (6+ hops):
///    - Base fare 2500 paise (₹25.0).
///    - Rule ID: `RULE_HOP_EXTENDED_V1`
///
/// Concession Rules:
/// - Student: 40% discount (pays 60% of base paise).
/// - Senior Citizen: 40% discount (pays 60% of base paise).
/// - General: 0% discount (pays 100% of base paise).
class FareEngine {
  const FareEngine._();

  /// Standard VIT ↔ Katpadi corridor base fare in integer paise (2000 paise = ₹20.0).
  static const int standardCorridorBasePaise = 2000;

  /// Concession discount percentage (40%).
  static const int concessionDiscountPercentage = 40;

  /// Calculates the fare given a base fare amount in double rupees and passenger type.
  /// Converts to integer paise internally for exact arithmetic without binary floating-point drift.
  static Fare calculateFromBase({
    required double baseFare,
    required PassengerType passengerType,
    int hopCount = 0,
    String ruleId = 'RULE_CUSTOM_BASE',
    String explanation = '',
  }) {
    final basePaise = (baseFare * 100).round();
    final discountPercent = switch (passengerType) {
      PassengerType.general => 0,
      PassengerType.student || PassengerType.senior => concessionDiscountPercentage,
    };

    final effectiveExplanation = explanation.isNotEmpty
        ? explanation
        : discountPercent > 0
            ? '${passengerType.name.toUpperCase()} concession ($discountPercent% discount) applied to base ₹${(basePaise / 100).toStringAsFixed(0)}.'
            : 'Standard general adult fare.';

    return Fare.fromPaise(
      basePaise: basePaise,
      passengerType: passengerType,
      discountPercentage: discountPercent,
      hopCount: hopCount,
      ruleId: ruleId,
      explanation: effectiveExplanation,
    );
  }

  /// Calculates the standard VIT ↔ Katpadi corridor fare (4 hops, 5 stops).
  static Fare calculateCorridorFare(PassengerType passengerType) {
    return calculateFromBase(
      baseFare: standardCorridorBasePaise / 100.0,
      passengerType: passengerType,
      hopCount: 4,
      ruleId: 'RULE_CORRIDOR_V1',
      explanation: 'VIT ↔ Katpadi Standard Corridor (4 hops, ₹20 base fare).',
    );
  }

  /// Calculates the fare based on the number of traversed hops (stops - 1).
  ///
  /// Rejects non-positive hops (hopCount <= 0) by throwing [ArgumentError]
  /// to satisfy Astra P0.1 boundary requirements.
  static Fare calculateByStopCount({
    required int stopCount,
    required PassengerType passengerType,
  }) {
    if (stopCount <= 0) {
      throw ArgumentError('Traversed stop count / hops must be at least 1.');
    }

    final int basePaise;
    final String ruleId;

    if (stopCount <= 3) {
      basePaise = 1500; // ₹15.0
      ruleId = 'RULE_HOP_SHORT_V1';
    } else if (stopCount <= 5) {
      basePaise = 2000; // ₹20.0
      ruleId = 'RULE_HOP_MEDIUM_V1';
    } else {
      basePaise = 2500; // ₹25.0
      ruleId = 'RULE_HOP_EXTENDED_V1';
    }

    return calculateFromBase(
      baseFare: basePaise / 100.0,
      passengerType: passengerType,
      hopCount: stopCount,
      ruleId: ruleId,
      explanation: 'Tier-based route fare for $stopCount traversed stops.',
    );
  }

  /// Calculates the fare between two stop indices along a route.
  static Fare calculateRouteFare({
    required int originIndex,
    required int destinationIndex,
    required PassengerType passengerType,
  }) {
    final hopsTraversed = (destinationIndex - originIndex).abs();
    if (hopsTraversed == 0) {
      throw ArgumentError('Origin and destination stop cannot be identical (0 hops).');
    }

    return calculateByStopCount(
      stopCount: hopsTraversed,
      passengerType: passengerType,
    );
  }
}
