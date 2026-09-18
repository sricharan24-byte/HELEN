import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../core/settings/app_settings_controller.dart';
import '../../data/models/home_screen_item.dart';

/// Screen allowing commuters to reorder, show, hide, and reset
/// home screen component cards with full touch and screen-reader accessibility.
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
    SemanticsService.announce('Home screen layout reset to default order and all cards restored.', TextDirection.ltr);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Home screen layout reset to default settings.'),
        backgroundColor: Color(0xFF15803D),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _moveUp(int index, HomeScreenItem item) {
    if (index > 0) {
      _settings.moveHomeScreenItemUp(item.id);
      SemanticsService.announce(
        '${item.title} moved up to position $index of ${_settings.homeScreenItems.length}',
        TextDirection.ltr,
      );
    }
  }

  void _moveDown(int index, HomeScreenItem item) {
    if (index < _settings.homeScreenItems.length - 1) {
      _settings.moveHomeScreenItemDown(item.id);
      SemanticsService.announce(
        '${item.title} moved down to position ${index + 2} of ${_settings.homeScreenItems.length}',
        TextDirection.ltr,
      );
    }
  }

  void _toggleVisibility(HomeScreenItem item, bool isVisible) {
    _settings.toggleHomeScreenItemVisibility(item.id, isVisible);
    SemanticsService.announce(
      '${item.title} is now ${isVisible ? "visible" : "hidden"} on home screen',
      TextDirection.ltr,
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _settings.homeScreenItems;
    final visibleCount = items.where((e) => e.isVisible).length;

    return Scaffold(
      backgroundColor: const Color(0xFF0B101D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B101D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          tooltip: 'Back to Personalization Settings',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('Bus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                Text('Buddy', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w900, fontSize: 20)),
              ],
            ),
            const Text(
              'Customize Home Screen',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Semantics(
            button: true,
            label: 'Reset home screen layout to default',
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
              tooltip: 'Reset Layout',
              onPressed: _resetToDefaults,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  // ── Hero Guidance Card ───────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111C33),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0284C7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.dashboard_customize, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Customize Your Home',
                                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Rearrange cards in any order and choose which features appear.',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Accessibility & Usage Tip Box ───────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF2563EB),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.accessibility_new, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Drag cards using ≡ to reorder, or use the Move Up and Move Down buttons for TalkBack screen-reader navigation. Toggle the switch to show or hide any card.',
                            style: TextStyle(
                              color: Color(0xFF1E3A8A),
                              fontSize: 12,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
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
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _resetToDefaults,
                        icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF38BDF8)),
                        label: const Text(
                          'Reset',
                          style: TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.w700),
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
                    onReorder: (oldIndex, newIndex) {
                      _settings.reorderHomeScreenItem(oldIndex, newIndex);
                      SemanticsService.announce('Card reordered', TextDirection.ltr);
                    },
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _buildCustomizationTile(
                        key: ValueKey(item.id),
                        item: item,
                        index: index,
                        totalCount: items.length,
                      );
                    },
                  ),
                ],
              ),
            ),

            // ── Sticky Bottom Action Bar ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF111C33),
                border: Border(
                  top: BorderSide(color: Color(0xFF1E293B)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _resetToDefaults,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF94A3B8),
                        side: const BorderSide(color: Color(0xFF334155)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Home screen layout saved.'),
                            backgroundColor: Color(0xFF15803D),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        Navigator.of(context).pop();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
  }) {
    final isFirst = index == 0;
    final isLast = index == totalCount - 1;
    final isVisible = item.isVisible;

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isVisible ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isVisible ? const Color(0xFF334155) : const Color(0xFF1E293B),
        ),
      ),
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
                            color: isVisible ? Colors.white : const Color(0xFF64748B),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isVisible) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF334155),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Hidden',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      color: isVisible ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // ── Non-touch Accessible Reorder Controls ─────────────────
            Semantics(
              button: true,
              label: isFirst ? '${item.title} is at top' : 'Move ${item.title} up',
              child: IconButton(
                icon: Icon(
                  Icons.arrow_upward,
                  size: 20,
                  color: isFirst ? const Color(0xFF334155) : const Color(0xFF38BDF8),
                ),
                tooltip: isFirst ? null : 'Move Up',
                onPressed: isFirst ? null : () => _moveUp(index, item),
              ),
            ),
            Semantics(
              button: true,
              label: isLast ? '${item.title} is at bottom' : 'Move ${item.title} down',
              child: IconButton(
                icon: Icon(
                  Icons.arrow_downward,
                  size: 20,
                  color: isLast ? const Color(0xFF334155) : const Color(0xFF38BDF8),
                ),
                tooltip: isLast ? null : 'Move Down',
                onPressed: isLast ? null : () => _moveDown(index, item),
              ),
            ),

            // ── Visibility Switch ─────────────────────────────────────
            Semantics(
              label: 'Toggle ${item.title} visibility on home screen',
              child: Switch(
                value: isVisible,
                activeThumbColor: Colors.white,
                activeTrackColor: const Color(0xFF22C55E),
                inactiveThumbColor: const Color(0xFF64748B),
                inactiveTrackColor: const Color(0xFF1E293B),
                onChanged: (val) => _toggleVisibility(item, val),
              ),
            ),

            // ── Drag Handle ───────────────────────────────────────────
            Semantics(
              label: 'Drag to reorder ${item.title}',
              child: ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.only(left: 4, right: 4),
                  child: Icon(Icons.drag_handle, color: Color(0xFF64748B), size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
