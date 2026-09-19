import 'ticket.dart';

/// Pure-Dart Fare domain value object.
/// Encapsulates base pricing, concessions, and currency display.
class Fare {
  const Fare({
    required this.amount,
    required this.baseFare,
    required this.passengerType,
    required this.discountPercentage,
    this.currency = '₹',
  });

  /// The final payable amount in INR after discounts.
  final double amount;

  /// The standard base fare before discounts.
  final double baseFare;

  /// The passenger category (general, student, senior).
  final PassengerType passengerType;

  /// Discount percentage applied (0 for general, 40 for student/senior).
  final int discountPercentage;

  /// Display currency symbol.
  final String currency;

  bool get isConcession => discountPercentage > 0;
  double get effectiveDiscountAmount => baseFare - amount;
  String get formattedAmount => '$currency${amount.toStringAsFixed(0)}';
  String get formattedBaseFare => '$currency${baseFare.toStringAsFixed(0)}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Fare &&
          runtimeType == other.runtimeType &&
          amount == other.amount &&
          baseFare == other.baseFare &&
          passengerType == other.passengerType &&
          discountPercentage == other.discountPercentage;

  @override
  int get hashCode => Object.hash(amount, baseFare, passengerType, discountPercentage);

  @override
  String toString() =>
      'Fare($formattedAmount, base: $formattedBaseFare, type: ${passengerType.name}, discount: $discountPercentage%)';
}
