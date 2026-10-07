import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/tokens/app_spacing.dart';
import '../../core/widgets/bus_buddy_logo.dart';
import '../../core/tokens/status_level.dart';

/// Live Corridor Alerts page with multi-modal indicators (WCAG 1.4.1)
/// and full semantic design tokens.
class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  static const List<Map<String, dynamic>> _alerts = [
    {
      'title': 'Bus TN-23-BUS-42 On Time',
      'subtitle': 'Operating on VIT Main Gate → Katpadi Railway Station corridor. ETA 4 mins to Gandhi Nagar.',
      'time': '2 mins ago',
      'level': StatusLevel.success,
      'icon': Icons.directions_bus,
    },
    {
      'title': 'Minor Traffic Delay near Green Circle',
      'subtitle': 'Expect +3 mins delay due to road maintenance near Green Circle junction.',
      'time': '15 mins ago',
      'level': StatusLevel.warning,
      'icon': Icons.warning_amber_rounded,
    },
    {
      'title': 'Auditory Voice Announcements Enabled',
      'subtitle': 'TalkBack and audio cues will announce each upcoming stop 500 meters prior to arrival.',
      'time': '1 hour ago',
      'level': StatusLevel.info,
      'icon': Icons.volume_up_outlined,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const BusBuddyLogo(
          fontSize: 20,
          subtitle: 'Live Corridor Alerts',
        ),
        centerTitle: true,
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: AppSpacing.pagePadding,
        itemCount: _alerts.length,
        itemBuilder: (context, index) {
          final alert = _alerts[index];
          final level = alert['level'] as StatusLevel;

          final statusColor = switch (level) {
            StatusLevel.success => colors.statusSuccess,
            StatusLevel.warning => colors.statusWarning,
            StatusLevel.error => colors.statusAlert,
            StatusLevel.info => colors.actionPrimary,
          };

          final statusBg = switch (level) {
            StatusLevel.success => colors.statusSuccessBg,
            StatusLevel.warning => colors.statusWarningBg,
            StatusLevel.error => colors.statusAlertBg,
            StatusLevel.info => colors.surface,
          };

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: statusColor),
                  ),
                  child: Icon(alert['icon'] as IconData, color: statusColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: Text(
                                alert['title'] as String,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: colors.textPrimary,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            alert['time'] as String,
                            style: TextStyle(color: colors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alert['subtitle'] as String,
                        style: TextStyle(
                          color: colors.textSecondary,
                          height: 1.35,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
