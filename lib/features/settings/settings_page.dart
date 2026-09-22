import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/tokens/app_spacing.dart';
import '../../data/repositories/transport_repository.dart';
import '../safety/safety_sharing_page.dart';
import '../tickets/ticket_controller.dart';
import 'accessibility_settings_page.dart';
import 'personalization_settings_page.dart';
import 'voice_assistant_settings_page.dart';

/// Settings hub — theme-aware cards for accessibility, personalization,
/// voice, and emergency configuration.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.repository, this.ticketController});

  final TransportRepository? repository;
  final TicketController? ticketController;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Bus',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                Text(
                  'Buddy',
                  style: TextStyle(
                    color: colors.actionSecondary,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            Text(
              'Settings & Preferences',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _buildSectionHeader(context, 'ACCESSIBILITY & TALKBACK'),
            const SizedBox(height: AppSpacing.sm),
            _buildHubCard(
              context: context,
              iconColor: const Color(0xFF3B82F6),
              icon: Icons.accessibility_new,
              title: 'Accessibility Settings',
              subtitle: 'Text size, high contrast, talkback, & haptics',
              trailingText: 'Large · On',
              onTap: () {
                unawaited(
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AccessibilitySettingsPage(
                        repository: repository,
                        ticketController: ticketController,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            _buildSectionHeader(context, 'PERSONALIZATION & LAYOUT'),
            const SizedBox(height: AppSpacing.sm),
            _buildHubCard(
              context: context,
              iconColor: const Color(0xFF16A34A),
              icon: Icons.home,
              title: 'Personalization Settings',
              subtitle: 'Customize home screen, adaptive UI, & layout',
              trailingText: 'Adaptive On',
              onTap: () {
                unawaited(
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PersonalizationSettingsPage(
                        repository: repository,
                        ticketController: ticketController,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            _buildSectionHeader(context, 'VOICE ASSISTANT & AI'),
            const SizedBox(height: AppSpacing.sm),
            _buildHubCard(
              context: context,
              iconColor: const Color(0xFF7C3AED),
              icon: Icons.mic,
              title: 'Voice Assistant Settings',
              subtitle: 'Preferred language, voice speed, & Gemini AI',
              trailingText: 'English',
              onTap: () {
                unawaited(
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => VoiceAssistantSettingsPage(
                        repository: repository,
                        ticketController: ticketController,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            _buildSectionHeader(context, 'EMERGENCY & TRUSTED CONTACTS'),
            const SizedBox(height: AppSpacing.sm),
            _buildHubCard(
              context: context,
              iconColor: const Color(0xFFDC2626),
              icon: Icons.shield_outlined,
              title: 'Emergency Contacts & SOS',
              subtitle: 'Configure 1-tap location alerts & sharing links',
              trailingText: 'Active',
              onTap: () {
                unawaited(
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SafetySharingPage(),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'VIT Vellore → Katpadi Railway Station corridor',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final colors = AppTheme.colors(context);
    return Semantics(
      header: true,
      label: title,
      child: Text(
        title,
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
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
    final colors = AppTheme.colors(context);

    return Semantics(
      button: true,
      label: '$title. $subtitle.',
      excludeSemantics: true,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(
                color: colors.border,
                width: colors.isHighContrast ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
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
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
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
                      style: TextStyle(
                        color: colors.actionSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      color: colors.actionSecondary,
                      size: 20,
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
