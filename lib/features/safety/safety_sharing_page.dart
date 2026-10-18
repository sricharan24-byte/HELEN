import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/a11y/announcement_coordinator.dart';
import '../../core/location/location_share_service.dart';
import '../../core/settings/app_settings_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/tokens/app_spacing.dart';
import '../../core/tokens/status_level.dart';
import '../../data/models/ticket_model.dart';
import '../../data/repositories/emergency_contact_repository.dart';

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
  final _locationShare = LocationShareService();
  bool _locationRequestPending = false;

  @override
  void initState() {
    super.initState();
    _contacts.addListener(_contactsChanged);
  }

  void _contactsChanged() => setState(() {});

  Future<void> _shareLocation({required bool emergency}) async {
    final colors = AppTheme.colors(context);
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          emergency ? 'Share emergency location?' : 'Share your location?',
          style: TextStyle(color: colors.textPrimary),
        ),
        content: Text(
          'BusBuddy will request foreground location access and create one map link for your current location. Your coordinates are not saved. Android will let you choose an app and recipient; nothing is sent until you confirm there.',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, AppSpacing.minTouchTarget),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;

    final trip = widget.activeTicket;
    final contextText = trip == null
        ? ''
        : ' I am riding bus ${trip.busId} from ${trip.origin.name} to ${trip.destination.name}.';
    _locationRequestPending = true;
    late final LocationShareResult result;
    try {
      result = await _locationShare.shareCurrentLocation(
        message: emergency
            ? 'Emergency: I need assistance.$contextText'
            : 'My current location snapshot.$contextText',
        chooserTitle: emergency ? 'Share emergency location' : 'Share location',
      );
    } finally {
      _locationRequestPending = false;
    }
    if (!mounted) return;

    final message = switch (result.status) {
      LocationShareStatus.chooserOpened =>
        'Share menu opened. Choose an app and recipient; the message has not been sent yet.',
      LocationShareStatus.permissionDenied =>
        'Location permission was denied. Allow it when you want to share a location snapshot.',
      LocationShareStatus.permanentlyDenied =>
        'Location permission is blocked. Enable it in Android Settings > Apps > BusBuddy > Permissions.',
      LocationShareStatus.locationDisabled =>
        'Turn on Location in Android settings, then try again.',
      LocationShareStatus.timeout =>
        'Could not get a location fix in time. Move to an area with a location signal and try again.',
      LocationShareStatus.unavailable =>
        'Phone location is unavailable. No location was shared.',
      LocationShareStatus.unsupported =>
        'Location sharing is available on Android only.',
      LocationShareStatus.cancelled => 'Location request cancelled.',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    if (result.status == LocationShareStatus.chooserOpened) {
      AnnouncementCoordinator.instance.announce(
        emergency
            ? 'Emergency location share menu opened. Choose a recipient to continue.'
            : 'Location share menu opened. Choose a recipient to continue.',
        priority: emergency
            ? AnnouncementPriority.urgent
            : AnnouncementPriority.normal,
      );
    }
  }

  Future<void> _openDialer(Map<String, String> contact) async {
    final result = await _locationShare.openDialer(contact['phone'] ?? '');
    if (!mounted) return;
    final message = switch (result.status) {
      DialerStatus.opened =>
        'Dialer opened with ${contact['name']}’s number. Review it and tap Call.',
      DialerStatus.invalidNumber =>
        'This contact has an invalid phone number. Edit the contact and try again.',
      DialerStatus.unavailable => 'The phone dialer could not be opened.',
      DialerStatus.unsupported => 'Calling is available on Android only.',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _removeContact(Map<String, String> contact) async {
    final colors = AppTheme.colors(context);
    final name = contact['name']!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(color: colors.border),
        ),
        title: Text(
          'Remove emergency contact?',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          '$name will no longer receive SOS alerts from BusBuddy.',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep Contact'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, AppSpacing.minTouchTarget),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    if (_contacts.removeContact(contact)) {
      AnnouncementCoordinator.instance.announce(
        'Removed emergency contact $name.',
        priority: AnnouncementPriority.normal,
      );
    }
  }

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();

  @override
  void dispose() {
    if (_locationRequestPending) {
      unawaited(_locationShare.cancelCurrentLocation());
    }
    _contacts.removeListener(_contactsChanged);
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _addContact() {
    final colors = AppTheme.colors(context);

    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            side: BorderSide(color: colors.border),
          ),
          title: Text(
            'Add Emergency Contact',
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Emergency contacts are shared only when you choose a recipient in Android’s share menu.',
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
              child: Text(
                'Cancel',
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
            FilledButton(
              onPressed: () {
                if (_nameCtrl.text.trim().isNotEmpty &&
                    _phoneCtrl.text.trim().isNotEmpty) {
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
      ),
    );
  }

  void _triggerSosAlert() {
    final colors = AppTheme.colors(context);

    unawaited(
      showDialog<void>(
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
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'After you continue, BusBuddy will request your current phone location and open Android’s share menu with an emergency map link. You choose the recipient and confirm sending there. For immediate assistance in India, call 112.',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 13,
                  height: 1.4,
                ),
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
                    Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: colors.statusAlert,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Non-voice alternative: SOS operates silently without requiring speech recognition or assistant mic.',
                        style: TextStyle(
                          color: colors.statusAlert,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
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
              child: Text(
                'Cancel',
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                // The haptic switch applies only when the user confirms the
                // simulated alert, not when opening or cancelling the dialog.
                if (_settings.hapticFeedback) {
                  unawaited(HapticFeedback.heavyImpact());
                }
                Navigator.of(ctx).pop();
                unawaited(_shareLocation(emergency: true));
              },
              icon: const Icon(Icons.sos, size: 18),
              label: const Text('CONTINUE TO SHARE SOS'),
              style: FilledButton.styleFrom(
                backgroundColor: colors.statusAlert,
                foregroundColor: Colors.white,
                minimumSize: const Size(140, AppSpacing.minTouchTarget),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final ticket = widget.activeTicket;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Safety'),
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
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            'Emergency location share',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: colors.statusAlert,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Choose an app and trusted contact to share a one-time phone location snapshot',
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
                  'REVIEW & SHARE SOS LOCATION',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.statusAlert,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Live Trip Sharing Card
            if (ticket != null) ...[
              Text(
                'ONE-TIME LOCATION SNAPSHOT',
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
                        Icon(
                          Icons.directions_bus,
                          color: colors.actionPrimary,
                          size: 24,
                        ),
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
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: double.infinity,
                        minHeight: AppSpacing.minTouchTarget,
                      ),
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            unawaited(_shareLocation(emergency: false)),
                        icon: Icon(
                          Icons.share,
                          color: colors.actionPrimary,
                          size: 18,
                        ),
                        label: Text(
                          'Share current phone location',
                          style: TextStyle(
                            color: colors.actionPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: colors.actionPrimary,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                  icon: Icon(
                    Icons.person_add_alt_1,
                    size: 18,
                    color: colors.actionPrimary,
                  ),
                  label: Text(
                    'Add Contact',
                    style: TextStyle(
                      color: colors.actionPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
                      backgroundColor: colors.actionPrimary.withValues(
                        alpha: 0.15,
                      ),
                      foregroundColor: colors.actionPrimary,
                      child: Text(
                        contact['name']![0],
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    title: Text(
                      contact['name']!,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '${contact['phone']} • ${contact['relation']}',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.phone, color: colors.statusSuccess),
                          tooltip: 'Call ${contact['name']}',
                          constraints: const BoxConstraints(
                            minWidth: AppSpacing.minTouchTarget,
                            minHeight: AppSpacing.minTouchTarget,
                          ),
                          onPressed: () => unawaited(_openDialer(contact)),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: colors.textSecondary,
                          ),
                          tooltip: 'Remove ${contact['name']}',
                          constraints: const BoxConstraints(
                            minWidth: AppSpacing.minTouchTarget,
                            minHeight: AppSpacing.minTouchTarget,
                          ),
                          onPressed: () => _removeContact(contact),
                        ),
                      ],
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
