import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/tokens/app_spacing.dart';
import '../../domain/transit/entities/stop.dart';

/// One-tap saved-place chips for the stop pickers.
///
/// Saved places used to own a whole home page option that showed ticket
/// history instead of places. They now live where places are actually chosen:
/// the booking origin/destination pickers and the Find-a-Place stop picker.
/// Tapping a chip selects that stop; starring inside the stop lists adds or
/// removes entries.
class SavedPlaceChips extends StatelessWidget {
  const SavedPlaceChips({
    super.key,
    required this.stops,
    required this.onSelect,
    this.selectedStopId,
    this.selectLabel = 'Set destination',
  });

  /// Resolved saved stops, in the passenger's saved order. Empty renders
  /// nothing — the pickers stay usable with their full stop lists.
  final List<Stop> stops;

  /// Called with the tapped stop (booking sets it as destination, the
  /// Find-a-Place sheet returns it to whichever field opened the sheet).
  final void Function(Stop stop) onSelect;

  /// Highlights the chip matching the picker's current value, if any.
  final String? selectedStopId;

  /// Verb used in the accessibility label, e.g. 'Set destination'.
  final String selectLabel;

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) return const SizedBox.shrink();
    final colors = AppTheme.colors(context);
    return Semantics(
      label: 'Saved places. $selectLabel by tapping a place.',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final stop in stops)
            Semantics(
              button: true,
              selected: stop.id == selectedStopId,
              label: '$selectLabel to ${stop.name}',
              excludeSemantics: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: AppSpacing.minTouchTarget,
                  minHeight: AppSpacing.minTouchTarget,
                ),
                child: ActionChip(
                  avatar: Icon(
                    Icons.star,
                    size: 18,
                    color: stop.id == selectedStopId
                        ? colors.onActionPrimary
                        : colors.actionPrimary,
                  ),
                  label: Text(
                    stop.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: stop.id == selectedStopId
                          ? colors.onActionPrimary
                          : colors.textPrimary,
                    ),
                  ),
                  backgroundColor: stop.id == selectedStopId
                      ? colors.actionPrimary
                      : colors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    side: BorderSide(
                      color: stop.id == selectedStopId
                          ? colors.actionPrimary
                          : colors.border,
                    ),
                  ),
                  onPressed: () => onSelect(stop),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
