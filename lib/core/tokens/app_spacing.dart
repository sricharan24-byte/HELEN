import 'package:flutter/widgets.dart';

/// Semantic spacing and layout tokens for BusBuddy.
///
/// Mandates WCAG 2.2 minimum touch target constraints (48dp floor)
/// and consistent rhythm across all components.
abstract final class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;

  /// Absolute WCAG 2.2 Level AA / AAA floor for any interactive touch target.
  static const double minTouchTarget = 48.0;

  /// Minimum gap between adjacent interactive controls to prevent mis-taps.
  static const double controlGap = 12.0;

  /// Standard card corner radius.
  static const double radiusSm = 8.0;
  static const double radiusMd = 14.0;
  static const double radiusLg = 20.0;
  static const double radiusPill = 999.0;

  /// Padding insets.
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0);
}
