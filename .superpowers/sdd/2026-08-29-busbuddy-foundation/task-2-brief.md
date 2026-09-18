# Task 2: Transport models, fixtures, and repository

Read this brief first. Work in `/home/pavan/BusBuddy` and implement only the transport data layer for the BusBuddy VIT Vellore → Katpadi Railway Station slice.

## Files

- Create `lib/data/models/transport_models.dart`.
- Create `lib/data/datasources/local_transport_data_source.dart`.
- Create `lib/data/repositories/transport_repository.dart`.
- Create `test/data/transport_repository_test.dart`.

## Interfaces

- `Stop({required String id, required String name, required String area})`.
- `Route({required String id, required String displayName, required String direction, required List<String> orderedStopIds})`.
- `JourneySelection({required Stop origin, required Stop destination, required Route route})`.
- `TransportRepository.findStops(String query) -> List<Stop>`.
- `TransportRepository.findRoutes({required String originId, required String destinationId}) -> List<Route>`.
- `TransportRepository.getStop(String stopId) -> Stop?`.
- `LocalTransportRepository` implements the interface using a `LocalTransportDataSource`.

## Behavior

- Use a curated local fixture corridor with 10–20 ordered stops, beginning with `vit-main-gate` named `VIT Main Gate` and ending with `katpadi-railway-station` named `Katpadi Railway Station`.
- Include an intermediate Vellore stop list that gives route details meaningful content. Keep all fixture data in the data source, not UI code.
- `findStops` trims and lowercases the query, matches stop name or area, and returns matching stops in fixture order. An empty query returns all stops.
- `findRoutes` returns the corridor route when the origin occurs before the destination in `orderedStopIds`; otherwise it returns an empty list.
- `getStop` returns null for unknown IDs.
- Keep the implementation dependency-free beyond the Flutter/Dart SDK.

## TDD

Write and run failing tests before production code. Cover: case-insensitive stop search; VIT-to-Katpadi route lookup; unsupported destination; reversed origin/destination; and unknown stop lookup. Then implement the minimum code and rerun the focused test.

## Verification and report

Run `dart format lib/data test/data`, `flutter analyze`, and `flutter test test/data/transport_repository_test.dart`. Write a full report to `.superpowers/sdd/2026-08-29-busbuddy-foundation/task-2-report.md`, including RED/GREEN evidence, files changed, commands and outputs, and concerns. Do not modify UI files. Do not dispatch subagents. There is no usable Git metadata, so do not claim a commit.
