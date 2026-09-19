import 'ticket.dart';

/// Pure-Dart Fare domain value object and quote.
///
/// Implements integer paise representation (1 Rupee = 100 Paise) per Astra audit P0.1
/// to eliminate binary floating-point drift on concessions, taxes, and multi-passenger aggregation.
class Fare {
  Fare({
    required this.amount,
    required this.baseFare,
    required this.passengerType,
    required this.discountPercentage,
    this.currency = '₹',
    int? basePaise,
    int? discountPaise,
    int? payablePaise,
    this.hopCount = 0,
    this.ruleId = 'RULE_DEFAULT',
    this.explanation = '',
  })  : basePaise = basePaise ?? (baseFare * 100).round(),
        discountPaise = discountPaise ?? ((baseFare - amount) * 100).round(),
        payablePaise = payablePaise ?? (amount * 100).round();

  /// Canonical factory computing exact integer paise arithmetic.
  factory Fare.fromPaise({
    required int basePaise,
    required PassengerType passengerType,
    required int discountPercentage,
    int hopCount = 0,
    String ruleId = 'RULE_CORRIDOR_V1',
    String explanation = '',
    String currency = '₹',
  }) {
    final cleanBasePaise = basePaise < 0 ? 0 : basePaise;
    final cleanDiscountPercent = discountPercentage.clamp(0, 100);
    // Nearest paise integer rounding: (basePaise * (100 - discount) + 50) ~/ 100
    final payablePaise = cleanDiscountPercent == 0
        ? cleanBasePaise
        : ((cleanBasePaise * (100 - cleanDiscountPercent) + 50) ~/ 100);
    final discountPaise = cleanBasePaise - payablePaise;

    return Fare(
      amount: payablePaise / 100.0,
      baseFare: cleanBasePaise / 100.0,
      passengerType: passengerType,
      discountPercentage: cleanDiscountPercent,
      currency: currency,
      basePaise: cleanBasePaise,
      discountPaise: discountPaise,
      payablePaise: payablePaise,
      hopCount: hopCount,
      ruleId: ruleId,
      explanation: explanation,
    );
  }

  /// The final payable amount in INR after discounts (e.g. ₹12.00).
  final double amount;

  /// The standard base fare before discounts (e.g. ₹20.00).
  final double baseFare;

  /// Base amount in integer paise (e.g. 2000 paise = ₹20.00).
  final int basePaise;

  /// Effective concession discount in integer paise (e.g. 800 paise = ₹8.00).
  final int discountPaise;

  /// Payable amount in integer paise (e.g. 1200 paise = ₹12.00).
  final int payablePaise;

  /// The passenger category (general, student, senior).
  final PassengerType passengerType;

  /// Discount percentage applied (0 for general, 40 for student/senior).
  final int discountPercentage;

  /// Number of traversed hops (adjacent stops = 1 hop).
  final int hopCount;

  /// Stable identifier/version of the applied pricing rule.
  final String ruleId;

  /// User-friendly explanation of the fare composition.
  final String explanation;

  /// Display currency symbol.
  final String currency;

  bool get isConcession => discountPercentage > 0;
  double get effectiveDiscountAmount => discountPaise / 100.0;
  String get formattedAmount => '$currency${amount.toStringAsFixed(0)}';
  String get formattedBaseFare => '$currency${baseFare.toStringAsFixed(0)}';
  String get formattedSavings => '$currency${effectiveDiscountAmount.toStringAsFixed(0)}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Fare &&
          runtimeType == other.runtimeType &&
          payablePaise == other.payablePaise &&
          basePaise == other.basePaise &&
          passengerType == other.passengerType &&
          discountPercentage == other.discountPercentage &&
          ruleId == other.ruleId;

  @override
  int get hashCode => Object.hash(
        payablePaise,
        basePaise,
        passengerType,
        discountPercentage,
        ruleId,
      );

  @override
  String toString() =>
      'Fare($formattedAmount, base: $formattedBaseFare, type: ${passengerType.name}, discount: $discountPercentage%, rule: $ruleId)';
}
