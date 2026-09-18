import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'adaptive_shortcuts_modal.dart';
import 'adaptive_ui_service.dart';
import '../../core/settings/app_settings_controller.dart';
import '../../data/models/adaptive_shortcut.dart';

/// Horizontal suggestion bar displayed on the HomePage when Adaptive UI is active.
class AdaptiveShortcutsView extends StatefulWidget {
  const AdaptiveShortcutsView({
    super.key,
    required this.onExecuteShortcut,
  });

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
    SemanticsService.announce('Pinned ${shortcut.title}', TextDirection.ltr);
  }

  void _dismissShortcut(AdaptiveShortcut shortcut) {
    _service.dismissShortcut(shortcut.id);
    SemanticsService.announce('Dismissed ${shortcut.title}', TextDirection.ltr);
  }

  @override
  Widget build(BuildContext context) {
    if (!_settings.adaptiveUi) return const SizedBox.shrink();

    final shortcuts = _service.visibleShortcuts;
    if (shortcuts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section Header ─────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: const [
                Icon(Icons.auto_awesome, color: Color(0xFF38BDF8), size: 16),
                SizedBox(width: 8),
                Text(
                  'Suggested for You',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => AdaptiveShortcutsModal.show(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(48, 32),
              ),
              child: const Text(
                'Manage',
                style: TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ── Horizontal Scrollable Shortcut Cards ───────────────────────
        SizedBox(
          height: 114,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: shortcuts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final shortcut = shortcuts[index];
              return _buildShortcutCard(shortcut);
            },
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildShortcutCard(AdaptiveShortcut shortcut) {
    final isAccepted = shortcut.isAccepted;

    return Semantics(
      button: true,
      label: '${shortcut.title}. ${shortcut.subtitle}. Tap to execute shortcut.',
      child: Material(
        color: const Color(0xFF111C33),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => widget.onExecuteShortcut(shortcut),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 230,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isAccepted
                    ? const Color(0xFF16A34A).withValues(alpha: 0.6)
                    : const Color(0xFF1E293B),
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
                        color: shortcut.color.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(shortcut.icon, color: shortcut.color, size: 18),
                    ),
                    if (isAccepted) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14532D),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.star, color: Color(0xFF86EFAC), size: 10),
                            SizedBox(width: 3),
                            Text(
                              'Pinned',
                              style: TextStyle(color: Color(0xFF86EFAC), fontSize: 10, fontWeight: FontWeight.w700),
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
                            child: IconButton(
                              icon: const Icon(Icons.check, size: 18, color: Color(0xFF22C55E)),
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                              tooltip: 'Pin Shortcut',
                              onPressed: () => _pinShortcut(shortcut),
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: 'Dismiss ${shortcut.title}',
                            child: IconButton(
                              icon: const Icon(Icons.close, size: 18, color: Color(0xFF94A3B8)),
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      shortcut.subtitle,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
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
