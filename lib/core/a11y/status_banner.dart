import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../tokens/app_spacing.dart';
import '../tokens/status_level.dart';

/// Accessible multi-modal status banner per Astra Gate 6 & WCAG 1.4.1.
///
/// Ensures information is never conveyed by color alone by pairing
/// high-contrast color styling with explicit icons and semantic prefixes.
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.message,
    required this.level,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final StatusLevel level;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final statusColor = level.resolveColor(colors);

    return Semantics(
      container: true,
      liveRegion: true,
      label: '${level.semanticLabel}$message',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.isHighContrast ? colors.surface : statusColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: colors.isHighContrast ? colors.border : statusColor,
            width: colors.isHighContrast ? 2.0 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(level.icon, size: 22, color: statusColor),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(AppSpacing.minTouchTarget, AppSpacing.minTouchTarget),
                  foregroundColor: statusColor,
                ),
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
