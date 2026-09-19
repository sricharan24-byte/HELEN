import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'adaptive_ui_service.dart';
import '../../data/models/adaptive_shortcut.dart';

/// Modal bottom sheet allowing commuters to review, accept, dismiss, and reset
/// usage-based adaptive shortcuts with full TalkBack accessibility.
class AdaptiveShortcutsModal extends StatefulWidget {
  const AdaptiveShortcutsModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B101D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
    SemanticsService.announce('${shortcut.title} accepted and pinned to home screen shortcuts.', TextDirection.ltr);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pinned "${shortcut.title}" to your home shortcuts.'),
        backgroundColor: const Color(0xFF15803D),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _dismiss(AdaptiveShortcut shortcut) {
    _adaptiveService.dismissShortcut(shortcut.id);
    SemanticsService.announce('${shortcut.title} suggestion dismissed.', TextDirection.ltr);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Dismissed "${shortcut.title}".'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _remove(AdaptiveShortcut shortcut) {
    _adaptiveService.removeShortcut(shortcut.id);
    SemanticsService.announce('${shortcut.title} removed.', TextDirection.ltr);
  }

  void _clearAll() {
    _adaptiveService.resetAllLearningData();
    SemanticsService.announce('All learning data and shortcuts cleared.', TextDirection.ltr);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All adaptive shortcuts and learning history cleared.'),
        backgroundColor: Color(0xFF15803D),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Clear all learned shortcuts?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: const Text(
          'This will reset your transit habits and remove all suggested shortcuts.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _clearAll();
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  color: const Color(0xFF475569),
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
                  children: const [
                    Text(
                      'Adaptive Shortcuts',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Review and govern AI-learned habits',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
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
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: const [
                    Icon(Icons.lightbulb_outline, color: Color(0xFF94A3B8), size: 36),
                    SizedBox(height: 10),
                    Text(
                      'No adaptive shortcuts yet',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'As you use BusBuddy, frequent journeys will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: shortcuts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFF7F1D1D)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111C33),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAccepted ? const Color(0xFF16A34A).withValues(alpha: 0.5) : const Color(0xFF1E293B),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: shortcut.color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(shortcut.icon, color: shortcut.color, size: 20),
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
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isAccepted ? const Color(0xFF14532D) : const Color(0xFF1E3A8A),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isAccepted ? 'Pinned' : 'Suggested',
                        style: TextStyle(
                          color: isAccepted ? const Color(0xFF86EFAC) : const Color(0xFF93C5FD),
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
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
              ],
            ),
          ),
          if (!isAccepted) ...[
            Semantics(
              button: true,
              label: 'Pin ${shortcut.title}',
              child: IconButton(
                icon: const Icon(Icons.check_circle_outline, color: Color(0xFF22C55E), size: 22),
                tooltip: 'Pin Shortcut',
                onPressed: () => _accept(shortcut),
              ),
            ),
            Semantics(
              button: true,
              label: 'Dismiss ${shortcut.title}',
              child: IconButton(
                icon: const Icon(Icons.cancel_outlined, color: Color(0xFF94A3B8), size: 22),
                tooltip: 'Dismiss',
                onPressed: () => _dismiss(shortcut),
              ),
            ),
          ] else ...[
            Semantics(
              button: true,
              label: 'Remove ${shortcut.title}',
              child: IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
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
