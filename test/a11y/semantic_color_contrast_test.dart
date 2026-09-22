import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/core/tokens/app_semantic_colors.dart';

double srgbToLinear(double channel) {
  return channel <= 0.04045
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
}

double relativeLuminance(Color color) {
  final r = srgbToLinear(color.r);
  final g = srgbToLinear(color.g);
  final b = srgbToLinear(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double contrastRatio(Color c1, Color c2) {
  final l1 = relativeLuminance(c1);
  final l2 = relativeLuminance(c2);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('BUS-P1-09 Semantic Color WCAG Contrast Tests', () {
    test('High-Contrast theme satisfies WCAG AAA (>= 7.0:1) across all roles', () {
      const c = AppSemanticColors.highContrast;

      expect(c.isHighContrast, isTrue);

      // Text contrast against background and surface
      expect(contrastRatio(c.textPrimary, c.surface), greaterThanOrEqualTo(7.0));
      expect(contrastRatio(c.textPrimary, c.background), greaterThanOrEqualTo(7.0));
      expect(contrastRatio(c.textSecondary, c.surface), greaterThanOrEqualTo(7.0));
      expect(contrastRatio(c.textMuted, c.surface), greaterThanOrEqualTo(7.0));

      // Button action contrast
      expect(contrastRatio(c.onActionPrimary, c.actionPrimary), greaterThanOrEqualTo(7.0));
      expect(contrastRatio(c.onActionSecondary, c.actionSecondary), greaterThanOrEqualTo(7.0));

      // Status indicator contrast on surface
      expect(contrastRatio(c.statusSuccess, c.surface), greaterThanOrEqualTo(7.0));
      expect(contrastRatio(c.statusWarning, c.surface), greaterThanOrEqualTo(7.0));
      expect(contrastRatio(c.statusError, c.surface), greaterThanOrEqualTo(7.0));
      expect(contrastRatio(c.statusInfo, c.surface), greaterThanOrEqualTo(7.0));
    });

    test('Dark theme satisfies WCAG AA (>= 4.5:1) across all text & status roles', () {
      const c = AppSemanticColors.dark;

      expect(c.isHighContrast, isFalse);

      // Text contrast
      expect(contrastRatio(c.textPrimary, c.surface), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(c.textPrimary, c.background), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(c.textSecondary, c.surface), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(c.textMuted, c.surface), greaterThanOrEqualTo(4.5));

      // Button actions
      expect(contrastRatio(c.onActionPrimary, c.actionPrimary), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(c.onActionSecondary, c.actionSecondary), greaterThanOrEqualTo(4.5));

      // Status indicators
      expect(contrastRatio(c.statusSuccess, c.surface), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(c.statusWarning, c.surface), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(c.statusError, c.surface), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(c.statusInfo, c.surface), greaterThanOrEqualTo(4.5));
    });

    test('Light theme satisfies WCAG AA (>= 4.5:1) and AAA (>= 7.0:1) text', () {
      const c = AppSemanticColors.light;

      expect(c.isHighContrast, isFalse);

      // Text contrast against white and subtle background
      expect(contrastRatio(c.textPrimary, c.surface), greaterThanOrEqualTo(7.0)); // AAA
      expect(contrastRatio(c.textPrimary, c.background), greaterThanOrEqualTo(7.0)); // AAA
      expect(contrastRatio(c.textSecondary, c.surface), greaterThanOrEqualTo(7.0)); // AAA
      expect(contrastRatio(c.textMuted, c.surface), greaterThanOrEqualTo(4.5)); // AA

      // Button actions
      expect(contrastRatio(c.onActionPrimary, c.actionPrimary), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(c.onActionSecondary, c.actionSecondary), greaterThanOrEqualTo(4.5));

      // Status indicators
      expect(contrastRatio(c.statusSuccess, c.surface), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(c.statusWarning, c.surface), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(c.statusError, c.surface), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(c.statusInfo, c.surface), greaterThanOrEqualTo(4.5));
    });
  });
}
