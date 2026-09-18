import 'dart:math';
import 'package:flutter/material.dart';

import '../../data/models/ticket_model.dart';
import '../../data/models/transport_models.dart';

/// Modal bottom sheet for passenger type selection, payment checkout, and ticket issuance.
class BookingCheckoutDialog extends StatefulWidget {
  const BookingCheckoutDialog({
    super.key,
    required this.busId,
    required this.routeName,
    required this.origin,
    required this.destination,
    required this.baseFare,
    required this.onTicketBooked,
    this.routeId = 'vit-to-katpadi',
  });

  final String busId;
  final String routeName;
  final Stop origin;
  final Stop destination;
  final double baseFare;
  final void Function(Ticket ticket) onTicketBooked;
  final String routeId;

  @override
  State<BookingCheckoutDialog> createState() => _BookingCheckoutDialogState();
}

class _BookingCheckoutDialogState extends State<BookingCheckoutDialog> {
  PassengerType _selectedPassengerType = PassengerType.general;
  PaymentMethod _selectedPaymentMethod = PaymentMethod.upi;
  late TextEditingController _passengerNameController;

  @override
  void initState() {
    super.initState();
    _passengerNameController = TextEditingController(text: 'Pavan K');
  }

  @override
  void dispose() {
    _passengerNameController.dispose();
    super.dispose();
  }

  double get _finalFare {
    switch (_selectedPassengerType) {
      case PassengerType.student:
      case PassengerType.senior:
        return (widget.baseFare * 0.6).roundToDouble();
      case PassengerType.general:
        return widget.baseFare;
    }
  }

  void _issueTicket() {
    final ticketId = 'BB${Random().nextInt(899999) + 100000}';
    final ticket = Ticket(
      id: ticketId,
      routeId: widget.routeId,
      routeName: widget.routeName,
      origin: widget.origin,
      destination: widget.destination,
      busId: widget.busId,
      passengerName: _passengerNameController.text.trim().isEmpty
          ? 'Pavan K'
          : _passengerNameController.text.trim(),
      passengerType: _selectedPassengerType,
      fareAmount: _finalFare,
      paymentMethod: _selectedPaymentMethod,
      issuedAt: DateTime.now(),
      validUntil: DateTime.now().add(const Duration(hours: 4)),
      status: TicketStatus.active,
      qrCodeData: 'BUSBUDDY-PASS-$ticketId',
    );

    widget.onTicketBooked(ticket);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0B101D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title & Subtitle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Confirm Ticket & Pay',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Bus ${widget.busId} • ${widget.origin.name} → ${widget.destination.name}',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Passenger Name Input
            const Text(
              'PASSENGER NAME',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passengerNameController,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.person, color: Color(0xFF38BDF8)),
                filled: true,
                fillColor: const Color(0xFF111C33),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF1E293B)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF1E293B)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Passenger Type Selection
            const Text(
              'PASSENGER TYPE & CONCESSION',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildPassengerChip(
                    type: PassengerType.general,
                    label: 'General',
                    sublabel: '₹${widget.baseFare.toStringAsFixed(0)}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPassengerChip(
                    type: PassengerType.student,
                    label: 'Student',
                    sublabel: '₹${(widget.baseFare * 0.6).toStringAsFixed(0)}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPassengerChip(
                    type: PassengerType.senior,
                    label: 'Senior',
                    sublabel: '₹${(widget.baseFare * 0.6).toStringAsFixed(0)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Payment Method Selection
            const Text(
              'PAYMENT METHOD',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            _buildPaymentOptionTile(
              method: PaymentMethod.upi,
              icon: Icons.qr_code_2,
              title: 'UPI (GPay / PhonePe / Paytm)',
              subtitle: 'Instant 1-tap UPI payment',
            ),
            const SizedBox(height: 8),
            _buildPaymentOptionTile(
              method: PaymentMethod.card,
              icon: Icons.credit_card,
              title: 'Credit / Debit Card',
              subtitle: 'Visa, Mastercard, RuPay',
            ),
            const SizedBox(height: 8),
            _buildPaymentOptionTile(
              method: PaymentMethod.wallet,
              icon: Icons.account_balance_wallet_outlined,
              title: 'BusBuddy Wallet',
              subtitle: 'Balance: ₹250.00',
            ),
            const SizedBox(height: 24),

            // Fare Summary & Issue Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111C33),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL FARE',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${_finalFare.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _issueTicket,
                      icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                      label: Text(
                        'Pay ₹${_finalFare.toStringAsFixed(0)} & Issue',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                      ),
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

  Widget _buildPassengerChip({
    required PassengerType type,
    required String label,
    required String sublabel,
  }) {
    final isSelected = _selectedPassengerType == type;
    return InkWell(
      onTap: () => setState(() => _selectedPassengerType = type),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF007AFF) : const Color(0xFF111C33),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF1E293B),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: TextStyle(
                color: isSelected ? Colors.white70 : const Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOptionTile({
    required PaymentMethod method,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedPaymentMethod == method;
    return InkWell(
      onTap: () => setState(() => _selectedPaymentMethod = method),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF111C33),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF1E293B),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
