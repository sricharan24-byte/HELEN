import 'package:flutter/material.dart';
import '../tokens/app_semantic_colors.dart';
import '../tokens/app_spacing.dart';

/// Centralized Accessible Theme System for BusBuddy.
///
/// Implements 3 distinct, fully-accessible themes per Astra Section 3:
/// 1. [light]: Daylight Transit theme with >= 4.5:1 / 7:1 text contrast.
/// 2. [dark]: Corridor Midnight theme with deep contrast and low eye fatigue.
/// 3. [highContrast]: Strict WCAG 2.2 AAA (7:1 contrast) theme with pure blacks and vibrant gold/cyan.
///
/// All interactive controls enforce the 48×48dp minimum touch target floor.
class AppTheme {
  AppTheme._();

  static const _fontFamily = 'Roboto';

  /// Resolves the semantic colors for the current theme context.
  static AppSemanticColors colors(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.light) {
      return AppSemanticColors.light;
    }
    final isHC = theme.colorScheme.primary == const Color(0xFFFFD700);
    return isHC ? AppSemanticColors.highContrast : AppSemanticColors.dark;
  }

  // ── 1. High-Contrast Theme (WCAG AAA 7:1) ──────────────────────────────────
  static ThemeData get highContrast {
    const c = AppSemanticColors.highContrast;
    final colorScheme = ColorScheme.dark(
      primary: c.actionPrimary,
      onPrimary: c.onActionPrimary,
      surface: c.surface,
      onSurface: c.textPrimary,
      outline: c.border,
      secondary: c.actionSecondary,
      onSecondary: c.onActionSecondary,
      error: c.statusError,
      onError: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: c.background,
      fontFamily: _fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: c.textPrimary,
          fontWeight: FontWeight.w900,
          fontSize: 22,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(AppSpacing.minTouchTarget, AppSpacing.minTouchTarget),
          backgroundColor: c.actionPrimary,
          foregroundColor: c.onActionPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            side: BorderSide(color: c.border, width: 2),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(AppSpacing.minTouchTarget, AppSpacing.minTouchTarget),
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.border, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: c.border, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: c.border, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: c.borderFocus, width: 3),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(color: c.border, width: 2),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
    );
  }

  // ── 2. Dark Theme (Corridor Midnight) ──────────────────────────────────────
  static ThemeData get dark {
    const c = AppSemanticColors.dark;
    final colorScheme = ColorScheme.dark(
      primary: c.actionPrimary,
      onPrimary: c.onActionPrimary,
      surface: c.surface,
      onSurface: c.textPrimary,
      outline: c.border,
      secondary: c.actionSecondary,
      onSecondary: c.onActionSecondary,
      error: c.statusError,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: c.background,
      fontFamily: _fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 22,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(AppSpacing.minTouchTarget, AppSpacing.minTouchTarget),
          backgroundColor: c.actionPrimary,
          foregroundColor: c.onActionPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(AppSpacing.minTouchTarget, AppSpacing.minTouchTarget),
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.border, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: c.borderFocus, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(color: c.border),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
    );
  }

  // ── 3. Light Theme (Daylight Transit) ──────────────────────────────────────
  static ThemeData get light {
    const c = AppSemanticColors.light;
    final colorScheme = ColorScheme.light(
      primary: c.actionPrimary,
      onPrimary: c.onActionPrimary,
      surface: c.surface,
      onSurface: c.textPrimary,
      outline: c.border,
      secondary: c.actionSecondary,
      onSecondary: c.onActionSecondary,
      error: c.statusError,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: c.background,
      fontFamily: _fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: Color(0xFF0F172A),
          fontWeight: FontWeight.w800,
          fontSize: 22,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(AppSpacing.minTouchTarget, AppSpacing.minTouchTarget),
          backgroundColor: c.actionPrimary,
          foregroundColor: c.onActionPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(AppSpacing.minTouchTarget, AppSpacing.minTouchTarget),
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.border, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: c.borderFocus, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(color: c.border),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
    );
  }
}
