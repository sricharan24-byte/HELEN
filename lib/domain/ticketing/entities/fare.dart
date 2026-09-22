import 'package:flutter/foundation.dart';
import 'ticket.dart';

/// Pure-Dart FareQuote value object and domain contract.
///
/// Implements strictly integer paise representation (1 Rupee = 100 Paise)
/// per Astra audit BUS-P0-01 to eliminate binary floating-point drift on concessions,
/// taxes, and multi-passenger aggregation.
@immutable
class FareQuote {
  const FareQuote({
    required this.basePaise,
    required this.discountPaise,
    required this.finalPaise,
    required this.passengerType,
    required this.hopCount,
    required this.ruleVersion,
    this.explanation = '',
    this.currency = '₹',
  });

  /// Canonical factory computing exact integer paise arithmetic.
  factory FareQuote.fromPaise({
    required int basePaise,
    required PassengerType passengerType,
    required int discountPercentage,
    int hopCount = 0,
    String ruleVersion = 'RULE_CORRIDOR_V1',
    String? ruleId,
    String explanation = '',
    String currency = '₹',
  }) {
    final cleanBasePaise = basePaise < 0 ? 0 : basePaise;
    final cleanDiscountPercent = discountPercentage.clamp(0, 100);
    // Nearest paise integer rounding: (basePaise * (100 - discount) + 50) ~/ 100
    final finalPaise = cleanDiscountPercent == 0
        ? cleanBasePaise
        : ((cleanBasePaise * (100 - cleanDiscountPercent) + 50) ~/ 100);
    final discountPaise = cleanBasePaise - finalPaise;

    return FareQuote(
      basePaise: cleanBasePaise,
      discountPaise: discountPaise,
      finalPaise: finalPaise,
      passengerType: passengerType,
      hopCount: hopCount,
      ruleVersion: ruleId ?? ruleVersion,
      explanation: explanation,
      currency: currency,
    );
  }

  /// Base amount in integer paise (e.g. 2000 paise = ₹20.00).
  final int basePaise;

  /// Effective concession discount in integer paise (e.g. 800 paise = ₹8.00).
  final int discountPaise;

  /// Final payable amount in integer paise (e.g. 1200 paise = ₹12.00).
  final int finalPaise;

  /// The passenger category (general, student, senior).
  final PassengerType passengerType;

  /// Number of traversed hops (adjacent stops = 1 hop).
  final int hopCount;

  /// Stable identifier/version of the applied pricing rule.
  final String ruleVersion;

  /// User-friendly explanation of the fare composition.
  final String explanation;

  /// Display currency symbol.
  final String currency;

  // Compatibility and presentation helpers:
  int get payablePaise => finalPaise;
  int get discountPercentage =>
      basePaise > 0 ? (((discountPaise * 100) + (basePaise ~/ 2)) ~/ basePaise) : 0;
  bool get isConcession => discountPaise > 0;
  String get ruleId => ruleVersion;

  /// Presentation getters in rupees (strictly for UI formatting):
  double get amount => finalPaise / 100.0;
  double get baseFare => basePaise / 100.0;
  double get effectiveDiscountAmount => discountPaise / 100.0;
  String get formattedAmount => '$currency${(finalPaise / 100).toStringAsFixed(0)}';
  String get formattedBaseFare => '$currency${(basePaise / 100).toStringAsFixed(0)}';
  String get formattedSavings => '$currency${(discountPaise / 100).toStringAsFixed(0)}';

  Map<String, Object?> toJson() => {
        'basePaise': basePaise,
        'discountPaise': discountPaise,
        'finalPaise': finalPaise,
        'passengerType': passengerType.name,
        'hopCount': hopCount,
        'ruleVersion': ruleVersion,
        'explanation': explanation,
        'currency': currency,
      };

  factory FareQuote.fromJson(Map<String, dynamic> json) {
    return FareQuote(
      basePaise: (json['basePaise'] as num).toInt(),
      discountPaise: (json['discountPaise'] as num).toInt(),
      finalPaise: (json['finalPaise'] as num).toInt(),
      passengerType: PassengerType.values.byName(json['passengerType'] as String),
      hopCount: (json['hopCount'] as num).toInt(),
      ruleVersion: json['ruleVersion'] as String? ?? 'RULE_CORRIDOR_V1',
      explanation: json['explanation'] as String? ?? '',
      currency: json['currency'] as String? ?? '₹',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FareQuote &&
          runtimeType == other.runtimeType &&
          finalPaise == other.finalPaise &&
          basePaise == other.basePaise &&
          discountPaise == other.discountPaise &&
          passengerType == other.passengerType &&
          hopCount == other.hopCount &&
          ruleVersion == other.ruleVersion;

  @override
  int get hashCode => Object.hash(
        finalPaise,
        basePaise,
        discountPaise,
        passengerType,
        hopCount,
        ruleVersion,
      );

  @override
  String toString() =>
      'FareQuote($formattedAmount, base: $formattedBaseFare, type: ${passengerType.name}, hops: $hopCount, rule: $ruleVersion)';
}

/// Backward compatibility alias for FareQuote.
typedef Fare = FareQuote;

