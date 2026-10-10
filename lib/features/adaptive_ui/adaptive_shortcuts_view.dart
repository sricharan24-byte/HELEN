import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'adaptive_shortcuts_modal.dart';
import 'adaptive_ui_service.dart';
import '../../core/settings/app_settings_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/tokens/app_semantic_colors.dart';
import '../../core/tokens/app_spacing.dart';
import '../../data/models/adaptive_shortcut.dart';

/// Horizontal suggestion bar displayed on the HomePage when Adaptive UI is active.
class AdaptiveShortcutsView extends StatefulWidget {
  const AdaptiveShortcutsView({super.key, required this.onExecuteShortcut});

  final void Function(AdaptiveShortcut shortcut) onExecuteShortcut;

  @override
  State<AdaptiveShortcutsView> createState() => _AdaptiveShortcutsViewState();
}

class _AdaptiveShortcutsViewState extends State<AdaptiveShortcutsView> {
  final AdaptiveUiService _service = AdaptiveUiService.instance;
  final AppSettingsController _settings = AppSettingsController.instance;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onChanged);
    _settings.addListener(_onChanged);
  }

  @override
  void dispose() {
    _service.removeListener(_onChanged);
    _settings.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _pinShortcut(AdaptiveShortcut shortcut) {
    _service.acceptShortcut(shortcut.id);
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Pinned ${shortcut.title}',
        TextDirection.ltr,
      ),
    );
  }

  void _dismissShortcut(AdaptiveShortcut shortcut) {
    _service.dismissShortcut(shortcut.id);
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Dismissed ${shortcut.title}',
        TextDirection.ltr,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_settings.adaptiveUi) return const SizedBox.shrink();

    final shortcuts = _service.visibleShortcuts;
    if (shortcuts.isEmpty) return const SizedBox.shrink();

    final colors = AppTheme.colors(context);

    // Scale the horizontal strip height with the platform text scaler so card
    // content reflows at 200–300% accessibility text sizes (Astra BUS-P1-05).
    final shortcutStripHeight = MediaQuery.textScalerOf(context).scale(114.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section Header ─────────────────────────────────────────────
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: colors.actionSecondary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Suggested for You',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  onPressed: () => AdaptiveShortcutsModal.show(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(
                      AppSpacing.minTouchTarget,
                      AppSpacing.minTouchTarget,
                    ),
                  ),
                  child: Text(
                    'Manage',
                    style: TextStyle(
                      color: colors.actionSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (shortcuts.length > 1)
                  Row(
                    children: [
                      Icon(Icons.swipe, size: 16, color: colors.textSecondary),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          'Swipe for more',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ── Horizontal Scrollable Shortcut Cards ───────────────────────
        SizedBox(
          height: shortcutStripHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: shortcuts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final shortcut = shortcuts[index];
              return _buildShortcutCard(shortcut, colors);
            },
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildShortcutCard(
    AdaptiveShortcut shortcut,
    AppSemanticColors colors,
  ) {
    final isAccepted = shortcut.isAccepted;

    return Semantics(
      button: true,
      label:
          '${shortcut.title}. ${shortcut.subtitle}. Tap to execute shortcut.',
      excludeSemantics: true,
      child: Material(
        color: colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: InkWell(
          onTap: () => widget.onExecuteShortcut(shortcut),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: Container(
            width: 230,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(
                color: isAccepted
                    ? colors.statusSuccess.withValues(alpha: 0.6)
                    : colors.border,
                width: isAccepted ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top row: Icon & Status / Pin action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colors.actionPrimary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        shortcut.icon,
                        color: colors.actionPrimary,
                        size: 18,
                      ),
                    ),
                    if (isAccepted) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.statusSuccessBg,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              color: colors.statusSuccess,
                              size: 10,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Pinned',
                              style: TextStyle(
                                color: colors.statusSuccess,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Semantics(
                            button: true,
                            label: 'Pin ${shortcut.title}',
                            excludeSemantics: true,
                            child: IconButton(
                              icon: Icon(
                                Icons.check,
                                size: 18,
                                color: colors.statusSuccess,
                              ),
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              tooltip: 'Pin Shortcut',
                              onPressed: () => _pinShortcut(shortcut),
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: 'Dismiss ${shortcut.title}',
                            excludeSemantics: true,
                            child: IconButton(
                              icon: Icon(
                                Icons.close,
                                size: 18,
                                color: colors.textSecondary,
                              ),
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              tooltip: 'Dismiss',
                              onPressed: () => _dismissShortcut(shortcut),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),

                // Bottom details
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shortcut.title,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      shortcut.subtitle,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
