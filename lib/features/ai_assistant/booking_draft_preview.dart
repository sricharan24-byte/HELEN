import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/tokens/app_semantic_colors.dart';
import '../../core/tokens/app_spacing.dart';
import '../../domain/ticketing/entities/fare.dart';
import '../../domain/ticketing/entities/fare_engine.dart';
import '../../domain/ticketing/entities/ticket.dart';
import 'app_automation_controller.dart';

/// Live, glanceable preview of what the voice booking agent has built so far.
///
/// The voice conversation fills the draft slot by slot, but speech alone is
/// ephemeral: provenance (your choice vs. profile default vs. suggestion) and
/// the current fare were previously invisible until checkout opened. This card
/// mirrors the draft in real time — it is a pure listener on
/// [AppAutomationController] and changes nothing about the voice flow, the
/// session, or the single-speaker contract.
///
/// Judgment call (revert freely): the card carries plain Semantics labels but
/// deliberately NO live region — the assistant already narrates every slot
/// change by voice, and a second announcement channel is the overlap class of
/// bug Chunks 41/42 spent whole chunks killing.
class BookingDraftPreview extends StatelessWidget {
  const BookingDraftPreview({super.key, required this.automation});

  final AppAutomationController automation;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: automation,
      builder: (context, _) {
        final active = automation.slotSources.values.any(
          (source) => source != BookingValueSource.unset,
        );
        if (!active) return const SizedBox.shrink();
        return _buildCard(context, AppTheme.colors(context));
      },
    );
  }

  Widget _buildCard(BuildContext context, AppSemanticColors colors) {
    final hasSuggestion = automation.slotSources.values.any(
      (source) => source == BookingValueSource.recentActivity,
    );
    final missing = automation.missingBookingSlots;
    final fare = _estimateFare();

    return Semantics(
      container: true,
      label: 'Booking draft preview. The voice assistant is filling your '
          'booking. ${_summaryLine()}',
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceSubtle,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.smart_toy_outlined,
                    color: colors.actionPrimary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Booking draft',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    missing.isEmpty
                        ? 'Ready to review'
                        : _missingLabel(missing),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: missing.isEmpty
                          ? colors.statusSuccess
                          : colors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _slotRow(
              colors,
              icon: Icons.trip_origin,
              label: 'Trip',
              value: _tripValue(),
              source: _combinedTripSource(),
            ),
            _slotRow(
              colors,
              icon: Icons.directions_bus_outlined,
              label: 'Bus',
              // The '18B' constructor fallback is not a choice: show it as
              // unset, exactly like the payment row does for UPI.
              value: automation.slotSources['bus'] == BookingValueSource.unset
                  ? 'Not set yet'
                  : automation.busId,
              source: automation.slotSources['bus']!,
            ),
            _slotRow(
              colors,
              icon: Icons.person_outline,
              label: 'Passenger',
              value: automation.passengerType == PassengerType.general &&
                      automation.slotSources['passengerType'] ==
                          BookingValueSource.unset
                  ? 'Not set yet'
                  : _passengerLabel(),
              source: automation.slotSources['passengerType']!,
            ),
            _slotRow(
              colors,
              icon: Icons.payment_outlined,
              label: 'Payment',
              value: automation.slotSources['paymentMethod'] ==
                      BookingValueSource.unset
                  ? 'Not set yet'
                  : automation.paymentMethod.name,
              source: automation.slotSources['paymentMethod']!,
            ),
            if (fare != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.payments_outlined,
                      color: colors.textSecondary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Estimated fare ${fare.formattedAmount} — final at checkout',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            if (hasSuggestion) ...[
              const SizedBox(height: 10),
              _suggestionBanner(colors),
            ],
          ],
        ),
      ),
    );
  }

  /// One draft slot line: icon, label, current value, provenance chip.
  /// Rows reflow (no fixed heights) so 300% text scale never clips.
  Widget _slotRow(
    AppSemanticColors colors, {
    required IconData icon,
    required String label,
    required String value,
    required BookingValueSource source,
  }) {
    final chip = _chipColors(colors, source);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.textSecondary, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  '$label: ',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: chip.$2,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text(
                    chip.$1,
                    style: TextStyle(
                      color: chip.$3,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The staged-suggestion banner: the one place where a suggestion can be
  /// accepted or dismissed — the deterministic acceptance path the voice
  /// flow alone could not offer.
  Widget _suggestionBanner(AppSemanticColors colors) {
    final origin = automation.origin?.name ?? 'your usual origin';
    final destination = automation.destination?.name ?? 'your usual stop';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.statusWarningBg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: colors.statusWarning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suggested from your recent trips: $origin → $destination '
            'on ${automation.busId}.',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.actionPrimary,
                      side: BorderSide(color: colors.actionPrimary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: automation.acceptStagedSuggestion,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text(
                      'Use this trip',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textSecondary,
                      side: BorderSide(color: colors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: automation.dismissStagedSuggestion,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text(
                      'Not now',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _tripValue() {
    final origin = automation.origin?.name;
    final destination = automation.destination?.name;
    if (origin == null && destination == null) return 'Not set yet';
    if (destination == null) return origin!;
    if (origin == null) return destination;
    return '$origin → $destination';
  }

  /// The trip line's provenance: the weaker of the two slot sources, so a
  /// suggestion-staged destination never masquerades as chosen.
  BookingValueSource _combinedTripSource() {
    final origin = automation.slotSources['origin']!;
    final destination = automation.slotSources['destination']!;
    const order = [
      BookingValueSource.unset,
      BookingValueSource.appDefault,
      BookingValueSource.recentActivity,
      BookingValueSource.profileDefault,
      BookingValueSource.passenger,
    ];
    return order.firstWhere(
      (s) => s == origin || s == destination,
      orElse: () => BookingValueSource.unset,
    );
  }

  String _passengerLabel() {
    final type = automation.passengerType;
    final base = type.name[0].toUpperCase() + type.name.substring(1);
    final name = automation.passengerName;
    if (name.isEmpty || name == 'Passenger') return base;
    return '$base • $name';
  }

  String _summaryLine() {
    final missing = automation.missingBookingSlots;
    if (missing.isEmpty) {
      return 'Trip, bus, passenger and payment are chosen. Ready to review '
          'and confirm.';
    }
    return 'Still needed: ${_missingLabel(missing)}.';
  }

  String _missingLabel(List<String> missing) {
    final labels = missing.map((slot) {
      switch (slot) {
        case 'trip':
          return 'origin & destination';
        case 'bus':
          return 'bus';
        case 'passenger':
          return 'passenger type';
        case 'payment':
          return 'payment method';
        default:
          return slot;
      }
    }).toList();
    return labels.length <= 1
        ? labels.first
        : '${labels.take(labels.length - 1).join(', ')} and ${labels.last}';
  }

  /// (label, background, foreground) for a provenance chip. Red is never
  /// used — nothing here is an emergency or an error.
  (String, Color, Color) _chipColors(
    AppSemanticColors colors,
    BookingValueSource source,
  ) {
    switch (source) {
      case BookingValueSource.passenger:
        return ('You chose', colors.statusSuccessBg, colors.statusSuccess);
      case BookingValueSource.profileDefault:
        return ('Your default', colors.actionPrimary, colors.onActionPrimary);
      case BookingValueSource.recentActivity:
        return ('Suggestion', colors.statusWarningBg, colors.statusWarning);
      case BookingValueSource.appDefault:
        return ('App default', colors.surfaceSubtle, colors.textMuted);
      case BookingValueSource.unset:
        return ('Not set yet', colors.surfaceSubtle, colors.textMuted);
    }
  }

  /// Integer-paise fare estimate, shown only when the trip is a real
  /// passenger choice on a known route — no invented numbers.
  FareQuote? _estimateFare() {
    final route = automation.route;
    final origin = automation.origin;
    final destination = automation.destination;
    if (route == null || origin == null || destination == null) return null;
    if (!automation.isSlotSatisfied('origin') ||
        !automation.isSlotSatisfied('destination')) {
      return null;
    }
    final originIdx = route.orderedStopIds.indexOf(origin.id);
    final destIdx = route.orderedStopIds.indexOf(destination.id);
    if (originIdx == -1 || destIdx == -1) return null;
    final hops = (destIdx - originIdx).abs();
    if (hops <= 0) return null;
    return FareEngine.calculateByStopCount(
      stopCount: hops,
      passengerType: automation.passengerType,
    );
  }
}
