# Task 2 — Transport Models, Fixtures, and Repository

**Date:** 2026-08-29
**Status:** ✅ Complete

---

## Summary

Implemented the transport data layer for the VIT Vellore → Katpadi Railway Station corridor.
All files created from scratch; no existing files were modified.
All verification steps pass with zero issues.

---

## Files Changed

| File | Action |
|------|--------|
| `lib/data/models/transport_models.dart` | **Created** — `Stop`, `Route`, `JourneySelection` models |
| `lib/data/datasources/local_transport_data_source.dart` | **Created** — curated 12-stop corridor fixture data |
| `lib/data/repositories/transport_repository.dart` | **Created** — `TransportRepository` abstraction + `LocalTransportRepository` |
| `test/data/transport_repository_test.dart` | **Created** — 11 unit tests covering all required scenarios |
| `lib/main.dart` | Unchanged |
| `test/placeholder_test.dart` | Unchanged |

---

## Design Decisions

### Models (`transport_models.dart`)

- `Stop` — immutable value class with `id`, `name`, `area` fields plus equality overrides.
- `Route` — immutable value class with `id`, `displayName`, `direction`, `orderedStopIds` (list of stop IDs).
- `JourneySelection` — groups an origin `Stop`, destination `Stop`, and `Route`.

### Local Fixture Data (`local_transport_data_source.dart`)

- **12 ordered stops** along the corridor:
  1. VIT Main Gate (VIT University)
  2. VIT Back Gate (VIT University)
  3. Gandhi Nagar (Vellore)
  4. Clock Tower (Vellore Town)
  5. Vellore Fort (Vellore Town)
  6. Srinagar (Vellore)
  7. Thottapalayam (Vellore)
  8. Dufflpet (Katpadi)
  9. South Arcot (Katpadi)
  10. Katpadi Bus Stand (Katpadi)
  11. Katpadi Junction (Katpadi)
  12. Katpadi Railway Station (Katpadi)

- One corridor `Route` (`vit-to-katpadi`) with all 12 stop IDs in order.
- `searchStops(query)` — case-insensitive substring match on name or area; empty query returns all.
- `stopById(id)` — direct ID lookup; returns `null` for unknown.

### Repository (`transport_repository.dart`)

- `TransportRepository` — abstract interface with `findStops`, `findRoutes`, `getStop`.
- `LocalTransportRepository` — concrete implementation injecting `LocalTransportDataSource`.
- `findStops` — trims whitespace, delegates to data source search.
- `findRoutes` — checks origin index < destination index in each route's `orderedStopIds`; returns matching routes or empty list.
- `getStop` — delegates to data source; returns `null` for unknown IDs.

---

## TDD Evidence

### RED Phase

Initial `flutter test` run produced compilation errors because the three source files did not exist:

```
test/data/transport_repository_test.dart:2:8: Error: Error when reading 'lib/data/models/transport_models.dart': No such file or directory
test/data/transport_repository_test.dart:3:8: Error: Error when reading 'lib/data/datasources/local_transport_data_source.dart': No such file or directory
test/data/transport_repository_test.dart:4:8: Error: Error when reading 'lib/data/repositories/transport_repository.dart': No such file or directory
...
00:00 +0 -1: Some tests failed.
```

### GREEN Phase

After implementing all three source files, all 11 tests pass:

```
00:00 +0: findStops empty query returns all stops in fixture order
00:00 +1: findStops case-insensitive search by stop name
00:00 +2: findStops case-insensitive search by area
00:00 +3: findStops query with leading/trailing spaces is trimmed
00:00 +4: findStops non-matching query returns empty list
00:00 +5: findRoutes VIT Main Gate to Katpadi Railway Station returns corridor route
00:00 +6: findRoutes reversed origin/destination returns empty list
00:00 +7: findRoutes unsupported destination returns empty list
00:00 +8: findRoutes unknown origin returns empty list
00:00 +9: getStop returns correct stop for known ID
00:00 +10: getStop returns null for unknown ID
00:00 +11: All tests passed!
```

---

## Verification Commands & Outputs

### 1. `dart format lib/data test/data`

```
Formatted 4 files (0 changed) in 0.03 seconds.
```

All files already conform to the Dart formatter. Zero changes required after initial format pass.

### 2. `flutter analyze`

```
Analyzing BusBuddy...

No issues found! (ran in 1.0s)
```

Zero warnings, zero errors, zero info diagnostics.

### 3. `flutter test test/data/transport_repository_test.dart`

```
00:00 +11: All tests passed!
```

11/11 tests pass. Test categories covered:

| # | Test | Group |
|---|------|-------|
| 1 | Empty query returns all stops in fixture order | findStops |
| 2 | Case-insensitive search by stop name | findStops |
| 3 | Case-insensitive search by area | findStops |
| 4 | Query with leading/trailing spaces is trimmed | findStops |
| 5 | Non-matching query returns empty list | findStops |
| 6 | VIT → Katpadi returns corridor route | findRoutes |
| 7 | Reversed origin/destination returns empty list | findRoutes |
| 8 | Unsupported destination returns empty list | findRoutes |
| 9 | Unknown origin returns empty list | findRoutes |
| 10 | Returns correct stop for known ID | getStop |
| 11 | Returns null for unknown ID | getStop |

---

## Concerns

1. **No Git metadata** — This environment has no usable Git history, so no commit was made or claimed.
2. **Linux build tools** — `flutter test` emits a warning about missing Linux build tools (clang, ninja, GTK3). This does not affect unit tests but would prevent `flutter run` on Linux.
3. **No reverse route** — The fixture defines only one direction (VIT → Katpadi). If a Katpadi → VIT route is needed later, a second `Route` entry with reversed `orderedStopIds` should be added.
4. **Simple substring matching** — `findStops` uses substring matching (`contains`), not fuzzy or token-based matching. This is sufficient for a curated fixture but may need enhancement with a larger dataset.
