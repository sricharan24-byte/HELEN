import 'package:flutter/material.dart';

/// Astra P0.3 / WCAG 2.2 SC 1.4.4 & 1.4.10 compliant TextScaler decorator.
///
/// Preserves the platform's native, non-linear accessibility [TextScaler]
/// without flattening it to a linear multiplier or downscaling below the user's
/// operating system font size.
class EnlargingTextScaler implements TextScaler {
  const EnlargingTextScaler(this.parent, this.enlargementMultiplier)
      : assert(enlargementMultiplier >= 1.0, 'Enlargement multiplier must be >= 1.0 to prevent downscaling platform accessibility text.');

  final TextScaler parent;
  final double enlargementMultiplier;

  @override
  double scale(double fontSize) {
    final parentScaled = parent.scale(fontSize);
    // Guarantee that platform font size is never reduced.
    final effectiveMultiplier = enlargementMultiplier < 1.0 ? 1.0 : enlargementMultiplier;
    return parentScaled * effectiveMultiplier;
  }

  @override
  TextScaler clamp({double minScaleFactor = 0.0, double maxScaleFactor = double.infinity}) {
    // Astra P0.3: Never clamp platform scaling with an artificial upper ceiling.
    return this;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnlargingTextScaler &&
          runtimeType == other.runtimeType &&
          parent == other.parent &&
          enlargementMultiplier == other.enlargementMultiplier;

  @override
  int get hashCode => Object.hash(parent, enlargementMultiplier);
}
