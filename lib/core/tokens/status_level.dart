import 'package:flutter/material.dart';
import 'app_semantic_colors.dart';

/// Semantic status severity level ensuring multi-modal feedback (Color + Icon + Label)
/// per WCAG 1.4.1 (Use of Color) and Astra Section 3 / Rule 2.
enum StatusLevel {
  success,
  warning,
  error,
  info;

  IconData get icon => switch (this) {
        StatusLevel.success => Icons.check_circle_outline,
        StatusLevel.warning => Icons.warning_amber_rounded,
        StatusLevel.error => Icons.error_outline_rounded,
        StatusLevel.info => Icons.info_outline_rounded,
      };

  String get semanticLabel => switch (this) {
        StatusLevel.success => 'Success: ',
        StatusLevel.warning => 'Warning: ',
        StatusLevel.error => 'Alert: ',
        StatusLevel.info => 'Notice: ',
      };

  Color resolveColor(AppSemanticColors colors) => switch (this) {
        StatusLevel.success => colors.statusSuccess,
        StatusLevel.warning => colors.statusWarning,
        StatusLevel.error => colors.statusError,
        StatusLevel.info => colors.statusInfo,
      };
}
