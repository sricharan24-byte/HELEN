import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/tokens/app_spacing.dart';
import '../../core/widgets/bus_buddy_logo.dart';
import '../../data/repositories/transport_repository.dart';
import '../alerts/alerts_page.dart';
import '../safety/safety_sharing_page.dart';
import '../settings/settings_page.dart';
import '../tickets/ticket_controller.dart';

class MorePage extends StatelessWidget {
  const MorePage({
    super.key,
    required this.repository,
    required this.ticketController,
  });

  final TransportRepository repository;
  final TicketController ticketController;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: const BusBuddyLogo(
          fontSize: 20,
          subtitle: 'Safety, alerts, and settings',
          crossAxisAlignment: CrossAxisAlignment.start,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _MoreEntry(
              title: 'Safety & Contacts',
              subtitle: 'Emergency SOS and trusted contacts',
              icon: Icons.shield_outlined,
              iconColor: colors.statusError,
              onTap: () => _push(
                context,
                SafetySharingPage(activeTicket: ticketController.activeTicket),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _MoreEntry(
              title: 'Corridor Alerts',
              subtitle: 'Service updates for Vellore and Katpadi',
              icon: Icons.notifications_active_outlined,
              iconColor: colors.actionPrimary,
              onTap: () => _push(context, const AlertsPage()),
            ),
            const SizedBox(height: AppSpacing.md),
            _MoreEntry(
              title: 'Settings',
              subtitle: 'Accessibility, voice, and personalization',
              icon: Icons.settings_outlined,
              iconColor: colors.actionPrimary,
              onTap: () => _push(
                context,
                SettingsPage(
                  repository: repository,
                  ticketController: ticketController,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget page) {
    unawaited(
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)),
    );
  }
}

class _MoreEntry extends StatelessWidget {
  const _MoreEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.minTouchTarget,
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
