import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'adaptive_ui_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/tokens/app_spacing.dart';
import '../../data/models/adaptive_shortcut.dart';

/// Modal bottom sheet allowing commuters to review, accept, dismiss, and reset
/// usage-based adaptive shortcuts with full TalkBack accessibility.
class AdaptiveShortcutsModal extends StatefulWidget {
  const AdaptiveShortcutsModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (_) => const AdaptiveShortcutsModal(),
    );
  }

  @override
  State<AdaptiveShortcutsModal> createState() => _AdaptiveShortcutsModalState();
}

class _AdaptiveShortcutsModalState extends State<AdaptiveShortcutsModal> {
  final AdaptiveUiService _adaptiveService = AdaptiveUiService.instance;

  @override
  void initState() {
    super.initState();
    _adaptiveService.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    _adaptiveService.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  void _accept(AdaptiveShortcut shortcut) {
    _adaptiveService.acceptShortcut(shortcut.id);
    final colors = AppTheme.colors(context);
    unawaited(SemanticsService.sendAnnouncement(View.of(context), '${shortcut.title} accepted and pinned to home screen shortcuts.', TextDirection.ltr));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pinned "${shortcut.title}" to your home shortcuts.'),
        backgroundColor: colors.statusSuccess,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _dismiss(AdaptiveShortcut shortcut) {
    _adaptiveService.dismissShortcut(shortcut.id);
    unawaited(SemanticsService.sendAnnouncement(View.of(context), '${shortcut.title} suggestion dismissed.', TextDirection.ltr));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Dismissed "${shortcut.title}".'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _remove(AdaptiveShortcut shortcut) {
    _adaptiveService.removeShortcut(shortcut.id);
    unawaited(SemanticsService.sendAnnouncement(View.of(context), '${shortcut.title} removed.', TextDirection.ltr));
  }

  void _clearAll() {
    _adaptiveService.resetAllLearningData();
    unawaited(SemanticsService.sendAnnouncement(View.of(context), 'All learning data and shortcuts cleared.', TextDirection.ltr));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('All adaptive shortcuts and learning history cleared.'),
        backgroundColor: AppTheme.colors(context).statusSuccess,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _confirmClearAll() {
    unawaited(showDialog<void>(
      context: context,
      builder: (ctx) {
        final colors = AppTheme.colors(context);
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Text('Clear all learned shortcuts?', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800)),
          content: Text(
            'This will reset your transit habits and remove all suggested shortcuts.',
            style: TextStyle(color: colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _clearAll();
              },
              style: FilledButton.styleFrom(backgroundColor: colors.statusError),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final shortcuts = _adaptiveService.allShortcuts
        .where((s) => s.status != AdaptiveShortcutStatus.dismissed)
        .toList();

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Adaptive Shortcuts',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Review and govern AI-learned habits',
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colors.textSecondary),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Shortcuts List or Empty State
            if (shortcuts.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Column(
                  children: [
                    Icon(Icons.lightbulb_outline, color: colors.textSecondary, size: 36),
                    const SizedBox(height: 10),
                    Text(
                      'No adaptive shortcuts yet',
                      style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'As you use BusBuddy, frequent journeys will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: shortcuts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _buildShortcutTile(shortcuts[index]),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // ── Footer Buttons ───────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _confirmClearAll,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.statusError,
                      side: BorderSide(color: colors.statusError.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Reset All Habits & Shortcuts', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.actionPrimary,
                      foregroundColor: colors.onActionPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutTile(AdaptiveShortcut shortcut) {
    final isAccepted = shortcut.isAccepted;
    final colors = AppTheme.colors(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: isAccepted ? colors.statusSuccess.withValues(alpha: 0.5) : colors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.actionPrimary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(shortcut.icon, color: colors.actionPrimary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        shortcut.title,
                        style: TextStyle(color: colors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isAccepted ? colors.statusSuccessBg : colors.statusInfoBg,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: Text(
                        isAccepted ? 'Pinned' : 'Suggested',
                        style: TextStyle(
                          color: isAccepted ? colors.statusSuccess : colors.statusInfo,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  shortcut.subtitle,
                  style: TextStyle(color: colors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          if (!isAccepted) ...[
            Semantics(
              button: true,
              label: 'Pin ${shortcut.title}',
              excludeSemantics: true,
              child: IconButton(
                icon: Icon(Icons.check_circle_outline, color: colors.statusSuccess, size: 22),
                tooltip: 'Pin Shortcut',
                onPressed: () => _accept(shortcut),
              ),
            ),
            Semantics(
              button: true,
              label: 'Dismiss ${shortcut.title}',
              excludeSemantics: true,
              child: IconButton(
                icon: Icon(Icons.cancel_outlined, color: colors.textSecondary, size: 22),
                tooltip: 'Dismiss',
                onPressed: () => _dismiss(shortcut),
              ),
            ),
          ] else ...[
            Semantics(
              button: true,
              label: 'Remove ${shortcut.title}',
              excludeSemantics: true,
              child: IconButton(
                icon: Icon(Icons.delete_outline, color: colors.statusError, size: 20),
                tooltip: 'Remove',
                onPressed: () => _remove(shortcut),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
