import 'package:flutter/material.dart' hide Route;

import '../../data/models/transport_models.dart';
import '../../domain/transit/entities/telemetry_state.dart';
import '../theme/app_theme.dart';
import '../tokens/app_spacing.dart';
import '../tokens/status_level.dart';

class MapTextAlternativeWidget extends StatelessWidget {
  const MapTextAlternativeWidget({
    super.key,
    this.route,
    required this.busLocation,
    this.freshness,
    this.errorMessage,
    this.remainingStopCount,
    this.onViewStopDetails,
  });

  final Route? route;
  final BusLocation? busLocation;
  final TelemetryFreshness? freshness;
  final String? errorMessage;
  final int? remainingStopCount;
  final VoidCallback? onViewStopDetails;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final state = freshness ??
        (busLocation == null
            ? TelemetryFreshness.loading
            : TelemetryFreshness.live);
    final hasError = state == TelemetryFreshness.error;
    final canDisplayValues = !hasError && busLocation != null;
    final location = canDisplayValues ? busLocation : null;
    final statusText = switch (state) {
      TelemetryFreshness.loading => 'WAITING',
      TelemetryFreshness.live => location!.isSimulated ? 'SIMULATED' : 'LIVE',
      TelemetryFreshness.stale => 'STALE',
      TelemetryFreshness.offline => 'OFFLINE',
      TelemetryFreshness.error => 'ERROR',
    };
    final nextStopText = location?.nextStopName ?? 'Waiting for telemetry';
    final etaText = location == null
        ? hasError
            ? 'Telemetry unavailable'
            : 'Waiting for telemetry'
        : '${location.etaMinutes} min${state == TelemetryFreshness.stale ? ' (last update)' : ''}';
    final speedText = location == null
        ? hasError
            ? 'Unavailable'
            : 'Waiting'
        : '${location.speedKmh.toStringAsFixed(0)} km/h${state == TelemetryFreshness.stale ? ' (last update)' : ''}';
    final stopCountText = remainingStopCount != null
        ? '$remainingStopCount stops remaining'
        : '${route?.orderedStopIds.length ?? 0} stops on route';
    final title = location?.isSimulated ?? false
        ? 'Simulated Bus Telemetry (Map Alternative)'
        : 'Live Bus Telemetry (Map Alternative)';
    final stateDescription = switch (state) {
      TelemetryFreshness.loading => 'Waiting for the first telemetry update.',
      TelemetryFreshness.live => location!.isSimulated
          ? 'This is simulated telemetry, not live GPS.'
          : 'Telemetry is current.',
      TelemetryFreshness.stale => 'The latest telemetry is stale.',
      TelemetryFreshness.offline => 'Telemetry is offline.',
      TelemetryFreshness.error => errorMessage ?? 'Telemetry is unavailable.',
    };

    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: hasError ? colors.statusError : colors.border,
          width: colors.isHighContrast || hasError ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              Icon(StatusLevel.info.icon, color: colors.actionPrimary, size: 20),
              Semantics(
                header: true,
                headingLevel: 2,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: hasError ? colors.statusAlertBg : colors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: hasError ? colors.statusError : colors.actionPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            liveRegion: true,
            child: Text(
              stateDescription,
              style: TextStyle(
                color: hasError ? colors.statusError : colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(color: colors.border),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            label: 'Next Stop: $nextStopText',
            excludeSemantics: true,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 4,
              children: [
                Text(
                  'Next Stop: ',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
                Text(
                  nextStopText,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            label: 'Estimated Arrival: $etaText',
            excludeSemantics: true,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 4,
              children: [
                Text(
                  'Estimated Arrival: ',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
                Text(
                  etaText,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: hasError ? colors.statusError : colors.actionPrimary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            label: 'Speed: $speedText, $stopCountText',
            excludeSemantics: true,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 4,
              children: [
                Text(
                  'Current Speed: ',
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
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(
                    AppSpacing.minTouchTarget,
                    AppSpacing.minTouchTarget,
                  ),
                  foregroundColor: colors.textPrimary,
                  side: BorderSide(color: colors.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
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
