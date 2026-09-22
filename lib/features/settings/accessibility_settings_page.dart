import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/a11y/announcement_coordinator.dart';
import '../../core/settings/app_settings_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/tokens/app_semantic_colors.dart';
import '../../core/tokens/app_spacing.dart';
import '../ai_assistant/gemini_live_screen.dart';
import '../../data/repositories/transport_repository.dart';
import '../tickets/ticket_controller.dart';
import 'voice_assistant_settings_page.dart';

/// Accessibility settings page matching BusBuddy dark UI design screenshot 1.
/// Upgraded per Astra Phase 2 with semantic design tokens, 48dp touch targets,
/// and live high-contrast theme toggling.
class AccessibilitySettingsPage extends StatefulWidget {
  const AccessibilitySettingsPage({
    super.key,
    this.repository,
    this.ticketController,
  });

  final TransportRepository? repository;
  final TicketController? ticketController;

  @override
  State<AccessibilitySettingsPage> createState() => _AccessibilitySettingsPageState();
}

class _AccessibilitySettingsPageState extends State<AccessibilitySettingsPage> {
  final AppSettingsController _settings = AppSettingsController.instance;

  String get _textSize => _settings.textSize;
  String get _highContrast => _settings.highContrast;
  bool get _hapticFeedback => _settings.hapticFeedback;
  bool get _simplifiedNav => _settings.simplifiedNav;
  bool get _screenReaderHints => _settings.screenReaderHints;

  void _showTextSizePicker() {
    final colors = AppTheme.colors(context);

    unawaited(showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Material(
          color: colors.surface,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Text Size',
                  style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                ...['Small', 'Medium', 'Large', 'Extra Large'].map((size) {
                  final isSelected = _textSize == size;
                  return Material(
                    color: Colors.transparent,
                    child: ListTile(
                      title: Text(
                        size,
                        style: TextStyle(
                          color: isSelected ? colors.actionPrimary : colors.textPrimary,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                        ),
                      ),
                      trailing: isSelected ? Icon(Icons.check, color: colors.actionPrimary) : null,
                      onTap: () {
                        setState(() {
                          _settings.updateTextSize(size);
                        });
                        AnnouncementCoordinator.instance.announce(
                          'Text size set to $size',
                          priority: AnnouncementPriority.normal,
                        );
                        Navigator.pop(context);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    ));
  }

  void _openAskBusBuddy() {
    unawaited(Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GeminiLiveScreen(
          repository: widget.repository,
          ticketController: widget.ticketController,
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: colors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
          constraints: const BoxConstraints(
            minWidth: AppSpacing.minTouchTarget,
            minHeight: AppSpacing.minTouchTarget,
          ),
        ),
        title: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Bus', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w900, fontSize: 20)),
                Text('Buddy', style: TextStyle(color: colors.actionPrimary, fontWeight: FontWeight.w900, fontSize: 20)),
              ],
            ),
            Text(
              'Accessibility',
              style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                // ── Hero Header Card ─────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: colors.actionPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.accessibility_new, color: colors.actionPrimaryText, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                'Accessibility',
                                style: TextStyle(color: colors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Adjust the app to make it easier to use.',
                              style: TextStyle(color: colors.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Card 1: Text Size ──────────────────────────────────
                _buildDarkCard(
                  icon: Icons.text_fields,
                  title: 'Text Size',
                  subtitle: 'Make text larger or smaller',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_textSize, style: TextStyle(color: colors.actionPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, color: colors.actionPrimary, size: 20),
                    ],
                  ),
                  onTap: _showTextSizePicker,
                  colors: colors,
                ),
                const SizedBox(height: 12),

                // ── Card 2: High Contrast ──────────────────────────────
                _buildDarkCard(
                  icon: Icons.contrast,
                  title: 'High Contrast',
                  subtitle: 'Improve visibility',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_highContrast, style: TextStyle(color: colors.actionPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, color: colors.actionPrimary, size: 20),
                    ],
                  ),
                  onTap: () {
                    setState(_settings.toggleHighContrast);
                    AnnouncementCoordinator.instance.announce(
                      'High contrast ${_settings.highContrast == 'On' ? 'enabled (WCAG AAA 7:1 ratio)' : 'disabled'}',
                      priority: AnnouncementPriority.normal,
                    );
                  },
                  colors: colors,
                ),
                const SizedBox(height: 12),

                // ── Card 3: Voice & TalkBack ────────────────────────────
                _buildDarkCard(
                  icon: Icons.volume_up,
                  title: 'Voice & TalkBack',
                  subtitle: 'App voice, TalkBack support',
                  trailing: Icon(Icons.chevron_right, color: colors.textSecondary, size: 20),
                  onTap: () {
                    unawaited(Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => VoiceAssistantSettingsPage(
                          repository: widget.repository,
                          ticketController: widget.ticketController,
                        ),
                      ),
                    ));
                  },
                  colors: colors,
                ),
                const SizedBox(height: 12),

                // ── Card 4: Haptic Feedback ─────────────────────────────
                _buildDarkCard(
                  icon: Icons.phonelink_ring,
                  title: 'Haptic Feedback',
                  subtitle: 'Vibrations for important alerts',
                  trailing: Switch(
                    value: _hapticFeedback,
                    activeThumbColor: Colors.white,
                    activeTrackColor: colors.statusSuccess,
                    onChanged: (val) => setState(() => _settings.updateHapticFeedback(val)),
                  ),
                  colors: colors,
                ),
                const SizedBox(height: 12),

                // ── Card 5: Simplified Navigation ───────────────────────
                _buildDarkCard(
                  icon: Icons.grid_view_rounded,
                  title: 'Simplified Navigation',
                  subtitle: 'Larger buttons, fewer steps',
                  trailing: Switch(
                    value: _simplifiedNav,
                    activeThumbColor: Colors.white,
                    activeTrackColor: colors.statusSuccess,
                    onChanged: (val) => setState(() => _settings.updateSimplifiedNav(val)),
                  ),
                  colors: colors,
                ),
                const SizedBox(height: 12),

                // ── Card 6: Screen Reader Hints ─────────────────────────
                _buildDarkCard(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Screen Reader Hints',
                  subtitle: 'Extra descriptions for clarity',
                  trailing: Switch(
                    value: _screenReaderHints,
                    activeThumbColor: Colors.white,
                    activeTrackColor: colors.statusSuccess,
                    onChanged: (val) => setState(() => _settings.updateScreenReaderHints(val)),
                  ),
                  colors: colors,
                ),
                const SizedBox(height: 14),

                // ── Tip Card ───────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: colors.actionPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.info, color: colors.actionPrimaryText, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tip',
                              style: TextStyle(color: colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "You can also use your phone's TalkBack settings. BusBuddy is designed to work well with TalkBack.",
                              style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Sticky Bottom Ask BusBuddy Action Bar ─────────────────────
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: Semantics(
                button: true,
                label: 'Ask BusBuddy. Need help with settings? Just ask.',
                excludeSemantics: true,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _openAskBusBuddy,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      height: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: colors.statusAlert,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: colors.statusAlert.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.mic, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 14),
                          const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ask BusBuddy',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                'Need help with settings? Just ask.',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDarkCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    required AppSemanticColors colors,
    VoidCallback? onTap,
  }) {
    return Semantics(
      button: onTap != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Icon(icon, color: colors.textPrimary, size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(color: colors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
