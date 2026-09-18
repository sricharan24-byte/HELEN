/// Journey page — shows active journey state.
library;

import 'package:flutter/material.dart';

import '../journey/journey_controller.dart';

/// Displays the active journey state.
///
/// Shows origin, destination, selected route, and a current-state message.
/// Explicitly communicates that live bus location and ETA are not yet
/// connected.
class JourneyPage extends StatelessWidget {
  const JourneyPage({super.key, required this.controller});

  final JourneyController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        final isActive = state.phase == JourneyPhase.active;

        return Scaffold(
          appBar: AppBar(title: const Text('Journey')),
          body: SafeArea(
            child: isActive
                ? _buildActiveView(context, state)
                : _buildIdleView(context),
          ),
        );
      },
    );
  }

  /// Builds the view for an active journey.
  Widget _buildActiveView(BuildContext context, JourneyState state) {
    final originName = state.origin?.name ?? 'Unknown origin';
    final destinationName = state.destination?.name ?? 'Unknown destination';
    final routeName = state.selectedRoute?.displayName ?? 'Unknown route';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Journey active heading ─────────────────────────────────
          Semantics(
            header: true,
            child: Text(
              'Journey active',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 24),

          // ── Origin ────────────────────────────────────────────────
          Text('Origin', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(originName, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),

          // ── Destination ───────────────────────────────────────────
          Text('Destination', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(destinationName, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),

          // ── Selected route ────────────────────────────────────────
          Text('Route', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(routeName, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 24),

          // ── Current state message ─────────────────────────────────
          const Divider(),
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(
              'Your journey is underway. '
              'Live bus location and estimated arrival time '
              'are not connected yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This is a local-first slice. '
            'Real-time tracking will be added in a future release.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  /// Builds the view when no journey is active.
  Widget _buildIdleView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No active journey. Start a journey from the route details screen.',
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
