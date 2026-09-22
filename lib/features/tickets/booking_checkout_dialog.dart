import 'package:flutter/material.dart';

import '../../core/a11y/announcement_coordinator.dart';
import '../../core/di/service_locator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/tokens/app_semantic_colors.dart';
import '../../core/tokens/app_spacing.dart';
import '../../core/tokens/status_level.dart';
import '../../data/models/ticket_model.dart';
import '../../data/models/transport_models.dart';
import '../../domain/ticketing/entities/fare_engine.dart';

/// Modal bottom sheet for passenger type selection, payment checkout, and ticket issuance.
/// Fully conforms to Astra Step 2.4 with semantic tokens, 48dp minimum touch targets,
/// multi-modal concession badges, and AnnouncementCoordinator integration.
class BookingCheckoutDialog extends StatefulWidget {
  const BookingCheckoutDialog({
    super.key,
    required this.busId,
    required this.routeName,
    required this.origin,
    required this.destination,
    this.baseFare,
    this.initialFareQuote,
    required this.onTicketBooked,
    this.routeId = 'vit-to-katpadi',
    this.travelDate,
  });

  final String busId;
  final String routeName;
  final Stop origin;
  final Stop destination;
  final double? baseFare;
  final FareQuote? initialFareQuote;
  final void Function(Ticket ticket) onTicketBooked;
  final String routeId;
  final DateTime? travelDate;

  @override
  State<BookingCheckoutDialog> createState() => _BookingCheckoutDialogState();
}

class _BookingCheckoutDialogState extends State<BookingCheckoutDialog> {
  PassengerType _selectedPassengerType = PassengerType.general;
  PaymentMethod _selectedPaymentMethod = PaymentMethod.upi;
  late TextEditingController _passengerNameController;
  bool _isIssuing = false;

  @override
  void initState() {
    super.initState();
    _passengerNameController = TextEditingController();
  }

  @override
  void dispose() {
    _passengerNameController.dispose();
    super.dispose();
  }

  int _resolveHops() {
    if (widget.initialFareQuote != null && widget.initialFareQuote!.hopCount > 0) {
      return widget.initialFareQuote!.hopCount;
    }
    final dataSource = AppServiceLocator.instance.transportDataSource;
    final route = dataSource.allRoutes.firstWhere(
      (r) => r.id == widget.routeId,
      orElse: () => dataSource.allRoutes.first,
    );
    final o = route.orderedStopIds.indexOf(widget.origin.id);
    final d = route.orderedStopIds.indexOf(widget.destination.id);
    if (o != -1 && d != -1) {
      final hops = (d - o).abs();
      if (hops > 0) return hops;
    }
    if (widget.baseFare != null && widget.baseFare! > 0) {
      if (widget.baseFare! <= 15) return 2;
      if (widget.baseFare! <= 20) return 4;
      return 6;
    }
    return 4; // Standard corridor fallback
  }

  FareQuote _quoteForType(PassengerType type) {
    final hopCount = _resolveHops();
    return FareEngine.calculateByStopCount(
      stopCount: hopCount,
      passengerType: type,
    );
  }

  FareQuote get _currentFareQuote => _quoteForType(_selectedPassengerType);

  void _issueTicket() {
    if (_isIssuing) return;
    setState(() => _isIssuing = true);

    final now = DateTime.now();
    final ticketId = Ticket.generateSecureTicketId(now);
    final travelDay = widget.travelDate ?? now;
    final dayEnd = DateTime(
      travelDay.year,
      travelDay.month,
      travelDay.day,
      23, 59, 59,
    );
    final finalizedValidUntil =
        dayEnd.isBefore(now) ? now.add(const Duration(hours: 4)) : dayEnd;

    final passengerName = _passengerNameController.text.trim().isEmpty
        ? 'Passenger'
        : _passengerNameController.text.trim();

    final quote = _currentFareQuote;
    final qrPayload = Ticket.buildQrPayload(
      ticketId: ticketId,
      originId: widget.origin.id,
      destinationId: widget.destination.id,
      busId: widget.busId,
      farePaise: quote.finalPaise,
      validUntil: finalizedValidUntil,
      isDemo: true,
    );

    final ticket = Ticket(
      id: ticketId,
      routeId: widget.routeId,
      routeName: widget.routeName,
      origin: widget.origin,
      destination: widget.destination,
      busId: widget.busId,
      passengerName: passengerName,
      passengerType: _selectedPassengerType,
      fareQuote: quote,
      paymentMethod: _selectedPaymentMethod,
      issuedAt: now,
      validUntil: finalizedValidUntil,
      status: TicketStatus.active,
      qrCodeData: qrPayload,
      isDemo: true,
    );

    widget.onTicketBooked(ticket);

    AnnouncementCoordinator.instance.announce(
      'Ticket confirmed for $passengerName. Paid ₹${(quote.finalPaise / 100).toStringAsFixed(0)}. Bus ${widget.busId}.',
      priority: AnnouncementPriority.high,
    );

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);


    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: colors.border),
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
                  color: colors.border,
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
                      Semantics(
                        header: true,
                        child: Text(
                          'Confirm Ticket & Pay',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Bus ${widget.busId} • ${widget.origin.name} → ${widget.destination.name}',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.science_outlined, size: 12, color: colors.textSecondary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'DEMO MODE • Simulated UPI Gateway',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colors.textPrimary),
                  tooltip: 'Cancel checkout',
                  onPressed: () => Navigator.of(context).pop(false),
                  constraints: const BoxConstraints(
                    minWidth: AppSpacing.minTouchTarget,
                    minHeight: AppSpacing.minTouchTarget,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Passenger Name Input
            Text(
              'PASSENGER NAME',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passengerNameController,
              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.person, color: colors.actionPrimary),
                filled: true,
                fillColor: colors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                hintText: 'Enter passenger name',
                hintStyle: TextStyle(color: colors.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  borderSide: BorderSide(color: colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  borderSide: BorderSide(color: colors.actionPrimary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Passenger Type Selection
            Row(
              children: [
                Flexible(
                  child: Text(
                    'PASSENGER TYPE & CONCESSION',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_selectedPassengerType != PassengerType.general)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.statusSuccessBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: colors.statusSuccess),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(StatusLevel.success.icon, size: 10, color: colors.statusSuccess),
                        const SizedBox(width: 3),
                        Text(
                          '40% CONCESSION',
                          style: TextStyle(
                            color: colors.statusSuccess,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildPassengerChip(
                    type: PassengerType.general,
                    label: 'General',
                    sublabel: _quoteForType(PassengerType.general).formattedAmount,
                    colors: colors,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPassengerChip(
                    type: PassengerType.student,
                    label: 'Student',
                    sublabel: _quoteForType(PassengerType.student).formattedAmount,
                    colors: colors,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPassengerChip(
                    type: PassengerType.senior,
                    label: 'Senior',
                    sublabel: _quoteForType(PassengerType.senior).formattedAmount,
                    colors: colors,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Payment Method Selection
            Text(
              'PAYMENT METHOD',
              style: TextStyle(
                color: colors.textSecondary,
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
              colors: colors,
            ),
            const SizedBox(height: 8),
            _buildPaymentOptionTile(
              method: PaymentMethod.card,
              icon: Icons.credit_card,
              title: 'Credit / Debit Card',
              subtitle: 'Visa, Mastercard, RuPay',
              colors: colors,
            ),
            const SizedBox(height: 8),
            _buildPaymentOptionTile(
              method: PaymentMethod.wallet,
              icon: Icons.account_balance_wallet_outlined,
              title: 'BusBuddy Wallet',
              subtitle: 'Balance: ₹250.00',
              colors: colors,
            ),
            const SizedBox(height: 24),

            // Fare Summary & Issue Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: colors.border),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 12,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL FARE',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentFareQuote.formattedAmount,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
                    child: ElevatedButton.icon(
                      onPressed: _isIssuing ? null : _issueTicket,
                      icon: _isIssuing
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.actionPrimaryText,
                              ),
                            )
                          : Icon(Icons.check_circle_outline, color: colors.actionPrimaryText, size: 20),
                      label: Text(
                        _isIssuing ? 'Processing...' : 'Pay ${_currentFareQuote.formattedAmount} & Issue',
                        style: TextStyle(
                          color: colors.actionPrimaryText,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.actionPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        minimumSize: const Size(120, AppSpacing.minTouchTarget),
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
    required AppSemanticColors colors,
  }) {
    final isSelected = _selectedPassengerType == type;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedPassengerType = type),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? colors.actionPrimary.withValues(alpha: 0.15) : colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? colors.actionPrimary : colors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? colors.actionPrimary : colors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: TextStyle(
                  color: isSelected ? colors.actionPrimary : colors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOptionTile({
    required PaymentMethod method,
    required IconData icon,
    required String title,
    required String subtitle,
    required AppSemanticColors colors,
  }) {
    final isSelected = _selectedPaymentMethod == method;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedPaymentMethod = method),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? colors.actionPrimary.withValues(alpha: 0.1) : colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? colors.actionPrimary : colors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? colors.actionPrimary : colors.textSecondary,
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
                        color: colors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(color: colors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected ? colors.actionPrimary : colors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
