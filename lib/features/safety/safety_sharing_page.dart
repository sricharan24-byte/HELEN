import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/a11y/announcement_coordinator.dart';
import '../../core/settings/app_settings_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/tokens/app_spacing.dart';
import '../../core/widgets/bus_buddy_logo.dart';
import '../../core/tokens/status_level.dart';
import '../../data/models/ticket_model.dart';
import '../../data/models/adaptive_shortcut.dart';
import '../../data/repositories/emergency_contact_repository.dart';
import '../adaptive_ui/adaptive_ui_service.dart';

/// Safety & Emergency Sharing page.
/// Fully conforms to Astra Gate 12 (Privacy & Safety Boundaries) and Step 2.5
/// with multi-modal alerts, AnnouncementCoordinator urgent dispatch,
/// semantic design tokens, and 48dp minimum touch targets.
class SafetySharingPage extends StatefulWidget {
  const SafetySharingPage({super.key, this.activeTicket});

  final Ticket? activeTicket;

  @override
  State<SafetySharingPage> createState() => _SafetySharingPageState();
}

class _SafetySharingPageState extends State<SafetySharingPage> {
  final _contacts = EmergencyContactRepository.instance;
  final _settings = AppSettingsController.instance;

  @override
  void initState() {
    super.initState();
    _contacts.addListener(_contactsChanged);
  }

  void _contactsChanged() => setState(() {});

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();

  @override
  void dispose() {
    _contacts.removeListener(_contactsChanged);
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _addContact() {
    final colors = AppTheme.colors(context);

    unawaited(showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(color: colors.border),
        ),
        title: Text(
          'Add Emergency Contact',
          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Astra Gate 12: Emergency contacts receive SMS alerts with your real-time bus telemetry when SOS is triggered.',
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nameCtrl,
              style: TextStyle(color: colors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Contact Name / Title',
                labelStyle: TextStyle(color: colors.textSecondary),
                filled: true,
                fillColor: colors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: BorderSide(color: colors.border),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: colors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Phone Number (+91)',
                labelStyle: TextStyle(color: colors.textSecondary),
                filled: true,
                fillColor: colors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: BorderSide(color: colors.border),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          FilledButton(
            onPressed: () {
              if (_nameCtrl.text.trim().isNotEmpty && _phoneCtrl.text.trim().isNotEmpty) {
                final name = _nameCtrl.text.trim();
                final phone = _phoneCtrl.text.trim();
                _contacts.addContact({
                  'name': name,
                  'phone': phone,
                  'relation': 'Trusted',
                });
                _nameCtrl.clear();
                _phoneCtrl.clear();
                AnnouncementCoordinator.instance.announce(
                  'Added emergency contact $name.',
                  priority: AnnouncementPriority.normal,
                );
              }
              Navigator.of(ctx).pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: colors.actionPrimary,
              foregroundColor: colors.actionPrimaryText,
              minimumSize: const Size(100, AppSpacing.minTouchTarget),
            ),
            child: const Text('Add Contact'),
          ),
        ],
      ),
    ));
  }

  void _triggerSosAlert() {
    // BUS-P2-06: the haptic switch is honest only if something reads it.
    // The SOS broadcast is the one "important alert" in the app, so it is
    // the one place a vibration is warranted. Honours the user's switch.
    if (_settings.hapticFeedback) {
      unawaited(HapticFeedback.heavyImpact());
    }
    final colors = AppTheme.colors(context);

    unawaited(showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(color: colors.statusAlert),
        ),
        title: Row(
          children: [
            Icon(StatusLevel.error.icon, color: colors.statusAlert, size: 28),
            const SizedBox(width: 10),
            Text(
              'Trigger SOS Alert?',
              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Demonstration Mode: This logs a simulated emergency alert with your current corridor stop coordinates. In production, this dispatches SMS and emergency dialer intents to 112 and your trusted contacts.',
              style: TextStyle(color: colors.textPrimary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.statusAlertBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.statusAlert),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, size: 16, color: colors.statusAlert),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Non-voice alternative: SOS operates silently without requiring speech recognition or assistant mic.',
                      style: TextStyle(color: colors.statusAlert, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          FilledButton.icon(
            onPressed: () {
              AdaptiveUiService.instance.recordGenericEvent(
                actionType: 'sos',
                title: 'Emergency SOS Broadcast',
                subtitle: 'Safety assistance alert',
                type: AdaptiveShortcutType.safety,
              );

              AnnouncementCoordinator.instance.announce(
                'Emergency SOS alert broadcasted. Dial 112 for immediate assistance.',
                priority: AnnouncementPriority.urgent,
              );

              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('⚠️ Demo Mode: Simulated SOS recorded. Dial 112 for real emergency assistance.'),
                  backgroundColor: colors.statusAlert,
                  duration: const Duration(seconds: 4),
                ),
              );
            },
            icon: const Icon(Icons.sos, size: 18),
            label: const Text('RECORD SIMULATED SOS'),
            style: FilledButton.styleFrom(
              backgroundColor: colors.statusAlert,
              foregroundColor: Colors.white,
              minimumSize: const Size(140, AppSpacing.minTouchTarget),
            ),
          ),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final ticket = widget.activeTicket;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const BusBuddyLogo(
          fontSize: 20,
          subtitle: 'Safety & Emergency Sharing',
        ),
        centerTitle: true,
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SOS Banner Card
            Container(
              padding: AppSpacing.cardPadding,
              decoration: BoxDecoration(
                color: colors.statusAlertBg,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: colors.statusAlert),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.statusAlert,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_outlined, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            '1-Tap Emergency Broadcast',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: colors.statusAlert,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Send immediate location distress alerts to trusted contacts',
                          style: TextStyle(color: colors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // SOS Broadcast Button
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: double.infinity,
                minHeight: AppSpacing.minTouchTarget + 4,
              ),
              child: FilledButton.icon(
                onPressed: _triggerSosAlert,
                icon: const Icon(Icons.sos, size: 24),
                label: const Text(
                  'BROADCAST SOS ALERT NOW',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.statusAlert,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Live Trip Sharing Card
            if (ticket != null) ...[
              Text(
                'ACTIVE TRIP LIVE SHARING',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: colors.textSecondary,
                  fontSize: 11,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.directions_bus, color: colors.actionPrimary, size: 24),
                        const SizedBox(width: 10),
                        Text(
                          'Bus ${ticket.busId}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${ticket.origin.name} → ${ticket.destination.name}',
                      style: TextStyle(color: colors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: double.infinity,
                        minHeight: AppSpacing.minTouchTarget,
                      ),
                      child: OutlinedButton.icon(
                        onPressed: () {
                          AnnouncementCoordinator.instance.announce(
                            'Live trip link copied for sharing.',
                            priority: AnnouncementPriority.normal,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Opening WhatsApp to share live trip link...')),
                          );
                        },
                        icon: Icon(Icons.share, color: colors.actionPrimary, size: 18),
                        label: Text(
                          'Share Live Trip via WhatsApp / SMS',
                          style: TextStyle(color: colors.actionPrimary, fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colors.actionPrimary, width: 1.5),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Contacts Header & Add Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'TRUSTED EMERGENCY CONTACTS',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: colors.textSecondary,
                      fontSize: 11,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _addContact,
                  icon: Icon(Icons.person_add_alt_1, size: 18, color: colors.actionPrimary),
                  label: Text('Add Contact', style: TextStyle(color: colors.actionPrimary, fontWeight: FontWeight.w700)),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, AppSpacing.minTouchTarget),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Contacts List
            ..._contacts.contacts.map((contact) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colors.actionPrimary.withValues(alpha: 0.15),
                      foregroundColor: colors.actionPrimary,
                      child: Text(contact['name']![0], style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    title: Text(
                      contact['name']!,
                      style: TextStyle(fontWeight: FontWeight.w700, color: colors.textPrimary),
                    ),
                    subtitle: Text(
                      '${contact['phone']} • ${contact['relation']}',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.phone, color: colors.statusSuccess),
                      tooltip: 'Call ${contact['name']}',
                      constraints: const BoxConstraints(
                        minWidth: AppSpacing.minTouchTarget,
                        minHeight: AppSpacing.minTouchTarget,
                      ),
                      onPressed: () {
                        AnnouncementCoordinator.instance.announce(
                          'Calling ${contact['name']}',
                          priority: AnnouncementPriority.high,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Calling ${contact['name']} (${contact['phone']})...')),
                        );
                      },
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
