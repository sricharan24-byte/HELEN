/// Journey page — shows active journey state.
library;

import 'package:flutter/material.dart';

import '../../core/a11y/announcement_coordinator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/tokens/app_spacing.dart';
import '../../core/tokens/status_level.dart';
import '../journey/journey_controller.dart';

/// Displays the active journey state with accessible tokens and persistent live region.
class JourneyPage extends StatelessWidget {
  const JourneyPage({super.key, required this.controller});

  final JourneyController controller;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        final isActive = state.phase == JourneyPhase.active;

        return Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            title: const Text('Journey'),
            backgroundColor: colors.background,
            foregroundColor: colors.textPrimary,
            elevation: 0,
          ),
          body: SafeArea(
            child: isActive
                ? _buildActiveView(context, state, colors)
                : _buildIdleView(context, colors),
          ),
        );
      },
    );
  }

  /// Builds the view for an active journey.
  Widget _buildActiveView(BuildContext context, JourneyState state, dynamic colors) {
    final originName = state.origin?.name ?? 'Unknown origin';
    final destinationName = state.destination?.name ?? 'Unknown destination';
    final routeName = state.selectedRoute?.displayName ?? 'Unknown route';

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Journey active heading ─────────────────────────────────
          Row(
            children: [
              Icon(StatusLevel.success.icon, color: colors.statusSuccess, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Journey active',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Transit facts card ─────────────────────────────────────
          Container(
            padding: AppSpacing.cardPadding,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: colors.border, width: colors.isHighContrast ? 2 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Origin', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colors.textSecondary)),
                const SizedBox(height: 4),
                Text(originName, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700, color: colors.textPrimary)),
                const SizedBox(height: 16),

                Text('Destination', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colors.textSecondary)),
                const SizedBox(height: 4),
                Text(destinationName, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700, color: colors.textPrimary)),
                const SizedBox(height: 16),

                Text('Route', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colors.textSecondary)),
                const SizedBox(height: 4),
                Text(routeName, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700, color: colors.textPrimary)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Current state message ─────────────────────────────────
          Divider(color: colors.border),
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(
              'Your journey is underway. '
              'Live bus location and estimated arrival time '
              'are not connected yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This is a local-first slice. '
            'Real-time tracking will be added in a future release.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 16),

          // ── Visual live status fallback from AnnouncementCoordinator ─
          ValueListenableBuilder<String>(
            valueListenable: AnnouncementCoordinator.instance.visualStatusText,
            builder: (context, visualAlert, _) {
              if (visualAlert.isEmpty) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: colors.borderFocus, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(StatusLevel.info.icon, size: 20, color: colors.borderFocus),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        visualAlert,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Builds the view when no journey is active.
  Widget _buildIdleView(BuildContext context, dynamic colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No active journey. Start a journey from the route details screen.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: colors.textPrimary),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
