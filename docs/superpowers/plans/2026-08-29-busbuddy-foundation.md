# BusBuddy Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first accessible Flutter vertical slice for the VIT Vellore → Katpadi Railway Station corridor.

**Architecture:** Use a dependency-light, feature-based Flutter app. Presentation widgets depend on a small journey controller, which depends on repository interfaces backed by local curated fixtures. Route facts remain outside widgets so a simulator, Firebase source, or routing service can be added later without changing the core journey screens.

**Tech Stack:** Flutter/Dart, Flutter SDK widgets, local in-memory fixtures, Flutter widget tests, Dart format and analyzer.

**Spec:** `docs/superpowers/specs/2026-08-29-busbuddy-foundation-design.md`

## Global Constraints

- Platform: Flutter Android-first application.
- Corridor: VIT Vellore → Katpadi Railway Station with approximately 10–20 curated stops.
- Data: local fixtures only; no external service is required for the first slice.
- Accessibility: meaningful semantics, task-order focus, state announcements, readable text, and tap targets of at least 48×48 logical pixels.
- Scope: no maps, geocoding, Firebase, live fleet feeds, Gemini, computer vision, UWB, authentication, payments, or user accounts in this slice.
- Verification: run formatting, static analysis, widget tests, and a manual TalkBack pass when an Android device or emulator is available.

---

## File map

- Create `pubspec.yaml` and the generated Flutter platform files through `flutter create .`.
- Create `lib/main.dart` as the composition root.
- Create `lib/core/theme/app_theme.dart` for the accessible visual system.
- Create `lib/data/models/transport_models.dart` for `Stop`, `Route`, and `JourneySelection`.
- Create `lib/data/datasources/local_transport_data_source.dart` for the Vellore fixture corridor.
- Create `lib/data/repositories/transport_repository.dart` for route and place lookup interfaces and the local implementation.
- Create `lib/features/journey/journey_controller.dart` for selection and journey state transitions.
- Create `lib/features/home/home_page.dart` for the task-oriented landing screen.
- Create `lib/features/route_search/route_search_page.dart` for origin/destination selection and route results.
- Create `lib/features/route_details/route_details_page.dart` for selected route facts and the start action.
- Create `lib/features/journey/journey_page.dart` for the active local journey state.
- Create `test/data/transport_repository_test.dart` for fixture and route-matching behavior.
- Create `test/features/journey_controller_test.dart` for state transitions and validation.
- Create `test/features/route_search_page_test.dart` for semantics and route-result rendering.
- Create `test/features/route_details_page_test.dart` for selection and journey transition.

## Task 1: Scaffold the Flutter application

**Files:**
- Create: Flutter project files via `flutter create .`
- Modify: `pubspec.yaml`
- Create: `lib/main.dart`

**Interfaces:**
- Produces a runnable Flutter application with `flutter run` and the standard test/analyzer commands.

- [ ] **Step 1: Verify the Flutter toolchain**

Run:

```bash
flutter --version
dart --version
```

Expected: Flutter and Dart versions print successfully. If Flutter is unavailable, stop and report the missing toolchain before changing application code.

- [ ] **Step 2: Generate the project shell**

Run:

```bash
flutter create --platforms=android .
```

Expected: Android project files, `pubspec.yaml`, `lib/main.dart`, and `test/widget_test.dart` are created without overwriting the approved design/spec documents.

- [ ] **Step 3: Replace the generated smoke test with the project test entry point**

Delete the generated `test/widget_test.dart` only after confirming it is the default counter-app test, then create the focused tests in later tasks.

- [ ] **Step 4: Run the scaffold verification**

Run:

```bash
flutter analyze
flutter test
```

Expected: PASS with no analyzer errors and no failing tests.

## Task 2: Add transport models, fixtures, and repository

**Files:**
- Create: `lib/data/models/transport_models.dart`
- Create: `lib/data/datasources/local_transport_data_source.dart`
- Create: `lib/data/repositories/transport_repository.dart`
- Test: `test/data/transport_repository_test.dart`

**Interfaces:**
- `Stop({required String id, required String name, required String area})`.
- `Route({required String id, required String displayName, required String direction, required List<String> orderedStopIds})`.
- `JourneySelection({required Stop origin, required Stop destination, required Route route})`.
- `TransportRepository.findStops(String query) -> List<Stop>`.
- `TransportRepository.findRoutes({required String originId, required String destinationId}) -> List<Route>`.
- `TransportRepository.getStop(String stopId) -> Stop?`.
- `LocalTransportRepository` implements the interface using a `LocalTransportDataSource`.

- [ ] **Step 1: Write failing repository tests**

```dart
test('finds the VIT origin stop case-insensitively', () {
  final results = repository.findStops('vit');
  expect(results.single.name, 'VIT Main Gate');
});

test('returns a route from VIT to Katpadi Railway Station', () {
  final routes = repository.findRoutes(
    originId: 'vit-main-gate',
    destinationId: 'katpadi-railway-station',
  );
  expect(routes, hasLength(1));
  expect(routes.single.orderedStopIds.first, 'vit-main-gate');
  expect(routes.single.orderedStopIds.last, 'katpadi-railway-station');
});

test('returns no route for an unsupported destination', () {
  expect(
    repository.findRoutes(
      originId: 'vit-main-gate',
      destinationId: 'unsupported-place',
    ),
    isEmpty,
  );
});
```

- [ ] **Step 2: Run the focused tests to verify they fail**

Run: `flutter test test/data/transport_repository_test.dart`

Expected: FAIL because the models, repository, and fixture source do not exist.

- [ ] **Step 3: Implement the models and a 10–20 stop local corridor**

Include `vit-main-gate`, intermediate Vellore stops, and `katpadi-railway-station`. Store the route’s ordered stop IDs in the fixture source, not in UI code. Normalize search with `trim().toLowerCase()` and match against stop name and area.

- [ ] **Step 4: Run the focused tests to verify they pass**

Run: `flutter test test/data/transport_repository_test.dart`

Expected: PASS.

## Task 3: Add theme, controller, and application shell

**Files:**
- Create: `lib/core/theme/app_theme.dart`
- Create: `lib/features/journey/journey_controller.dart`
- Modify: `lib/main.dart`
- Test: `test/features/journey_controller_test.dart`

**Interfaces:**
- `JourneyPhase { idle, originSelected, destinationSelected, routeSelected, active, error }`.
- `JourneyState({required JourneyPhase phase, Stop? origin, Stop? destination, Route? selectedRoute, String? errorMessage})`.
- `JourneyController.selectOrigin(Stop stop) -> void`.
- `JourneyController.selectDestination(Stop stop) -> void`.
- `JourneyController.searchRoutes() -> List<Route>`.
- `JourneyController.selectRoute(Route route) -> void`.
- `JourneyController.startJourney() -> void`.

- [ ] **Step 1: Write failing controller tests**

```dart
test('requires both places before searching', () {
  final controller = JourneyController(repository);
  expect(controller.searchRoutes(), isEmpty);
  expect(controller.state.errorMessage, 'Choose an origin and destination first.');
});

test('moves from route selection to an active journey', () {
  final controller = JourneyController(repository);
  controller.selectOrigin(repository.getStop('vit-main-gate')!);
  controller.selectDestination(repository.getStop('katpadi-railway-station')!);
  final route = controller.searchRoutes().single;
  controller.selectRoute(route);
  controller.startJourney();
  expect(controller.state.phase, JourneyPhase.active);
});
```

- [ ] **Step 2: Run the focused tests to verify they fail**

Run: `flutter test test/features/journey_controller_test.dart`

Expected: FAIL because the controller and theme do not exist.

- [ ] **Step 3: Implement the controller and theme**

Use `ChangeNotifier` with immutable `JourneyState` snapshots. Expose the current state and notify listeners after every valid transition. Make the primary color high-contrast, use a readable default text theme, and ensure buttons have a minimum visual and semantic target size.

- [ ] **Step 4: Wire `MaterialApp` to the home page placeholder**

`main()` must create one `LocalTransportRepository`, one `JourneyController`, and pass the controller to `HomePage`. Do not create repositories inside individual widgets.

- [ ] **Step 5: Run the focused tests to verify they pass**

Run: `flutter test test/features/journey_controller_test.dart`

Expected: PASS.

## Task 4: Build the home and route-search flow

**Files:**
- Create: `lib/features/home/home_page.dart`
- Create: `lib/features/route_search/route_search_page.dart`
- Test: `test/features/route_search_page_test.dart`

**Interfaces:**
- `HomePage({required JourneyController controller})`.
- `RouteSearchPage({required JourneyController controller, required TransportRepository repository})`.
- The search page calls `controller.selectOrigin`, `controller.selectDestination`, and `controller.searchRoutes`.

- [ ] **Step 1: Write failing widget tests for accessible search**

In `test/features/route_search_page_test.dart`, define `testApp()` to construct a `MaterialApp` with a `LocalTransportRepository`, a `JourneyController`, and `HomePage`. Define `openSearchAndChooseVelloreCorridor(tester)` to tap `Plan a journey`, tap `Choose starting stop`, tap the `VIT Main Gate` list item, tap `Choose destination stop`, tap the `Katpadi Railway Station` list item, and tap the labeled search action.

```dart
testWidgets('exposes labeled origin and destination controls', (tester) async {
  await tester.pumpWidget(testApp());
  await tester.tap(find.bySemanticsLabel('Plan a journey'));
  await tester.pumpAndSettle();
  expect(find.bySemanticsLabel('Choose starting stop'), findsOneWidget);
  expect(find.bySemanticsLabel('Choose destination stop'), findsOneWidget);
});

testWidgets('renders a deterministic route result after both places are chosen', (tester) async {
  await tester.pumpWidget(testApp());
  await openSearchAndChooseVelloreCorridor(tester);
  expect(find.text('VIT to Katpadi'), findsOneWidget);
  expect(find.bySemanticsLabel('View route VIT to Katpadi'), findsOneWidget);
});
```

- [ ] **Step 2: Run the focused tests to verify they fail**

Run: `flutter test test/features/route_search_page_test.dart`

Expected: FAIL because the pages and semantics labels do not exist.

- [ ] **Step 3: Implement the home screen**

Show the BusBuddy title, a concise purpose statement, and one prominent button with semantic label `Plan a journey`. Keep the primary action above secondary content and avoid a map-first dashboard.

- [ ] **Step 4: Implement origin and destination selection**

Use labeled buttons that open a searchable local list. Each result must expose the stop name and area. Preserve the selected value in the button’s visible text and semantic label. Disable route search until both selections exist and announce the reason.

- [ ] **Step 5: Implement route results**

Render route display name, direction, number of stops, and a text status. Do not use color as the only status signal. Each result has a labeled action to open route details.

- [ ] **Step 6: Run the focused tests to verify they pass**

Run: `flutter test test/features/route_search_page_test.dart`

Expected: PASS.

## Task 5: Build route details and active journey state

**Files:**
- Create: `lib/features/route_details/route_details_page.dart`
- Create: `lib/features/journey/journey_page.dart`
- Modify: `lib/main.dart` or the navigation composition file from Task 4
- Test: `test/features/route_details_page_test.dart`

**Interfaces:**
- `RouteDetailsPage({required JourneyController controller, required TransportRepository repository, required Route route})`.
- `JourneyPage({required JourneyController controller, required TransportRepository repository})`.
- The details page calls `controller.startJourney()` and navigates to `JourneyPage`.

- [ ] **Step 1: Write failing widget tests for route details and journey transition**

In `test/features/route_details_page_test.dart`, define `routeDetailsTestApp()` to construct a `MaterialApp` with a repository, a controller whose origin is `vit-main-gate`, destination is `katpadi-railway-station`, and the matching route selected, then display `RouteDetailsPage`.

```dart
testWidgets('shows boarding stop and ordered stop facts', (tester) async {
  await tester.pumpWidget(routeDetailsTestApp());
  expect(find.text('Board at VIT Main Gate'), findsOneWidget);
  expect(find.textContaining('Stops on this route'), findsOneWidget);
});

testWidgets('starts the journey and exposes current journey state', (tester) async {
  await tester.pumpWidget(routeDetailsTestApp());
  await tester.tap(find.bySemanticsLabel('Start this journey'));
  await tester.pumpAndSettle();
  expect(find.bySemanticsLabel('Journey active'), findsOneWidget);
  expect(find.text('Your journey has started'), findsOneWidget);
});
```

- [ ] **Step 2: Run the focused tests to verify they fail**

Run: `flutter test test/features/route_details_page_test.dart`

Expected: FAIL because the details and journey pages do not exist.

- [ ] **Step 3: Implement route details**

Show route name, direction, boarding stop, destination, ordered stop list, and a clearly labeled `Start this journey` button. Use headings and grouped sections so TalkBack users can understand the page structure.

- [ ] **Step 4: Implement the active journey page**

Show a semantic heading `Journey active`, origin, destination, selected route, current phase text, and the next useful action. In this local phase, state that live bus location and ETA are not yet connected rather than displaying fabricated live values.

- [ ] **Step 5: Run the focused tests to verify they pass**

Run: `flutter test test/features/route_details_page_test.dart`

Expected: PASS.

## Task 6: Run full verification and manual accessibility review

**Files:**
- Modify: any implementation files needed to resolve analyzer/test failures
- Test: all files under `test/`

- [ ] **Step 1: Format the project**

Run: `dart format lib test`

Expected: all Dart files are formatted with no errors.

- [ ] **Step 2: Run static analysis**

Run: `flutter analyze`

Expected: no analyzer errors or warnings that affect the first slice.

- [ ] **Step 3: Run all automated tests**

Run: `flutter test`

Expected: all repository, controller, and widget tests pass.

- [ ] **Step 4: Run the Android app**

Run `flutter devices` to identify an Android device or emulator, then run `flutter run` while that device is selected.

Expected: the app launches and the complete local journey flow works without network access.

- [ ] **Step 5: Perform the TalkBack checklist**

On an Android device or emulator with TalkBack enabled, verify: the title is announced; `Plan a journey` is discoverable; origin and destination controls announce their current values; route results announce route name, direction, and stop count; route details announce boarding stop and destination; `Start this journey` is reachable; the active journey announces `Journey active`; and no fact is conveyed only through color, map, or icon.

- [ ] **Step 6: Record verification results**

Update the handoff or a build-notes file with the Flutter version, device/emulator used, automated test result, and TalkBack findings. Do not claim the slice is complete until the automated checks and the available manual review have been performed.
