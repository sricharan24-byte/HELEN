import 'package:flutter/material.dart';

import '../../data/repositories/transport_repository.dart';
import '../safety/safety_sharing_page.dart';
import '../tickets/ticket_controller.dart';
import 'accessibility_settings_page.dart';
import 'personalization_settings_page.dart';
import 'voice_assistant_settings_page.dart';

/// Settings & Accessibility hub matching dark BusBuddy UI palette.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    this.repository,
    this.ticketController,
  });

  final TransportRepository? repository;
  final TicketController? ticketController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B101D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B101D),
        elevation: 0,
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
              'Settings & Preferences',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Section 1: Accessibility ────────────────────────────────
            _buildSectionHeader('ACCESSIBILITY & TALKBACK'),
            const SizedBox(height: 8),
            _buildHubCard(
              context: context,
              iconColor: const Color(0xFF3B82F6),
              icon: Icons.accessibility_new,
              title: 'Accessibility Settings',
              subtitle: 'Text size, high contrast, talkback, & haptics',
              trailingText: 'Large · On',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AccessibilitySettingsPage(
                      repository: repository,
                      ticketController: ticketController,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // ── Section 2: Personalization ──────────────────────────────
            _buildSectionHeader('PERSONALIZATION & LAYOUT'),
            const SizedBox(height: 8),
            _buildHubCard(
              context: context,
              iconColor: const Color(0xFF16A34A),
              icon: Icons.home,
              title: 'Personalization Settings',
              subtitle: 'Customize home screen, adaptive UI, & layout',
              trailingText: 'Adaptive On',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PersonalizationSettingsPage(
                      repository: repository,
                      ticketController: ticketController,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // ── Section 3: Voice Assistant ──────────────────────────────
            _buildSectionHeader('VOICE ASSISTANT & AI'),
            const SizedBox(height: 8),
            _buildHubCard(
              context: context,
              iconColor: const Color(0xFF7C3AED),
              icon: Icons.mic,
              title: 'Voice Assistant Settings',
              subtitle: 'Preferred language, voice speed, & Gemini AI',
              trailingText: 'English',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VoiceAssistantSettingsPage(
                      repository: repository,
                      ticketController: ticketController,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // ── Section 4: Safety & Emergency ───────────────────────────
            _buildSectionHeader('EMERGENCY & TRUSTED CONTACTS'),
            const SizedBox(height: 8),
            _buildHubCard(
              context: context,
              iconColor: const Color(0xFFDC2626),
              icon: Icons.shield_outlined,
              title: 'Emergency Contacts & SOS',
              subtitle: 'Configure 1-tap location alerts & sharing links',
              trailingText: 'Active',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SafetySharingPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildHubCard({
    required BuildContext context,
    required Color iconColor,
    required IconData icon,
    required String title,
    required String subtitle,
    required String trailingText,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: '$title. $subtitle.',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF111C33),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    trailingText,
                    style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: Color(0xFF38BDF8), size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
