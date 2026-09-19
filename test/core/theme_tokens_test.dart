import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busbuddy/core/theme/app_theme.dart';
import 'package:busbuddy/core/tokens/app_semantic_colors.dart';
import 'package:busbuddy/core/tokens/app_spacing.dart';
import 'package:busbuddy/core/tokens/status_level.dart';

void main() {
  group('Semantic Design Tokens & Spacing (Astra Step 2.1)', () {
    test('Minimum touch target conforms to WCAG 2.2 floor (48dp)', () {
      expect(AppSpacing.minTouchTarget, 48.0);
      expect(AppSpacing.controlGap, 12.0);
    });

    test('High-Contrast palette satisfies WCAG AAA 7:1 ratio attributes', () {
      const hc = AppSemanticColors.highContrast;
      expect(hc.isHighContrast, isTrue);
      expect(hc.background, const Color(0xFF000000)); // Pure black
      expect(hc.textPrimary, const Color(0xFFFFFFFF)); // 21:1 against black
      expect(hc.actionPrimary, const Color(0xFFFFD700)); // Vibrant Gold
      expect(hc.border, const Color(0xFFFFFFFF));
    });

    test('Status levels provide multi-modal cues (Icon + Non-color prefix) per WCAG 1.4.1', () {
      for (final level in StatusLevel.values) {
        expect(level.icon, isNotNull);
        expect(level.semanticLabel, isNotEmpty);
      }
      expect(StatusLevel.warning.semanticLabel, contains('Warning:'));
      expect(StatusLevel.error.semanticLabel, contains('Alert:'));
      expect(StatusLevel.success.semanticLabel, contains('Success:'));
    });
  });

  group('3-Theme Architecture', () {
    test('AppTheme generates valid ThemeData for High-Contrast, Dark, and Light', () {
      final hcTheme = AppTheme.highContrast;
      expect(hcTheme.brightness, Brightness.dark);
      expect(hcTheme.scaffoldBackgroundColor, const Color(0xFF000000));
      expect(hcTheme.filledButtonTheme.style?.minimumSize?.resolve({}), const Size(48, 48));

      final darkTheme = AppTheme.dark;
      expect(darkTheme.brightness, Brightness.dark);
      expect(darkTheme.scaffoldBackgroundColor, const Color(0xFF0B101D));

      final lightTheme = AppTheme.light;
      expect(lightTheme.brightness, Brightness.light);
      expect(lightTheme.scaffoldBackgroundColor, const Color(0xFFF8FAFC));
    });
  });
}
