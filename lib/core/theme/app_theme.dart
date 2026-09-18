import 'package:flutter/material.dart';

/// Shared theme for the BusBuddy application.
///
/// High-contrast accessible design system matching master project reference.
class AppTheme {
  AppTheme._();

  // ── Colour palette ─────────────────────────────────────────────────────

  static const Color _darkBackground = Color(0xFF0B101D);
  static const Color _primary = Color(0xFF0284C7); // Sky / Vibrant Blue
  static const Color _onPrimary = Color(0xFFFFFFFF);
  static const Color _onSurface = Color(0xFFF8FAFC);
  static const Color _outline = Color(0xFF334155);

  // ── Text themes ────────────────────────────────────────────────────────

  static const TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w400, color: _onSurface),
    displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w400, color: _onSurface),
    displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w400, color: _onSurface),
    headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: _onSurface),
    headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: _onSurface),
    headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: _onSurface),
    titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _onSurface),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _onSurface),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _onSurface),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: _onSurface),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: _onSurface),
    bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFF94A3B8)),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _onSurface),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _onSurface),
    labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
  );

  /// High-contrast accessible theme for BusBuddy.
  static ThemeData get light => dark; // Default to master dark theme

  static ThemeData get highContrast {
    const colorScheme = ColorScheme.dark(
      primary: Color(0xFFFFD700), // Vibrant Gold
      onPrimary: Colors.black,
      surface: Colors.black,
      onSurface: Colors.white,
      outline: Colors.white,
      secondary: Color(0xFF00FFFF), // Vibrant Cyan
      onSecondary: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.black,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 22,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: const Color(0xFFFFD700),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white, width: 2),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF121212),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white, width: 1.5),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
    );
  }

  static ThemeData get dark {
    final colorScheme = ColorScheme.dark(
      primary: _primary,
      onPrimary: _onPrimary,
      surface: _darkBackground,
      onSurface: _onSurface,
      outline: _outline,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: _textTheme,
      scaffoldBackgroundColor: _darkBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: _darkBackground,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: _textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 22,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: _textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
    );
  }
}
