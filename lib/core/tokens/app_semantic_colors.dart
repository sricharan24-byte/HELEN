import 'package:flutter/material.dart';

/// Semantic color role contract per Astra Section 3 / P0 Architecture Gates.
///
/// Ensures color usage is purposeful rather than hardcoded hex codes.
/// Every status role also maps to a non-color cue (icon/shape) per WCAG 1.4.1.
class AppSemanticColors {
  const AppSemanticColors({
    required this.background,
    required this.surface,
    required this.surfaceSubtle,
    required this.actionPrimary,
    required this.onActionPrimary,
    required this.actionSecondary,
    required this.onActionSecondary,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.borderFocus,
    required this.statusSuccess,
    required this.statusWarning,
    required this.statusError,
    required this.statusInfo,
    required this.isHighContrast,
  });

  final Color background;
  final Color surface;
  final Color surfaceSubtle;
  final Color actionPrimary;
  final Color onActionPrimary;
  final Color actionSecondary;
  final Color onActionSecondary;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color borderFocus;
  final Color statusSuccess;
  final Color statusWarning;
  final Color statusError;
  final Color statusInfo;
  final bool isHighContrast;

  Color get actionPrimaryText => onActionPrimary;
  Color get statusAlert => statusError;
  Color get statusAlertBg => statusError.withValues(alpha: 0.15);
  Color get statusSuccessBg => statusSuccess.withValues(alpha: 0.15);
  Color get statusInfoBg => statusInfo.withValues(alpha: 0.15);
  Color get statusWarningBg => statusWarning.withValues(alpha: 0.15);
  Color get surfaceBackground => background;
  Color get primaryBlue => actionPrimary;
  Color get surfaceCard => surface;
  Color get cardBorder => border;
  Color get cardBackground => surface;
  Color get successGreen => statusSuccess;
  Color get accentYellow => statusWarning;

  /// High-Contrast theme palette guaranteeing WCAG 2.2 AAA (7:1 contrast ratio).
  static const AppSemanticColors highContrast = AppSemanticColors(
    background: Color(0xFF000000), // Pure Black (21:1)
    surface: Color(0xFF121212),
    surfaceSubtle: Color(0xFF1E1E1E),
    actionPrimary: Color(
      0xFFFFD700,
    ), // Vibrant Gold (13.4:1 on surface, 15.0:1 on black, AAA >= 7:1)
    onActionPrimary: Color(0xFF000000),
    actionSecondary: Color(
      0xFF00FFFF,
    ), // Vibrant Cyan (15.0:1 on surface, 16.8:1 on black, AAA >= 7:1)
    onActionSecondary: Color(0xFF000000),
    textPrimary: Color(
      0xFFFFFFFF,
    ), // 18.7:1 on surface, 21.0:1 on pure black (AAA)
    textSecondary: Color(0xFFE2E8F0), // 15.2:1 on surface (AAA)
    textMuted: Color(0xFFCBD5E1), // 12.6:1 on surface (AAA)
    border: Color(0xFFFFFFFF), // High-visibility 2px white border
    borderFocus: Color(0xFFFFD700),
    statusSuccess: Color(
      0xFF00FF66,
    ), // High-contrast neon green (13.8:1 on surface, AAA)
    statusWarning: Color(
      0xFFFFD700,
    ), // High-contrast gold (13.4:1 on surface, AAA)
    statusError: Color(
      0xFFFF7575,
    ), // High-contrast coral red (7.18:1 on surface, 8.05:1 on black, AAA >= 7:1)
    statusInfo: Color(
      0xFF00FFFF,
    ), // High-contrast cyan (14.9:1 on surface, AAA)
    isHighContrast: true,
  );

  /// Default Accessible Dark theme palette (Corridor Midnight).
  static const AppSemanticColors dark = AppSemanticColors(
    background: Color(0xFF0B101D),
    surface: Color(0xFF1E293B),
    surfaceSubtle: Color(0xFF111C33),
    actionPrimary: Color(
      0xFF0369A1,
    ), // Ocean Blue (5.93:1 on white onActionPrimary, AA >= 4.5:1)
    onActionPrimary: Color(0xFFFFFFFF),
    actionSecondary: Color(0xFF38BDF8), // Sky Blue (6.83:1 on surface, AA)
    onActionSecondary: Color(0xFF0F172A), // (8.33:1 on actionSecondary, AAA)
    textPrimary: Color(0xFFF8FAFC), // 13.98:1 on surface (AAA)
    textSecondary: Color(0xFF94A3B8), // 5.71:1 on surface (AA >= 4.5:1)
    textMuted: Color(0xFF94A3B8), // 5.71:1 on surface (AA >= 4.5:1)
    border: Color(0xFF334155),
    borderFocus: Color(0xFF38BDF8),
    statusSuccess: Color(0xFF10B981), // 5.77:1 on surface (AA >= 4.5:1)
    statusWarning: Color(0xFFF59E0B), // 6.81:1 on surface (AA >= 4.5:1)
    statusError: Color(0xFFF87171), // 5.29:1 on surface (AA >= 4.5:1)
    statusInfo: Color(0xFF38BDF8), // 6.83:1 on surface (AA >= 4.5:1)
    isHighContrast: false,
  );

  /// Accessible Light theme palette (Daylight Transit).
  static const AppSemanticColors light = AppSemanticColors(
    background: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFF1F5F9),
    actionPrimary: Color(
      0xFF0369A1,
    ), // Accessible Ocean Blue (5.93:1 on white surface, 5.67:1 on bg, AA >= 4.5:1)
    onActionPrimary: Color(0xFFFFFFFF), // 5.93:1 against actionPrimary
    actionSecondary: Color(
      0xFF025A86,
    ), // Deep Ocean Blue (7.48:1 on white surface, AAA >= 7:1)
    onActionSecondary: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF0F172A), // 17.85:1 on surface, 17.06:1 on bg (AAA)
    textSecondary: Color(0xFF334155), // 10.35:1 on surface (AAA)
    textMuted: Color(0xFF475569), // 7.58:1 on surface (AAA >= 7:1)
    border: Color(0xFFCBD5E1),
    borderFocus: Color(0xFF0369A1), // 5.93:1 on surface
    statusSuccess: Color(
      0xFF047857,
    ), // Accessible Emerald 700 (5.48:1 on surface, AA >= 4.5:1)
    statusWarning: Color(
      0xFFB45309,
    ), // Accessible Amber 700 (5.02:1 on surface, AA >= 4.5:1)
    statusError: Color(
      0xFFDC2626,
    ), // Accessible Red 600 (4.83:1 on surface, AA >= 4.5:1)
    statusInfo: Color(
      0xFF0369A1,
    ), // Accessible Ocean Blue (5.93:1 on surface, AA >= 4.5:1)
    isHighContrast: false,
  );
}
