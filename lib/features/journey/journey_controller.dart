import 'package:flutter/foundation.dart';

import '../../data/models/transport_models.dart';
import '../../data/repositories/transport_repository.dart';

// ---------------------------------------------------------------------------
// Phase enum
// ---------------------------------------------------------------------------

/// Lifecycle phases of a journey through the BusBuddy corridor.
enum JourneyPhase {
  idle,
  originSelected,
  destinationSelected,
  routeSelected,
  active,
  error,
}

// ---------------------------------------------------------------------------
// Immutable state
// ---------------------------------------------------------------------------

/// A snapshot of the journey wizard's current progress.
///
/// All fields are final; callers cannot mutate the state through the object.
class JourneyState {
  const JourneyState({
    required this.phase,
    this.origin,
    this.destination,
    this.selectedRoute,
    this.errorMessage,
  });

  final JourneyPhase phase;
  final Stop? origin;
  final Stop? destination;
  final Route? selectedRoute;
  final String? errorMessage;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JourneyState &&
          runtimeType == other.runtimeType &&
          phase == other.phase &&
          origin == other.origin &&
          destination == other.destination &&
          selectedRoute == other.selectedRoute &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      Object.hash(phase, origin, destination, selectedRoute, errorMessage);

  @override
  String toString() =>
      'JourneyState(phase: $phase, origin: $origin, destination: $destination, '
      'selectedRoute: $selectedRoute, errorMessage: $errorMessage)';
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

/// Manages the journey selection wizard.
///
/// Uses [ChangeNotifier] so that UI widgets can listen for state changes.
class JourneyController extends ChangeNotifier {
  JourneyController(this._repository);

  final TransportRepository _repository;

  JourneyState _state = const JourneyState(phase: JourneyPhase.idle);

  /// The current immutable state snapshot.
  JourneyState get state => _state;

  // ── Mutations ──────────────────────────────────────────────────────────

  /// Select an origin [stop].
  ///
  /// Clears any prior error. If a destination was already selected the phase
  /// advances to [JourneyPhase.destinationSelected]; otherwise it becomes
  /// [JourneyPhase.originSelected].
  void selectOrigin(Stop stop) {
    final existingDestination = _state.destination;
    final nextPhase = existingDestination != null
        ? JourneyPhase.destinationSelected
        : JourneyPhase.originSelected;

    _updateState(
      JourneyState(
        phase: nextPhase,
        origin: stop,
        destination: existingDestination,
      ),
    );
  }

  /// Select a destination [stop].
  ///
  /// Requires an origin to have been selected first; otherwise the controller
  /// transitions to [JourneyPhase.error] with an explanatory message.
  void selectDestination(Stop stop) {
    if (_state.origin == null) {
      _updateState(
        const JourneyState(
          phase: JourneyPhase.error,
          errorMessage: 'Choose an origin first.',
        ),
      );
      return;
    }

    _updateState(
      JourneyState(
        phase: JourneyPhase.destinationSelected,
        origin: _state.origin,
        destination: stop,
      ),
    );
  }

  /// Search for routes between the selected origin and destination.
  ///
  /// Returns the list of matching [Route]s. When either selection is missing
  /// the controller transitions to an error state and returns an empty list.
  List<Route> searchRoutes() {
    final origin = _state.origin;
    final destination = _state.destination;

    if (origin == null || destination == null) {
      _updateState(
        JourneyState(
          phase: JourneyPhase.error,
          origin: origin,
          destination: destination,
          errorMessage: 'Choose an origin and destination first.',
        ),
      );
      return const [];
    }

    final routes = _repository.findRoutes(
      originId: origin.id,
      destinationId: destination.id,
    );

    if (routes.isEmpty) {
      _updateState(
        JourneyState(
          phase: JourneyPhase.error,
          origin: origin,
          destination: destination,
          errorMessage: 'No routes found for this journey.',
        ),
      );
      return const [];
    }

    // Routes found — keep phase at destinationSelected (no new enum value).
    // Existing selectedRoute is cleared since we have a fresh search.
    _updateState(
      JourneyState(
        phase: JourneyPhase.destinationSelected,
        origin: origin,
        destination: destination,
      ),
    );

    return routes;
  }

  /// Pick one [route] from search results.
  void selectRoute(Route route) {
    _updateState(
      JourneyState(
        phase: JourneyPhase.routeSelected,
        origin: _state.origin,
        destination: _state.destination,
        selectedRoute: route,
      ),
    );
  }

  /// Begin the journey.
  ///
  /// Requires origin, destination, and selected route to all be set; otherwise
  /// the controller transitions to an error state.
  void startJourney() {
    final origin = _state.origin;
    final destination = _state.destination;
    final route = _state.selectedRoute;

    if (origin == null || destination == null || route == null) {
      _updateState(
        JourneyState(
          phase: JourneyPhase.error,
          origin: origin,
          destination: destination,
          selectedRoute: route,
          errorMessage: 'Select a route before starting your journey.',
        ),
      );
      return;
    }

    _updateState(
      JourneyState(
        phase: JourneyPhase.active,
        origin: origin,
        destination: destination,
        selectedRoute: route,
      ),
    );
  }

  // ── Internal helpers ───────────────────────────────────────────────────

  void _updateState(JourneyState newState) {
    _state = newState;
    notifyListeners();
  }
}
