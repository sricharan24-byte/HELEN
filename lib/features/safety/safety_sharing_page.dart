import 'package:flutter/material.dart';

import '../../data/models/ticket_model.dart';
import '../../data/models/adaptive_shortcut.dart';
import '../../data/repositories/emergency_contact_repository.dart';
import '../adaptive_ui/adaptive_ui_service.dart';

class SafetySharingPage extends StatefulWidget {
  const SafetySharingPage({super.key, this.activeTicket});

  final Ticket? activeTicket;

  @override
  State<SafetySharingPage> createState() => _SafetySharingPageState();
}

class _SafetySharingPageState extends State<SafetySharingPage> {
  final _contacts = EmergencyContactRepository.instance;

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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Emergency Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Contact Name / Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone Number (+91)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (_nameCtrl.text.trim().isNotEmpty && _phoneCtrl.text.trim().isNotEmpty) {
                _contacts.addContact({
                  'name': _nameCtrl.text,
                  'phone': _phoneCtrl.text,
                  'relation': 'Trusted',
                });
                _nameCtrl.clear();
                _phoneCtrl.clear();
              }
              Navigator.of(ctx).pop();
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF002B7F)),
            child: const Text('Add Contact'),
          ),
        ],
      ),
    );
  }

  void _triggerSosAlert() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFE11D48), size: 28),
            SizedBox(width: 10),
            Text('Trigger SOS Alert?'),
          ],
        ),
        content: const Text(
          'This will immediately send an urgent emergency alert containing your live GPS bus coordinates to all trusted contacts and campus security.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              AdaptiveUiService.instance.recordGenericEvent(
                actionType: 'sos',
                title: 'Emergency SOS Broadcast',
                subtitle: 'Safety assistance alert',
                type: AdaptiveShortcutType.safety,
              );
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🚨 SOS Alert Broadcasted to Emergency Contacts & Campus Security!'),
                  backgroundColor: Color(0xFFE11D48),
                ),
              );
            },
            icon: const Icon(Icons.sos, size: 18),
            label: const Text('BROADCAST SOS NOW'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE11D48)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final ticket = widget.activeTicket;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('Safety & Emergency Sharing'),
        centerTitle: true,
        backgroundColor: const Color(0xFFF4F6F8),
        foregroundColor: const Color(0xFF002B7F),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SOS Banner Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE11D48),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_outlined, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1-Tap Emergency Broadcast',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF9F1239),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Send immediate location distress alerts to trusted contacts',
                          style: textTheme.bodySmall?.copyWith(color: const Color(0xFFBE123C)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // SOS Broadcast Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _triggerSosAlert,
                icon: const Icon(Icons.sos, size: 24),
                label: Text(
                  'BROADCAST SOS ALERT NOW',
                  style: textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE11D48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Live Trip Sharing Card
            if (ticket != null) ...[
              Text(
                'ACTIVE TRIP LIVE SHARING',
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.directions_bus, color: Color(0xFF002B7F), size: 24),
                        const SizedBox(width: 10),
                        Text(
                          'Bus ${ticket.busId}',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0A2540),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${ticket.origin.name} → ${ticket.destination.name}',
                      style: textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Opening WhatsApp to share live trip link...')),
                          );
                        },
                        icon: const Icon(Icons.share, color: Color(0xFF002B7F), size: 18),
                        label: const Text('Share Live Trip via WhatsApp / SMS'),
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
                Text(
                  'TRUSTED EMERGENCY CONTACTS',
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF64748B),
                  ),
                ),
                TextButton.icon(
                  onPressed: _addContact,
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('Add Contact'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Contacts List
            ..._contacts.contacts.map((contact) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFE8EEFF),
                    foregroundColor: const Color(0xFF002B7F),
                    child: Text(contact['name']![0], style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  title: Text(contact['name']!, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0A2540))),
                  subtitle: Text('${contact['phone']} • ${contact['relation']}', style: const TextStyle(color: Color(0xFF64748B))),
                  trailing: IconButton(
                    icon: const Icon(Icons.phone, color: Color(0xFF059669)),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Calling ${contact['name']} (${contact['phone']})...')),
                      );
                    },
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
