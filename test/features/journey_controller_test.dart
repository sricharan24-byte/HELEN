/// Tests for [JourneyController] — Task 3 TDD red/green cycle.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:busbuddy/data/models/transport_models.dart';
import 'package:busbuddy/data/repositories/transport_repository.dart';
import 'package:busbuddy/features/journey/journey_controller.dart';

// ---------------------------------------------------------------------------
// Fake repository – no external mocking library required.
// ---------------------------------------------------------------------------

class FakeTransportRepository implements TransportRepository {
  FakeTransportRepository({List<Stop>? stops, List<Route>? routes})
    : _stops = stops ?? const [],
      _routes = routes ?? const [];

  final List<Stop> _stops;
  final List<Route> _routes;

  /// Tracks calls for verification.
  int findRoutesCalls = 0;

  @override
  List<Stop> findStops(String query) => _stops;

  @override
  List<Route> findRoutes({
    required String originId,
    required String destinationId,
  }) {
    findRoutesCalls++;
    return _routes;
  }

  @override
  List<Route> get allRoutes => _routes;

  @override
  Stream<BusLocation> streamBusLocation(String busId, String routeId) {
    return const Stream.empty();
  }

  @override
  Stop? getStop(String stopId) {
    for (final s in _stops) {
      if (s.id == stopId) return s;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Fixture stops and routes mirroring the VIT→Katpadi corridor.
// ---------------------------------------------------------------------------

const vitMainGate = Stop(
  id: 'vit-main-gate',
  name: 'VIT Main Gate',
  area: 'VIT University',
);
const katpadiStation = Stop(
  id: 'katpadi-railway-station',
  name: 'Katpadi Railway Station',
  area: 'Katpadi',
);
const clockTower = Stop(
  id: 'clock-tower',
  name: 'Clock Tower',
  area: 'Vellore Town',
);

const corridorRoute = Route(
  id: 'vit-to-katpadi',
  displayName: 'VIT → Katpadi Railway Station',
  direction: 'inbound',
  orderedStopIds: [
    'vit-main-gate',
    'old-katpadi',
    'chittoor-bus-stop',
    'katpadi-bus-stand',
    'katpadi-railway-station',
  ],
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── Initial state ──────────────────────────────────────────────────────
  group('initial state', () {
    test('starts in idle phase with all fields null', () {
      final repo = FakeTransportRepository();
      final controller = JourneyController(repo);

      expect(controller.state.phase, JourneyPhase.idle);
      expect(controller.state.origin, isNull);
      expect(controller.state.destination, isNull);
      expect(controller.state.selectedRoute, isNull);
      expect(controller.state.errorMessage, isNull);
    });
  });

  // ── selectOrigin ───────────────────────────────────────────────────────
  group('selectOrigin', () {
    test('stores origin and transitions to originSelected', () {
      final controller = JourneyController(FakeTransportRepository());

      controller.selectOrigin(vitMainGate);

      expect(controller.state.phase, JourneyPhase.originSelected);
      expect(controller.state.origin, vitMainGate);
      expect(controller.state.errorMessage, isNull);
    });

    test('clears a prior error message', () {
      final controller = JourneyController(FakeTransportRepository());

      // Trigger an error first.
      controller.selectDestination(katpadiStation); // no origin → error
      expect(controller.state.phase, JourneyPhase.error);

      // Now select an origin – error should clear.
      controller.selectOrigin(vitMainGate);
      expect(controller.state.errorMessage, isNull);
      expect(controller.state.phase, JourneyPhase.originSelected);
    });

    test('transitions to destinationSelected when destination already set', () {
      final controller = JourneyController(FakeTransportRepository());

      // The brief says: "sets phase to originSelected unless a destination is
      // already selected". To get destination set, we need origin first.
      controller.selectOrigin(vitMainGate);
      controller.selectDestination(katpadiStation);
      expect(controller.state.phase, JourneyPhase.destinationSelected);

      // Now re-select origin – destination is still set, so phase should
      // remain destinationSelected.
      controller.selectOrigin(clockTower);
      expect(controller.state.phase, JourneyPhase.destinationSelected);
      expect(controller.state.origin, clockTower);
      expect(controller.state.destination, katpadiStation);
    });
  });

  // ── selectDestination ──────────────────────────────────────────────────
  group('selectDestination', () {
    test('sets error when no origin has been chosen', () {
      final controller = JourneyController(FakeTransportRepository());

      controller.selectDestination(katpadiStation);

      expect(controller.state.phase, JourneyPhase.error);
      expect(controller.state.errorMessage, 'Choose an origin first.');
    });

    test('stores destination and transitions to destinationSelected', () {
      final controller = JourneyController(FakeTransportRepository());

      controller.selectOrigin(vitMainGate);
      controller.selectDestination(katpadiStation);

      expect(controller.state.phase, JourneyPhase.destinationSelected);
      expect(controller.state.destination, katpadiStation);
      expect(controller.state.errorMessage, isNull);
    });
  });

  // ── searchRoutes ───────────────────────────────────────────────────────
  group('searchRoutes', () {
    test('returns error when origin is missing', () {
      final repo = FakeTransportRepository(routes: [corridorRoute]);
      final controller = JourneyController(repo);

      final results = controller.searchRoutes();

      expect(results, isEmpty);
      expect(controller.state.phase, JourneyPhase.error);
      expect(
        controller.state.errorMessage,
        'Choose an origin and destination first.',
      );
      expect(repo.findRoutesCalls, 0);
    });

    test('returns error when destination is missing', () {
      final repo = FakeTransportRepository(routes: [corridorRoute]);
      final controller = JourneyController(repo);

      controller.selectOrigin(vitMainGate);
      final results = controller.searchRoutes();

      expect(results, isEmpty);
      expect(controller.state.phase, JourneyPhase.error);
      expect(
        controller.state.errorMessage,
        'Choose an origin and destination first.',
      );
      expect(repo.findRoutesCalls, 0);
    });

    test('delegates to repository and returns routes when both selected', () {
      final repo = FakeTransportRepository(routes: [corridorRoute]);
      final controller = JourneyController(repo);

      controller.selectOrigin(vitMainGate);
      controller.selectDestination(katpadiStation);
      final results = controller.searchRoutes();

      expect(results, [corridorRoute]);
      expect(controller.state.phase, JourneyPhase.destinationSelected);
      expect(controller.state.errorMessage, isNull);
      expect(repo.findRoutesCalls, 1);
    });

    test('sets error when repository returns no routes', () {
      final repo = FakeTransportRepository(routes: const []);
      final controller = JourneyController(repo);

      controller.selectOrigin(vitMainGate);
      controller.selectDestination(katpadiStation);
      final results = controller.searchRoutes();

      expect(results, isEmpty);
      expect(controller.state.phase, JourneyPhase.error);
      expect(
        controller.state.errorMessage,
        'No routes found for this journey.',
      );
    });
  });

  // ── selectRoute ────────────────────────────────────────────────────────
  group('selectRoute', () {
    test('stores route and transitions to routeSelected', () {
      final controller = JourneyController(FakeTransportRepository());

      controller.selectRoute(corridorRoute);

      expect(controller.state.phase, JourneyPhase.routeSelected);
      expect(controller.state.selectedRoute, corridorRoute);
    });
  });

  // ── startJourney ───────────────────────────────────────────────────────
  group('startJourney', () {
    test('sets error when route has not been selected', () {
      final controller = JourneyController(FakeTransportRepository());

      controller.selectOrigin(vitMainGate);
      controller.selectDestination(katpadiStation);
      controller.startJourney();

      expect(controller.state.phase, JourneyPhase.error);
      expect(
        controller.state.errorMessage,
        'Select a route before starting your journey.',
      );
    });

    test('sets error when origin is missing', () {
      final controller = JourneyController(FakeTransportRepository());

      controller.selectDestination(katpadiStation); // errors
      controller.selectRoute(corridorRoute);
      controller.startJourney();

      expect(controller.state.phase, JourneyPhase.error);
      expect(
        controller.state.errorMessage,
        'Select a route before starting your journey.',
      );
    });
  });

  // ── Full VIT→Katpadi happy path ────────────────────────────────────────
  group('full happy path (VIT → Katpadi)', () {
    test(
      'idle → originSelected → destinationSelected → search → routeSelected → active',
      () {
        final repo = FakeTransportRepository(routes: [corridorRoute]);
        final controller = JourneyController(repo);

        // 1. Select origin
        controller.selectOrigin(vitMainGate);
        expect(controller.state.phase, JourneyPhase.originSelected);

        // 2. Select destination
        controller.selectDestination(katpadiStation);
        expect(controller.state.phase, JourneyPhase.destinationSelected);

        // 3. Search routes
        final routes = controller.searchRoutes();
        expect(routes, isNotEmpty);
        expect(controller.state.phase, JourneyPhase.destinationSelected);

        // 4. Select route
        controller.selectRoute(corridorRoute);
        expect(controller.state.phase, JourneyPhase.routeSelected);

        // 5. Start journey
        controller.startJourney();
        expect(controller.state.phase, JourneyPhase.active);
        expect(controller.state.origin, vitMainGate);
        expect(controller.state.destination, katpadiStation);
        expect(controller.state.selectedRoute, corridorRoute);
        expect(controller.state.errorMessage, isNull);
      },
    );
  });

  // ── ChangeNotifier notification ────────────────────────────────────────
  group('ChangeNotifier', () {
    test('notifies listeners on state change', () {
      final controller = JourneyController(FakeTransportRepository());

      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.selectOrigin(vitMainGate);
      controller.selectDestination(katpadiStation);
      controller.selectRoute(corridorRoute);
      controller.startJourney();

      expect(notifyCount, 4);
    });
  });
}
