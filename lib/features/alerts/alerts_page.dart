import 'package:flutter/material.dart';

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  static const List<Map<String, dynamic>> _alerts = [
    {
      'title': 'Bus TN-23-BUS-42 On Time',
      'subtitle': 'Operating on VIT Main Gate → Katpadi Railway Station corridor. ETA 4 mins to Gandhi Nagar.',
      'time': '2 mins ago',
      'type': 'status',
      'icon': Icons.directions_bus,
      'iconColor': Color(0xFF059669),
    },
    {
      'title': 'Minor Traffic Delay near Green Circle',
      'subtitle': 'Expect +3 mins delay due to road maintenance near Green Circle junction.',
      'time': '15 mins ago',
      'type': 'warning',
      'icon': Icons.warning_amber_rounded,
      'iconColor': Color(0xFFD97706),
    },
    {
      'title': 'Auditory Voice Announcements Enabled',
      'subtitle': 'TalkBack and audio cues will announce each upcoming stop 500 meters prior to arrival.',
      'time': '1 hour ago',
      'type': 'info',
      'icon': Icons.volume_up_outlined,
      'iconColor': Color(0xFF002B7F),
    },
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('Live Corridor Alerts'),
        centerTitle: true,
        backgroundColor: const Color(0xFFF4F6F8),
        foregroundColor: const Color(0xFF002B7F),
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _alerts.length,
        itemBuilder: (context, index) {
          final alert = _alerts[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (alert['iconColor'] as Color).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(alert['icon'] as IconData, color: alert['iconColor'] as Color, size: 24),
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
                            child: Text(
                              alert['title'] as String,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0A2540),
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Text(
                            alert['time'] as String,
                            style: textTheme.bodySmall?.copyWith(color: const Color(0xFF94A3B8), fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alert['subtitle'] as String,
                        style: textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF64748B),
                          height: 1.3,
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
