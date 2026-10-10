import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/tokens/app_spacing.dart';

class SettingsAskBusBuddyBar extends StatelessWidget {
  const SettingsAskBusBuddyBar({
    super.key,
    required this.message,
    required this.onTap,
  });

  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, AppSpacing.sm, 16, AppSpacing.md),
      child: Semantics(
        button: true,
        label: 'Ask BusBuddy. $message',
        excludeSemantics: true,
        child: Material(
          color: colors.actionPrimary,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: Container(
              constraints: const BoxConstraints(
                minHeight: AppSpacing.minTouchTarget,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.onActionPrimary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mic,
                      color: colors.onActionPrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ask BusBuddy',
                          style: TextStyle(
                            color: colors.onActionPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          message,
                          style: TextStyle(
                            color: colors.onActionPrimary.withValues(
                              alpha: 0.8,
                            ),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
