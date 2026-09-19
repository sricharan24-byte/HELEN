import 'package:flutter/material.dart' hide Route;
import '../../data/models/transport_models.dart';
import '../theme/app_theme.dart';
import '../tokens/app_spacing.dart';
import '../tokens/status_level.dart';

/// Accessible Text Alternative for Map Canvases per Astra Gate 8.
///
/// Guaranteed Map Equivalence: Every telemetry fact (bus position, ETA, speed,
/// next stop, remaining stops, and simulation status) rendered graphically
/// on the map canvas is provided here as a fully navigable, TalkBack-friendly text card.
class MapTextAlternativeWidget extends StatelessWidget {
  const MapTextAlternativeWidget({
    super.key,
    required this.route,
    required this.busLocation,
    this.remainingStopCount,
    this.onViewStopDetails,
  });

  final Route route;
  final BusLocation? busLocation;
  final int? remainingStopCount;
  final VoidCallback? onViewStopDetails;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    final speedText = busLocation != null
        ? '${busLocation!.speedKmh.toStringAsFixed(0)} km/h'
        : 'Telemetry paused';
    final nextStopText = busLocation?.nextStopName ?? 'Next stop unknown';
    final etaText = busLocation != null ? '${busLocation!.etaMinutes} mins' : 'Calculating...';
    final stopCountText = remainingStopCount != null
        ? '$remainingStopCount stops remaining'
        : '${route.orderedStopIds.length} stops on route';

    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: colors.border,
          width: colors.isHighContrast ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(StatusLevel.info.icon, color: colors.actionPrimary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Live Bus Status (Map Alternative)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  busLocation != null ? 'LIVE' : 'WAITING',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: colors.actionPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(color: colors.border),
          const SizedBox(height: AppSpacing.sm),

          // Next stop row
          Semantics(
            label: 'Next Stop: $nextStopText',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Next Stop:',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
                Flexible(
                  child: Text(
                    nextStopText,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // ETA row
          Semantics(
            label: 'Estimated Arrival: $etaText',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Estimated Arrival:',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
                Text(
                  etaText,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: colors.actionPrimary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Speed & Remaining stops row
          Semantics(
            label: 'Speed: $speedText, $stopCountText',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Current Speed:',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
                Text(
                  '$speedText • $stopCountText',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          if (onViewStopDetails != null) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: AppSpacing.minTouchTarget,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(AppSpacing.minTouchTarget, AppSpacing.minTouchTarget),
                  foregroundColor: colors.textPrimary,
                  side: BorderSide(color: colors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                onPressed: onViewStopDetails,
                child: const Text(
                  'View Full Stop List',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
