import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../tokens/app_spacing.dart';

/// Accessible Button component per Astra Gate 4.
///
/// Features:
/// 1. Enforces WCAG 2.2 48×48dp minimum touch target floor structurally.
/// 2. Requires accessible semantic [label].
/// 3. Announces [disabledReason] to TalkBack/screen-readers when disabled.
/// 4. Provides high-contrast border and focus indication.
class AccessibleButton extends StatelessWidget {
  const AccessibleButton({
    super.key,
    required this.onPressed,
    required this.label,
    required this.child,
    this.disabledReason,
    this.icon,
    this.isSecondary = false,
    this.minWidth,
    this.height = 50.0,
  });

  final VoidCallback? onPressed;
  final String label;
  final Widget child;
  final String? disabledReason;
  final Widget? icon;
  final bool isSecondary;
  final double? minWidth;
  final double height;

  bool get isEnabled => onPressed != null;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final effectiveHeight = height < AppSpacing.minTouchTarget ? AppSpacing.minTouchTarget : height;

    final effectiveSemanticsLabel = isEnabled
        ? label
        : disabledReason != null && disabledReason!.isNotEmpty
            ? '$label, disabled: $disabledReason'
            : '$label, disabled';

    Widget buttonWidget;

    if (isSecondary) {
      buttonWidget = OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(minWidth ?? AppSpacing.minTouchTarget, effectiveHeight),
          foregroundColor: colors.textPrimary,
          side: BorderSide(
            color: isEnabled ? colors.border : colors.border.withValues(alpha: 0.3),
            width: colors.isHighContrast ? 2.0 : 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
        onPressed: onPressed,
        child: _buildButtonContent(context),
      );
    } else {
      buttonWidget = FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: Size(minWidth ?? AppSpacing.minTouchTarget, effectiveHeight),
          backgroundColor: isEnabled ? colors.actionPrimary : colors.surfaceSubtle,
          foregroundColor: isEnabled ? colors.onActionPrimary : colors.textMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            side: colors.isHighContrast
                ? BorderSide(color: isEnabled ? colors.border : colors.border.withValues(alpha: 0.4), width: 2)
                : BorderSide.none,
          ),
        ),
        onPressed: onPressed,
        child: _buildButtonContent(context),
      );
    }

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: effectiveSemanticsLabel,
      child: buttonWidget,
    );
  }

  Widget _buildButtonContent(BuildContext context) {
    if (icon == null) return child;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        icon!,
        const SizedBox(width: AppSpacing.sm),
        Flexible(child: child),
      ],
    );
  }
}
