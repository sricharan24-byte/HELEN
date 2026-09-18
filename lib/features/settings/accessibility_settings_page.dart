import 'package:flutter/material.dart';

import '../../core/settings/app_settings_controller.dart';
import '../ai_assistant/gemini_live_screen.dart';
import '../../data/repositories/transport_repository.dart';
import '../tickets/ticket_controller.dart';
import 'voice_assistant_settings_page.dart';

/// Accessibility settings page matching BusBuddy dark UI design screenshot 1.
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
                'Select Text Size',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              ...['Small', 'Medium', 'Large', 'Extra Large'].map((size) {
                final isSelected = _textSize == size;
                return ListTile(
                  title: Text(
                    size,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF38BDF8) : Colors.white,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                  trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF38BDF8)) : null,
                  onTap: () {
                    setState(() {
                      _settings.updateTextSize(size);
                    });
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
              'Accessibility',
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
                // ── Hero Header Card ─────────────────────────────────────
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
                          color: Color(0xFF3B82F6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.accessibility_new, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Accessibility',
                              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Adjust the app to make it easier to use.',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
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
                      Text(_textSize, style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, color: Color(0xFF38BDF8), size: 20),
                    ],
                  ),
                  onTap: _showTextSizePicker,
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
                      Text(_highContrast, style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, color: Color(0xFF38BDF8), size: 20),
                    ],
                  ),
                  onTap: () {
                    setState(() => _settings.toggleHighContrast());
                  },
                ),
                const SizedBox(height: 12),

                // ── Card 3: Voice & TalkBack ────────────────────────────
                _buildDarkCard(
                  icon: Icons.volume_up,
                  title: 'Voice & TalkBack',
                  subtitle: 'App voice, TalkBack support',
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFF64748B), size: 20),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => VoiceAssistantSettingsPage(
                          repository: widget.repository,
                          ticketController: widget.ticketController,
                        ),
                      ),
                    );
                  },
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
                    activeTrackColor: const Color(0xFF22C55E),
                    onChanged: (val) => setState(() => _settings.updateHapticFeedback(val)),
                  ),
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
                    activeTrackColor: const Color(0xFF22C55E),
                    onChanged: (val) => setState(() => _settings.updateSimplifiedNav(val)),
                  ),
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
                    activeTrackColor: const Color(0xFF22C55E),
                    onChanged: (val) => setState(() => _settings.updateScreenReaderHints(val)),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Tip Card ───────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111C33),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF2563EB),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.info, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Tip',
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "You can also use your phone's TalkBack settings. BusBuddy is designed to work well with TalkBack.",
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
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
    VoidCallback? onTap,
  }) {
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF111C33),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
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
