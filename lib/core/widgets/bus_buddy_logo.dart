import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../tokens/app_spacing.dart';

/// Compact, theme-aware BusBuddy brand mark for the Home screen.
class BusBuddyLogo extends StatelessWidget {
  const BusBuddyLogo({
    super.key,
    this.fontSize = 20,
    this.subtitle,
    this.subtitleColor,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final double fontSize;
  final String? subtitle;
  final Color? subtitleColor;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final logoRow = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: colors.actionPrimary,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Icon(
            Icons.directions_bus_filled_rounded,
            size: fontSize,
            color: colors.onActionPrimary,
          ),
        ),
        Text(
          'Bus',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: fontSize,
            letterSpacing: -0.3,
          ),
        ),
        Text(
          'Buddy',
          style: TextStyle(
            color: colors.actionPrimary,
            fontWeight: FontWeight.w800,
            fontSize: fontSize,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );

    Widget accessibleLogo() => Semantics(
      label: 'BusBuddy',
      image: true,
      child: ExcludeSemantics(child: logoRow),
    );

    if (subtitle == null) return accessibleLogo();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        accessibleLogo(),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle!,
          style: TextStyle(
            color: subtitleColor ?? colors.textSecondary,
            fontSize: fontSize * 0.58,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
