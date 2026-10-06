import 'package:flutter/material.dart';

import '../../core/a11y/announcement_coordinator.dart';
import '../../core/settings/app_settings_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/tokens/app_semantic_colors.dart';
import '../../core/tokens/app_spacing.dart';
import '../../data/models/home_screen_item.dart';

/// Screen allowing commuters to reorder, show, hide, and reset
/// home screen component cards with full touch and screen-reader accessibility.
/// Conforms to Astra Step 2.7 with semantic design tokens, 48dp touch targets,
/// non-drag accessible reordering, and AnnouncementCoordinator integration.
class HomeScreenCustomizationPage extends StatefulWidget {
  const HomeScreenCustomizationPage({super.key});

  @override
  State<HomeScreenCustomizationPage> createState() => _HomeScreenCustomizationPageState();
}

class _HomeScreenCustomizationPageState extends State<HomeScreenCustomizationPage> {
  final AppSettingsController _settings = AppSettingsController.instance;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  void _resetToDefaults() {
    _settings.resetHomeScreenLayout();
    AnnouncementCoordinator.instance.announce(
      'Home screen layout reset to default order and all cards restored.',
      priority: AnnouncementPriority.normal,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Home screen layout reset to default settings.'),
        backgroundColor: AppTheme.colors(context).statusSuccess,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _moveUp(int index, HomeScreenItem item) {
    if (index > 0) {
      _settings.moveHomeScreenItemUp(item.id);
      AnnouncementCoordinator.instance.announce(
        '${item.title} moved up to position $index of ${_settings.homeScreenItems.length}',
        priority: AnnouncementPriority.normal,
      );
    }
  }

  void _moveDown(int index, HomeScreenItem item) {
    if (index < _settings.homeScreenItems.length - 1) {
      _settings.moveHomeScreenItemDown(item.id);
      AnnouncementCoordinator.instance.announce(
        '${item.title} moved down to position ${index + 2} of ${_settings.homeScreenItems.length}',
        priority: AnnouncementPriority.normal,
      );
    }
  }

  void _toggleVisibility(HomeScreenItem item, bool isVisible) {
    _settings.toggleHomeScreenItemVisibility(item.id, isVisible);
    AnnouncementCoordinator.instance.announce(
      '${item.title} is now ${isVisible ? "visible" : "hidden"} on home screen',
      priority: AnnouncementPriority.normal,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final items = _settings.homeScreenItems;
    final visibleCount = items.where((e) => e.isVisible).length;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: colors.textPrimary, size: 20),
          tooltip: 'Back to Personalization Settings',
          onPressed: () => Navigator.of(context).pop(),
          constraints: const BoxConstraints(
            minWidth: AppSpacing.minTouchTarget,
            minHeight: AppSpacing.minTouchTarget,
          ),
        ),
        // Single reflow-safe title: the two-line brand Column overflowed at
        // large text scales; the guidance hero below carries the details.
        title: Text(
          'Customize Home Screen',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  // ── Hero Guidance Card ─────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colors.actionPrimary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.dashboard_customize, color: colors.actionPrimaryText, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  'Customize Your Home',
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Drag cards using ≡ to reorder, or use the accessible up/down buttons. Toggle switches to show or hide cards.',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 12.5,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Visibility Counter Pill ─────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Home Screen Cards ($visibleCount of ${items.length} visible)',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _resetToDefaults,
                        icon: Icon(Icons.refresh, size: 16, color: colors.actionPrimary),
                        label: Text(
                          'Reset',
                          style: TextStyle(color: colors.actionPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, AppSpacing.minTouchTarget),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ── Reorderable List of Home Screen Items ───────────────────
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    onReorderItem: (oldIndex, newIndex) {
                      _settings.reorderHomeScreenItem(oldIndex, newIndex);
                      AnnouncementCoordinator.instance.announce(
                        'Card reordered',
                        priority: AnnouncementPriority.low,
                      );
                    },
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _buildCustomizationTile(
                        key: ValueKey(item.id),
                        item: item,
                        index: index,
                        totalCount: items.length,
                        colors: colors,
                      );
                    },
                  ),
                ],
              ),
            ),

            // ── Sticky Bottom Action Bar ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  top: BorderSide(color: colors.border),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _resetToDefaults,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textSecondary,
                        side: BorderSide(color: colors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        minimumSize: const Size(100, AppSpacing.minTouchTarget),
                      ),
                      icon: const Icon(Icons.restore, size: 20),
                      label: const Text(
                        'Reset Layout',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        AnnouncementCoordinator.instance.announce(
                          'Home screen layout saved.',
                          priority: AnnouncementPriority.normal,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Home screen layout saved.'),
                            backgroundColor: colors.statusSuccess,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        Navigator.of(context).pop();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.actionPrimary,
                        foregroundColor: colors.actionPrimaryText,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        minimumSize: const Size(100, AppSpacing.minTouchTarget),
                      ),
                      icon: const Icon(Icons.check, size: 20),
                      label: const Text(
                        'Done',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomizationTile({
    required Key key,
    required HomeScreenItem item,
    required int index,
    required int totalCount,
    required AppSemanticColors colors,
  }) {
    final isFirst = index == 0;
    final isLast = index == totalCount - 1;
    final isVisible = item.isVisible;

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isVisible ? colors.surface : colors.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: isVisible ? colors.border : colors.border.withValues(alpha: 0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // ── Icon Bubble ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isVisible ? item.color : item.color.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  item.icon,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),

              // ── Title & Subtitle ──────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              color: isVisible ? colors.textPrimary : colors.textSecondary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!isVisible) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: colors.border,
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusSm),
                            ),
                            child: Text(
                              'Hidden',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // ── Move Up Button (Screen-Reader / Motor Alternative) ───
              IconButton(
                icon: Icon(
                  Icons.arrow_upward,
                  size: 18,
                  color: isFirst ? colors.textSecondary.withValues(alpha: 0.3) : colors.textSecondary,
                ),
                tooltip: 'Move Up',
                constraints: const BoxConstraints(
                  minWidth: AppSpacing.minTouchTarget,
                  minHeight: AppSpacing.minTouchTarget,
                ),
                onPressed: isFirst ? null : () => _moveUp(index, item),
              ),

              // ── Move Down Button (Screen-Reader / Motor Alternative) ─
              IconButton(
                icon: Icon(
                  Icons.arrow_downward,
                  size: 18,
                  color: isLast ? colors.textSecondary.withValues(alpha: 0.3) : colors.textSecondary,
                ),
                tooltip: 'Move Down',
                constraints: const BoxConstraints(
                  minWidth: AppSpacing.minTouchTarget,
                  minHeight: AppSpacing.minTouchTarget,
                ),
                onPressed: isLast ? null : () => _moveDown(index, item),
              ),

              // ── Visibility Switch ───────────────────────────────────
              Semantics(
                label: '${item.title} visibility',
                child: Switch(
                  value: isVisible,
                  activeThumbColor: Colors.white,
                  activeTrackColor: colors.statusSuccess,
                  inactiveThumbColor: Colors.white60,
                  inactiveTrackColor: colors.border,
                  onChanged: (val) => _toggleVisibility(item, val),
                ),
              ),

              // ── Reorder Drag Handle (≡) ─────────────────────────────
              // 48x48 tappable: the bare 22dp icon was far below the WCAG
              // touch-target floor.
              ReorderableDragStartListener(
                index: index,
                child: SizedBox(
                  width: AppSpacing.minTouchTarget,
                  height: AppSpacing.minTouchTarget,
                  child: Icon(
                    Icons.drag_handle,
                    color: colors.textSecondary,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
