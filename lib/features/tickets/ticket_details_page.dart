import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/tokens/app_spacing.dart';
import '../../core/tokens/status_level.dart';
import '../../data/models/ticket_model.dart';

/// Digital Ticket Pass details screen matching Image 2 reference UI with QR code and ticket perforation notches.
class TicketDetailsPage extends StatelessWidget {
  const TicketDetailsPage({
    super.key,
    required this.ticket,
  });

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: colors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
          constraints: const BoxConstraints(
            minWidth: AppSpacing.minTouchTarget,
            minHeight: AppSpacing.minTouchTarget,
          ),
        ),
        title: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Bus', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w900, fontSize: 20)),
                Text('Buddy', style: TextStyle(color: colors.actionPrimary, fontWeight: FontWeight.w900, fontSize: 20)),
              ],
            ),
            Text(
              'Ticket Details',
              style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // ── Main Ticket Boarding Pass Card with Side Notches ─────────
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC), // Light ticket card background
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      // Top Green Banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: const BoxDecoration(
                          color: Color(0xFF16A34A),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, color: Color(0xFF16A34A), size: 20),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Valid Ticket',
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Show this ticket while boarding',
                                  style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Ticket Details Body
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.directions_bus, color: Color(0xFF0F172A), size: 36),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ticket.busId,
                                      style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      '${ticket.origin.name} → ${ticket.destination.name}',
                                      style: const TextStyle(
                                        color: Color(0xFF475569),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            _buildPassDetailRow(Icons.calendar_today_outlined, _formatDate(ticket.issuedAt)),
                            const SizedBox(height: 12),
                            _buildPassDetailRow(Icons.access_time_outlined, _formatTime(ticket.issuedAt)),
                            const SizedBox(height: 12),
                            _buildPassDetailRow(Icons.currency_rupee, '₹${ticket.fareAmount.toStringAsFixed(0)}'),
                            const SizedBox(height: 12),
                            _buildPassDetailRow(Icons.confirmation_number_outlined, 'Ticket ID: ${ticket.id}'),
                            const SizedBox(height: 12),
                            _buildPassDetailRow(Icons.person_outline, 'Passenger: ${ticket.passengerName}'),
                          ],
                        ),
                      ),

                      // Dashed Perforation Line
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: List.generate(
                            30,
                            (index) => Expanded(
                              child: Container(
                                color: index % 2 == 0 ? const Color(0xFFCBD5E1) : Colors.transparent,
                                height: 2,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // QR Code Display Section
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: CustomPaint(
                                size: const Size(180, 180),
                                painter: _QrCodePainter(data: ticket.qrCodeData),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Scan this QR code while boarding',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEBF3FF),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                ticket.id,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Left Cutout Notch
                Positioned(
                  left: -14,
                  top: 250,
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: colors.background,
                  ),
                ),

                // Right Cutout Notch
                Positioned(
                  right: -14,
                  top: 250,
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: colors.background,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Dark Important Guidance Card ─────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.actionPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.info, color: colors.actionPrimaryText, size: 16),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Important',
                          style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Keep this ticket ready while boarding. This ticket is valid only for the selected bus and date.',
                          style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF475569), size: 18),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final suffix = isToday ? ' (Today)' : '';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}$suffix';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }
}

/// Vector QR code pattern painter for clean boarding pass rendering.
class _QrCodePainter extends CustomPainter {
  _QrCodePainter({required this.data});

  final String data;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    // Draw position detection finder squares (3 corners)
    _drawFinderPattern(canvas, paint, 0, 0, 48);
    _drawFinderPattern(canvas, paint, size.width - 48, 0, 48);
    _drawFinderPattern(canvas, paint, 0, size.height - 48, 48);

    // Draw grid data pixels
    final cellSize = size.width / 12;
    for (int row = 0; row < 12; row++) {
      for (int col = 0; col < 12; col++) {
        // Skip finder pattern areas
        if ((row < 4 && col < 4) || (row < 4 && col > 7) || (row > 7 && col < 4)) {
          continue;
        }
        final val = (row * 13 + col * 7 + data.hashCode) % 3;
        if (val == 0 || val == 2) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(col * cellSize + 1, row * cellSize + 1, cellSize - 2, cellSize - 2),
              const Radius.circular(2),
            ),
            paint,
          );
        }
      }
    }
  }

  void _drawFinderPattern(Canvas canvas, Paint paint, double x, double y, double size) {
    final outerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, size, size),
      const Radius.circular(8),
    );
    final innerClearRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x + 6, y + 6, size - 12, size - 12),
      const Radius.circular(4),
    );
    final centerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x + 12, y + 12, size - 24, size - 24),
      const Radius.circular(2),
    );

    canvas.drawRRect(outerRect, paint);
    canvas.drawRRect(innerClearRect, Paint()..color = Colors.white);
    canvas.drawRRect(centerRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
