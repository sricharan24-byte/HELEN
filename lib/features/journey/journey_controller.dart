import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../data/datasources/local_json_store.dart';
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
    this.activeSession,
    this.errorMessage,
  });

  final JourneyPhase phase;
  final Stop? origin;
  final Stop? destination;
  final Route? selectedRoute;
  final JourneySession? activeSession;
  final String? errorMessage;

  Map<String, dynamic> toJson() => {
    'phase': phase.name,
    if (origin != null) 'origin': origin!.toJson(),
    if (destination != null) 'destination': destination!.toJson(),
    if (selectedRoute != null) 'selectedRoute': selectedRoute!.toJson(),
    if (activeSession != null) 'activeSession': activeSession!.toJson(),
    if (errorMessage != null) 'errorMessage': errorMessage,
  };

  factory JourneyState.fromJson(Map<String, dynamic> json) {
    final phaseName = json['phase'] as String? ?? 'idle';
    final phase = JourneyPhase.values.firstWhere(
      (p) => p.name == phaseName,
      orElse: () => JourneyPhase.idle,
    );

    return JourneyState(
      phase: phase,
      origin: json['origin'] is Map<String, dynamic>
          ? Stop.fromJson(json['origin'] as Map<String, dynamic>)
          : null,
      destination: json['destination'] is Map<String, dynamic>
          ? Stop.fromJson(json['destination'] as Map<String, dynamic>)
          : null,
      selectedRoute: json['selectedRoute'] is Map<String, dynamic>
          ? Route.fromJson(json['selectedRoute'] as Map<String, dynamic>)
          : null,
      activeSession: json['activeSession'] is Map<String, dynamic>
          ? JourneySession.fromJson(json['activeSession'] as Map<String, dynamic>)
          : null,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JourneyState &&
          runtimeType == other.runtimeType &&
          phase == other.phase &&
          origin == other.origin &&
          destination == other.destination &&
          selectedRoute == other.selectedRoute &&
          activeSession == other.activeSession &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      Object.hash(phase, origin, destination, selectedRoute, activeSession, errorMessage);

  @override
  String toString() =>
      'JourneyState(phase: $phase, origin: $origin, destination: $destination, '
      'selectedRoute: $selectedRoute, activeSession: $activeSession, errorMessage: $errorMessage)';
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
  static const storageKey = 'busbuddy.active_journey.v1';
  LocalJsonStore? _store;

  JourneyState _state = const JourneyState(phase: JourneyPhase.idle);

  /// The current immutable state snapshot.
  JourneyState get state => _state;

  /// Restores active journey state from durable storage across app restarts and process death.
  Future<void> hydrate(LocalJsonStore store) async {
    await store.flush();
    _store = store;
    final stored = store.read(storageKey);
    if (stored.absent || stored.value == null) return;

    try {
      final data = stored.value;
      if (data is! Map<String, dynamic>) return;
      final restored = JourneyState.fromJson(data);

      // If active session is older than 8 hours or completed, clear it
      if (restored.activeSession != null) {
        final age = DateTime.now().difference(restored.activeSession!.startTime);
        if (age.inHours >= 8 || restored.activeSession!.isCompleted) {
          await reset();
          return;
        }
      }

      _state = restored;
      notifyListeners();
    } catch (e) {
      debugPrint('[JourneyController] Process death restoration error: $e');
    }
  }

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
  void startJourney({String? busId}) {
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

    final session = JourneySession(
      id: 'journey-${DateTime.now().millisecondsSinceEpoch}',
      routeId: route.id,
      routeName: route.displayName,
      origin: origin,
      destination: destination,
      busId: busId ?? 'Bus 18B',
      startTime: DateTime.now(),
    );

    _updateState(
      JourneyState(
        phase: JourneyPhase.active,
        origin: origin,
        destination: destination,
        selectedRoute: route,
        activeSession: session,
      ),
    );
  }

  /// Mark the ongoing journey as successfully completed.
  Future<void> completeJourney() async {
    final session = _state.activeSession;
    if (session != null) {
      _updateState(
        JourneyState(
          phase: JourneyPhase.idle,
          activeSession: session.copyWith(isCompleted: true),
        ),
      );
    } else {
      _updateState(const JourneyState(phase: JourneyPhase.idle));
    }
  }

  /// Reset the journey controller to clean idle state.
  Future<void> reset() async {
    _updateState(const JourneyState(phase: JourneyPhase.idle));
  }

  // ── Internal helpers ───────────────────────────────────────────────────

  void _persist() {
    if (_store == null) return;
    if (_state.phase == JourneyPhase.idle) {
      unawaited(_store!.write(storageKey, {'phase': 'idle'}));
    } else {
      unawaited(_store!.write(storageKey, _state.toJson()));
    }
  }

  void _updateState(JourneyState newState) {
    _state = newState;
    _persist();
    notifyListeners();
  }
}
