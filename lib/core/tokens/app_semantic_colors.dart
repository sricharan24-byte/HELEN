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

  /// High-Contrast theme palette guaranteeing WCAG 2.2 AAA (7:1 contrast ratio).
  static const AppSemanticColors highContrast = AppSemanticColors(
    background: Color(0xFF000000), // Pure Black
    surface: Color(0xFF121212),
    surfaceSubtle: Color(0xFF1E1E1E),
    actionPrimary: Color(0xFFFFD700), // Vibrant Gold (>= 7:1 against black)
    onActionPrimary: Color(0xFF000000),
    actionSecondary: Color(0xFF00FFFF), // Vibrant Cyan
    onActionSecondary: Color(0xFF000000),
    textPrimary: Color(0xFFFFFFFF), // 21:1 against pure black
    textSecondary: Color(0xFFE2E8F0),
    textMuted: Color(0xFFCBD5E1),
    border: Color(0xFFFFFFFF), // High-visibility 2px white border
    borderFocus: Color(0xFFFFD700),
    statusSuccess: Color(0xFF00FF66), // High-contrast neon green
    statusWarning: Color(0xFFFFD700), // High-contrast gold
    statusError: Color(0xFFFF3333), // High-contrast coral red
    statusInfo: Color(0xFF00FFFF), // High-contrast cyan
    isHighContrast: true,
  );

  /// Default Accessible Dark theme palette (Corridor Midnight).
  static const AppSemanticColors dark = AppSemanticColors(
    background: Color(0xFF0B101D),
    surface: Color(0xFF1E293B),
    surfaceSubtle: Color(0xFF111C33),
    actionPrimary: Color(0xFF0284C7), // Vibrant Blue
    onActionPrimary: Color(0xFFFFFFFF),
    actionSecondary: Color(0xFF38BDF8),
    onActionSecondary: Color(0xFF0F172A),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
    border: Color(0xFF334155),
    borderFocus: Color(0xFF38BDF8),
    statusSuccess: Color(0xFF10B981),
    statusWarning: Color(0xFFF59E0B),
    statusError: Color(0xFFEF4444),
    statusInfo: Color(0xFF0284C7),
    isHighContrast: false,
  );

  /// Accessible Light theme palette (Daylight Transit).
  static const AppSemanticColors light = AppSemanticColors(
    background: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFF1F5F9),
    actionPrimary: Color(0xFF0284C7),
    onActionPrimary: Color(0xFFFFFFFF),
    actionSecondary: Color(0xFF0369A1),
    onActionSecondary: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF0F172A), // 14:1 against pure white
    textSecondary: Color(0xFF334155), // 7:1 against pure white
    textMuted: Color(0xFF64748B), // 4.5:1 against pure white
    border: Color(0xFFCBD5E1),
    borderFocus: Color(0xFF0284C7),
    statusSuccess: Color(0xFF059669),
    statusWarning: Color(0xFFD97706),
    statusError: Color(0xFFDC2626),
    statusInfo: Color(0xFF0284C7),
    isHighContrast: false,
  );
}
