# Task 2 — Review Report

**Reviewer:** fresh task reviewer
**Date:** 2026-08-29
**Scope:** Files under `lib/data/` and `test/data/` against Task 2 brief and foundation spec.
**Verdict:** ✅ **APPROVED**

---

## Verification (independent host execution)

| Command | Result |
|---------|--------|
| `dart format lib/data test/data` | Formatted 4 files (0 changed) |
| `flutter analyze` | No issues found |
| `flutter test test/data/transport_repository_test.dart` | +11 passed, 0 failed |

All three verification steps succeed. The implementer's report matches observed output.

---

## Files inspected

| File | Lines | Status |
|------|-------|--------|
| `lib/data/models/transport_models.dart` | 80 | Created — matches brief |
| `lib/data/datasources/local_transport_data_source.dart` | 71 | Created — matches brief |
| `lib/data/repositories/transport_repository.dart` | 49 | Created — matches brief |
| `test/data/transport_repository_test.dart` | 97 | Created — matches brief |
| `lib/main.dart` | ~97 | Unchanged (UI scaffold from Task 1) |
| `test/placeholder_test.dart` | ~8 | Unchanged |

**UI isolation:** `lib/main.dart` was not modified. No presentation-layer code was created or touched.

---

## Brief requirement checklist

### File creation

- [x] `lib/data/models/transport_models.dart` exists
- [x] `lib/data/datasources/local_transport_data_source.dart` exists
- [x] `lib/data/repositories/transport_repository.dart` exists
- [x] `test/data/transport_repository_test.dart` exists

### Model interfaces

- [x] `Stop({required String id, required String name, required String area})` — correct constructor, `const`, equality overrides
- [x] `Route({required String id, required String displayName, required String direction, required List<String> orderedStopIds})` — correct constructor, `const`, custom list equality
- [x] `JourneySelection({required Stop origin, required Stop destination, required Route route})` — correct constructor, `const`

### Repository interfaces

- [x] `TransportRepository.findStops(String query) -> List<Stop>` — abstract, present
- [x] `TransportRepository.findRoutes({required String originId, required String destinationId}) -> List<Route>` — abstract, present
- [x] `TransportRepository.getStop(String stopId) -> Stop?` — abstract, present
- [x] `LocalTransportRepository` implements `TransportRepository` using injected `LocalTransportDataSource`

### Fixture data

- [x] 12 ordered stops (within the 10–20 range required)
- [x] First stop: `vit-main-gate` / "VIT Main Gate"
- [x] Last stop: `katpadi-railway-station` / "Katpadi Railway Station"
- [x] Intermediate Vellore-area stops present (Gandhi Nagar, Clock Tower, Vellore Fort, Srinagar, Thottapalayam)
- [x] One corridor route `vit-to-katpadi` using all stop IDs
- [x] All fixture data lives in `LocalTransportDataSource`, not UI code
- [x] `allStops` and `allRoutes` return unmodifiable list wrappers

### Behavior

- [x] `findStops`: repository trims query, data source lowercases it, matches on name or area substring
- [x] `findStops`: empty query returns all stops
- [x] `findStops`: returns matches in fixture order (uses `_stops.where(...).toList()`)
- [x] `findRoutes`: returns route when origin index < destination index in `orderedStopIds`
- [x] `findRoutes`: returns empty list when origin ≥ destination or either ID not found
- [x] `getStop`: returns `null` for unknown IDs

### Dependencies

- [x] No imports beyond `flutter_test` (test) and the project's own `package:busbuddy/...`
- [x] No third-party packages introduced

### TDD evidence

- [x] Report shows RED phase (compilation failure before source files existed)
- [x] Report shows GREEN phase (11/11 tests pass after implementation)

---

## Findings

### INFO — none

### WARN — 2 findings

**W1. `Route.hashCode` uses `orderedStopIds` List reference, not content.**
`Object.hash(id, displayName, direction, orderedStopIds)` hashes the List *identity*, but `==` compares list *contents* via `_listEquals`. Two `Route` instances with identical data can produce different hash codes, violating the `hashCode`/`==` contract. This has no functional impact in the current codebase (no `Route` instances are used as `Set` keys or `Map` keys), but would surface as a subtle bug if that ever changes. Severity: **low** — acceptable for a curated fixture, worth fixing before routes enter any hash-based collection.

**W2. Brief says "trims and lowercases the query" but lowercase happens in the data source, not the repository.**
The `LocalTransportRepository.findStops` trims the query, then passes it to `LocalTransportDataSource.searchStops`, which performs the lowercase. The overall behavior is correct and the separation of concerns is arguably cleaner, but the lowercase step is invisible to a consumer relying only on the repository interface. Severity: **cosmetic** — no behavioral difference.

### ERROR — none

---

## Test quality assessment

11 tests across 3 groups (`findStops`, `findRoutes`, `getStop`). Coverage map:

| Brief requirement | Test(s) | Verdict |
|---|---|---|
| Case-insensitive stop search | "case-insensitive search by stop name", "case-insensitive search by area", "query with leading/trailing spaces is trimmed" | ✅ Thorough |
| VIT-to-Katpadi route lookup | "VIT Main Gate to Katpadi Railway Station returns corridor route" (verifies origin < dest index) | ✅ |
| Unsupported destination | "unsupported destination returns empty list" | ✅ |
| Reversed origin/destination | "reversed origin/destination returns empty list" | ✅ |
| Unknown stop lookup | "returns null for unknown ID" | ✅ |
| Empty query returns all | "empty query returns all stops in fixture order" (checks first/last ID) | ✅ Bonus test |
| Non-matching query | "non-matching query returns empty list" | ✅ Bonus test |
| Unknown origin for route | "unknown origin returns empty list" | ✅ Bonus test |

Tests are well-structured, use descriptive names, and assert both positive and negative conditions. No flaky or order-dependent tests observed.

---

## Conclusion

**APPROVED.** The implementation fully satisfies the Task 2 brief. All four required files are present, all interfaces match the spec, fixture data is correctly scoped to the data source, behavior is correct, UI files are untouched, and all 11 tests pass with a clean analyzer. The two WARN-level findings are minor and non-blocking.
