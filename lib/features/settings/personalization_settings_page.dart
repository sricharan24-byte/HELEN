import 'package:flutter/material.dart';

import '../../core/settings/app_settings_controller.dart';
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
  State<PersonalizationSettingsPage> createState() => _PersonalizationSettingsPageState();
}

class _PersonalizationSettingsPageState extends State<PersonalizationSettingsPage> {
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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Default Starting Screen',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              ...['Home', 'Live Tracking', 'My Tickets', 'Alerts'].map((screen) {
                final isSelected = _startingScreen == screen;
                return ListTile(
                  title: Text(
                    screen,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF38BDF8) : Colors.white,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                  trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF38BDF8)) : null,
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
    );
  }

  void _resetLayout() {
    setState(() {
      _settings.resetHomeScreenLayout();
      _settings.resetToDefaults();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Home layout reset to default settings.'),
        backgroundColor: Color(0xFF15803D),
      ),
    );
  }

  void _openAskBusBuddy() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GeminiLiveScreen(
          repository: widget.repository,
          ticketController: widget.ticketController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B101D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B101D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
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
              'Personalization',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500),
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
                // ── Hero Header Card (Green Circle) ─────────────────────
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
                          color: Color(0xFF16A34A),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.home, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Personalization',
                              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Customize your experience and choose what you see.',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
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
                  icon: Icons.grid_view_rounded,
                  title: 'Customize Home Screen',
                  subtitle: 'Rearrange and choose features',
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFF0F172A), size: 22),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const HomeScreenCustomizationPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // ── White Card 2: Adaptive UI ─────────────────────────────
                _buildWhiteCard(
                  icon: Icons.star_rounded,
                  title: 'Adaptive UI',
                  subtitle: 'Shows shortcuts based on your usage',
                  trailing: Switch(
                    value: _adaptiveUi,
                    activeThumbColor: Colors.white,
                    activeTrackColor: const Color(0xFF22C55E),
                    onChanged: (val) => setState(() => _settings.updateAdaptiveUi(val)),
                  ),
                ),
                if (_adaptiveUi) ...[
                  const SizedBox(height: 12),
                  _buildWhiteCard(
                    icon: Icons.auto_awesome,
                    title: 'Manage Adaptive Shortcuts',
                    subtitle:
                        '${AdaptiveUiService.instance.visibleShortcuts.length} active shortcuts • Review & Pin',
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFF0F172A), size: 22),
                    onTap: () => AdaptiveShortcutsModal.show(context),
                  ),
                ],
                const SizedBox(height: 12),

                // ── Light Blue Info Box ──────────────────────────────────
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
                        child: const Icon(Icons.info, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'BusBuddy learns your frequently used features and suggests shortcuts. You remain in control.',
                          style: TextStyle(
                            color: Color(0xFF1E3A8A),
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
                  icon: Icons.home_outlined,
                  title: 'Default Starting Screen',
                  subtitle: 'Choose which screen opens first',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_startingScreen, style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, color: Color(0xFF2563EB), size: 20),
                    ],
                  ),
                  onTap: _showStartingScreenPicker,
                ),
                const SizedBox(height: 12),

                // ── White Card 4: Reset My Layout ────────────────────────
                _buildWhiteCard(
                  icon: Icons.refresh_rounded,
                  title: 'Reset My Layout',
                  subtitle: 'Restore default settings',
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFF0F172A), size: 22),
                  onTap: _resetLayout,
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
                label: 'Ask BusBuddy. Customize my home screen.',
                child: InkWell(
                  onTap: _openAskBusBuddy,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.4),
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
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Ask BusBuddy',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'Customize my home screen.',
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
          ],
        ),
      ),
    );
  }

  Widget _buildWhiteCard({
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF0F172A), size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
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
