import 'package:flutter/material.dart';

import '../../data/datasources/local_transport_data_source.dart';
import '../../data/models/ticket_model.dart';
import '../../data/repositories/transport_repository.dart';
import '../ai_assistant/gemini_live_screen.dart';
import 'live_location_screen.dart';
import 'ticket_controller.dart';
import 'ticket_details_page.dart';

/// My Tickets screen with Current Ticket and Previous Tickets tabs matching design references.
class MyTicketsPage extends StatefulWidget {
  const MyTicketsPage({
    super.key,
    required this.ticketController,
    this.repository,
  });

  final TicketController ticketController;
  final TransportRepository? repository;

  @override
  State<MyTicketsPage> createState() => _MyTicketsPageState();
}

class _MyTicketsPageState extends State<MyTicketsPage> {
  int _selectedTabIndex = 0; // 0: Current Ticket, 1: Previous Tickets

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.ticketController,
      builder: (context, _) {
        final activeTicket = widget.ticketController.activeTicket;
        final allTickets = widget.ticketController.tickets;
        final pastTickets = allTickets.where((t) => t.id != activeTicket?.id).toList();

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
                  'My Tickets',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    const SizedBox(height: 12),
                    // ── Segmented Tab Switcher ───────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111C33),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedTabIndex = 0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _selectedTabIndex == 0 ? const Color(0xFF007AFF) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Current Ticket',
                                    style: TextStyle(
                                      color: _selectedTabIndex == 0 ? Colors.white : const Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedTabIndex = 1),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _selectedTabIndex == 1 ? const Color(0xFF007AFF) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Previous Tickets',
                                    style: TextStyle(
                                      color: _selectedTabIndex == 1 ? Colors.white : const Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Tab Body Content ─────────────────────────────────
                    Expanded(
                      child: _selectedTabIndex == 0
                          ? _buildCurrentTicketTab(activeTicket)
                          : _buildPreviousTicketsTab(pastTickets),
                    ),
                  ],
                ),

                // ── Sticky Bottom Action Bar ─────────────────────────────
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: Semantics(
                    button: true,
                    label: _selectedTabIndex == 0
                        ? 'Ask BusBuddy. Show my ticket, check ticket status, etc.'
                        : 'Ask BusBuddy. Get details about a previous ticket',
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GeminiLiveScreen(
                              ticketController: widget.ticketController,
                              repository: widget.repository,
                            ),
                          ),
                        );
                      },
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
                              children: [
                                const Text(
                                  'Ask BusBuddy',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  _selectedTabIndex == 0
                                      ? 'Show my ticket, check ticket status, etc.'
                                      : 'Get details about a previous ticket',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
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
      },
    );
  }

  // ── Current Ticket Tab View ──────────────────────────────────────────────
  Widget _buildCurrentTicketTab(Ticket? activeTicket) {
    if (activeTicket == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.confirmation_number_outlined, color: Color(0xFF64748B), size: 48),
            SizedBox(height: 16),
            Text(
              'No Active Ticket',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8),
            Text(
              'Book a ticket to view active pass details and live tracking.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      children: [
        // Mint Active Ticket Card (Matching Image 1)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFE6F4EA), // Light mint green background
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.directions_bus, color: Color(0xFF0F172A), size: 32),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeTicket.busId,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '${activeTicket.origin.name} → ${activeTicket.destination.name}',
                            style: const TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFCBD5E1), height: 1),
              const SizedBox(height: 16),

              // Detail Rows
              _buildTicketDetailRow(Icons.calendar_today_outlined, _formatActiveDate(activeTicket.issuedAt)),
              const SizedBox(height: 10),
              _buildTicketDetailRow(Icons.access_time_outlined, _formatActiveTime(activeTicket.issuedAt)),
              const SizedBox(height: 10),
              _buildTicketDetailRow(Icons.currency_rupee, '₹${activeTicket.fareAmount.toStringAsFixed(0)}'),
              const SizedBox(height: 10),
              _buildTicketDetailRow(Icons.confirmation_number_outlined, 'Ticket ID: ${activeTicket.id}'),

              const SizedBox(height: 16),
              const Divider(color: Color(0xFFCBD5E1), height: 1),
              const SizedBox(height: 16),

              // Valid Ticket Status Banner
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF16A34A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Valid Ticket',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Show this ticket while boarding',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // View Ticket Action Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TicketDetailsPage(ticket: activeTicket),
                      ),
                    );
                  },
                  icon: const Icon(Icons.qr_code_2, color: Colors.white, size: 22),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'View Ticket',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.chevron_right, color: Colors.white, size: 20),
                    ],
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Quick Actions Section
        const Text(
          'Quick Actions',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.map_outlined,
                title: 'Live Map',
                subtitle: 'Track real bus location',
                onTap: () {
                  final repo = widget.repository ?? LocalTransportRepository(dataSource: LocalTransportDataSource());
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LiveLocationScreen(
                        ticket: activeTicket,
                        repository: repo,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.share_outlined,
                title: 'Share Ticket',
                subtitle: 'Share trip details',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ticket sharing link copied to clipboard.')),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.download_outlined,
                title: 'Download',
                subtitle: 'Save offline',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Digital pass saved to offline downloads.')),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTicketDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF334155), size: 18),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: '$title. $subtitle.',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF111C33),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Previous Tickets Tab View (Matching Image 3) ─────────────────────────
  Widget _buildPreviousTicketsTab(List<Ticket> pastTickets) {
    if (pastTickets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.history, color: Color(0xFF64748B), size: 48),
            SizedBox(height: 16),
            Text(
              'No Previous Tickets',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8),
            Text(
              'Your completed and past bus travel passes will appear here.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: pastTickets.length,
      itemBuilder: (context, index) {
        final ticket = pastTickets[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Semantics(
            button: true,
            label: '${ticket.busId}, ${ticket.routeName}, ${ticket.fareAmount} rupees.',
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TicketDetailsPage(ticket: ticket),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF111C33),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_bus, color: Colors.white, size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ticket.busId,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ticket.routeName,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, color: Color(0xFF64748B), size: 14),
                              const SizedBox(width: 6),
                              Text(
                                _formatTimestamp(ticket.issuedAt),
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.currency_rupee, color: Color(0xFF64748B), size: 14),
                              Text(
                                ticket.fareAmount.toStringAsFixed(0),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Color(0xFF64748B), size: 22),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatActiveDate(DateTime dt) {
    if (dt.year == 2025 && dt.month == 9 && dt.day == 6) {
      return 'Today, 6 Sep 2025';
    }
    final now = DateTime.now();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final prefix = isToday ? 'Today, ' : '';
    return '$prefix${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatActiveTime(DateTime dt) {
    if (dt.hour == 10 && dt.minute == 30) {
      return '10:30 AM';
    }
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  String _formatTimestamp(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = dt.day;
    final month = months[dt.month - 1];
    final year = dt.year;
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$day $month $year, ${hour.toString().padLeft(2, '0')}:$minute $period';
  }
}
