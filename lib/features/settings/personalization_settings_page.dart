import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/settings/app_settings_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/tokens/app_semantic_colors.dart';
import '../../core/tokens/app_spacing.dart';
import '../../core/widgets/bus_buddy_logo.dart';
import '../adaptive_ui/adaptive_shortcuts_modal.dart';
import '../adaptive_ui/adaptive_ui_service.dart';
import '../ai_assistant/gemini_live_screen.dart';
import 'home_screen_customization_page.dart';
import '../../data/repositories/transport_repository.dart';
import '../tickets/ticket_controller.dart';

/// Personalization settings page matching BusBuddy UI design screenshot 2.
class PersonalizationSettingsPage extends StatefulWidget {
  const PersonalizationSettingsPage({
    super.key,
    this.repository,
    this.ticketController,
  });

  final TransportRepository? repository;
  final TicketController? ticketController;

  @override
  State<PersonalizationSettingsPage> createState() =>
      _PersonalizationSettingsPageState();
}

class _PersonalizationSettingsPageState
    extends State<PersonalizationSettingsPage> {
  final AppSettingsController _settings = AppSettingsController.instance;

  bool get _adaptiveUi => _settings.adaptiveUi;
  String get _startingScreen => _settings.startingScreen;

  @override
  void initState() {
    super.initState();
    AdaptiveUiService.instance.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    AdaptiveUiService.instance.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _showStartingScreenPicker() {
    final colors = AppTheme.colors(context);
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusLg),
          ),
        ),
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Default Starting Screen',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                ...['Home', 'Live Tracking', 'My Tickets', 'Alerts'].map((
                  screen,
                ) {
                  final isSelected = _startingScreen == screen;
                  return ListTile(
                    title: Text(
                      screen,
                      style: TextStyle(
                        color: isSelected
                            ? colors.actionSecondary
                            : colors.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check, color: colors.actionSecondary)
                        : null,
                    onTap: () {
                      setState(() => _settings.updateStartingScreen(screen));
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  void _resetLayout() {
    final colors = AppTheme.colors(context);
    // Narrow action: only the home screen layout is reset. This button must
    // not wipe every other preference (voice, accessibility, API key…), so
    // resetToDefaults() deliberately stays out of this path.
    setState(_settings.resetHomeScreenLayout);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Home layout reset to default settings.'),
        backgroundColor: colors.statusSuccess,
      ),
    );
  }

  void _openAskBusBuddy() {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GeminiLiveScreen(
            repository: widget.repository,
            ticketController: widget.ticketController,
          ),
        ),
      ),
    );
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
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: colors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const BusBuddyLogo(
          fontSize: 20,
          subtitle: 'Personalization',
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                // ── Hero Header Card (Green Circle) ─────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.surfaceSubtle,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusLg),
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
                        child: Icon(
                          Icons.home,
                          color: colors.onActionPrimary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Personalization',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Customize your experience and choose what you see.',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── White Card 1: Customize Home Screen ──────────────────
                _buildWhiteCard(
                  colors: colors,
                  icon: Icons.grid_view_rounded,
                  title: 'Customize Home Screen',
                  subtitle: 'Rearrange and choose features',
                  trailing: Icon(
                    Icons.chevron_right,
                    color: colors.textPrimary,
                    size: 22,
                  ),
                  onTap: () {
                    unawaited(
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const HomeScreenCustomizationPage(),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // ── White Card 2: Adaptive UI ─────────────────────────────
                _buildWhiteCard(
                  colors: colors,
                  icon: Icons.star_rounded,
                  title: 'Adaptive UI',
                  subtitle: 'Shows shortcuts based on your usage',
                  trailing: Switch(
                    value: _adaptiveUi,
                    activeThumbColor: colors.onActionPrimary,
                    activeTrackColor: colors.statusSuccess,
                    onChanged: (val) =>
                        setState(() => _settings.updateAdaptiveUi(val)),
                  ),
                ),
                if (_adaptiveUi) ...[
                  const SizedBox(height: 12),
                  _buildWhiteCard(
                    colors: colors,
                    icon: Icons.auto_awesome,
                    title: 'Manage Adaptive Shortcuts',
                    subtitle:
                        '${AdaptiveUiService.instance.visibleShortcuts.length} active shortcuts • Review & Pin',
                    trailing: Icon(
                      Icons.chevron_right,
                      color: colors.textPrimary,
                      size: 22,
                    ),
                    onTap: () => AdaptiveShortcutsModal.show(context),
                  ),
                ],
                const SizedBox(height: 12),

                // ── Light Blue Info Box ──────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.statusInfoBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: colors.statusInfo,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.info,
                          color: colors.background,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'BusBuddy learns your frequently used features and suggests shortcuts. You remain in control.',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── White Card 3: Default Starting Screen ────────────────
                _buildWhiteCard(
                  colors: colors,
                  icon: Icons.home_outlined,
                  title: 'Default Starting Screen',
                  subtitle: 'Choose which screen opens first',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _startingScreen,
                        style: TextStyle(
                          color: colors.actionPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        color: colors.actionPrimary,
                        size: 20,
                      ),
                    ],
                  ),
                  onTap: _showStartingScreenPicker,
                ),
                const SizedBox(height: 12),

                // ── White Card 4: Reset My Layout ────────────────────────
                _buildWhiteCard(
                  colors: colors,
                  icon: Icons.refresh_rounded,
                  title: 'Reset My Layout',
                  subtitle: 'Restore the default home screen layout',
                  trailing: Icon(
                    Icons.chevron_right,
                    color: colors.textPrimary,
                    size: 22,
                  ),
                  onTap: _resetLayout,
                ),
              ],
            ),

            // ── Sticky Bottom Ask BusBuddy Action Bar ─────────────────────
            // Single actionPrimary accent (red is reserved for Emergency SOS).
            // minHeight instead of a fixed height so two-line content reflows
            // at 300% text scale instead of overflowing.
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: Semantics(
                button: true,
                label: 'Ask BusBuddy. Customize my home screen.',
                excludeSemantics: true,
                child: Material(
                  color: colors.actionPrimary,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  child: InkWell(
                    onTap: _openAskBusBuddy,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: AppSpacing.minTouchTarget,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: colors.onActionPrimary.withValues(
                                alpha: 0.2,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.mic,
                              color: colors.onActionPrimary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
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
                                  'Customize my home screen.',
                                  style: TextStyle(
                                    color: colors.onActionPrimary
                                        .withValues(alpha: 0.8),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhiteCard({
    required AppSemanticColors colors,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
