# ADR-001: Phase 1 Domain Hardening, Fare Precedence, and Accessibility Contracts

- **Status**: Accepted
- **Date**: 2026-09-19
- **Auditors**: Claude Opus 5 (Architectural Blueprint) & GPT-6 Astra (External Architecture & Accessibility Audit)

---

## Context

BusBuddy completed Phase 0 (pinned toolchain, 187/187 green baseline) and Phase 1 (Pure-Dart domain layer `lib/domain/`, authoritative `FareEngine`, and `AppServiceLocator` DI container). 

An external architectural audit conducted by **GPT-6 Astra** (`main.pdf`) identified three critical P0 contracts and several domain boundary conditions required before proceeding to the Phase 2 Accessibility-First UI Rebuild:
1. **Fare Precedence & Money Representation**: Floating-point `double` creates drift on concessions and taxes. Precedence between corridor rules and hop counts was implicit.
2. **Singleton Ownership & Asynchronous Teardown**: `LocalTransportRepository` spawned background simulation timers without explicit disposal hooks. `resetForTesting()` cleared references without awaiting resource shutdown.
3. **Platform Text Scaling Floor & Ceiling**: Capping text scale at 2.0x in `main.dart` degrades or overrides the user's platform accessibility setting on Android / One UI.

---

## Decision

### 1. P0.1 Fare Precedence, Integer Paise, and Zero-Hop Validation
- **Integer Paise Representation**: All monetary calculations within `Fare` and `FareEngine` are computed in integer paise (1 Rupee = 100 Paise).
- **Authoritative Precedence Table**:
  1. *Zero Hops (origin == destination)*: Rejected with `ArgumentError` / `ValidationFailure`. Same-stop ticketing is illegal.
  2. *Standard Corridor (VIT Main Gate ↔ Katpadi Station)*: Exactly 4 hops (5 stops), mapping directly to the 4–5 stop tier (2000 paise / ₹20 base fare). Rule ID: `RULE_CORRIDOR_V1`.
  3. *Short-Hop (1–3 hops)*: 1500 paise (₹15.0 base fare). Rule ID: `RULE_HOP_SHORT_V1`.
  4. *Medium-Hop (4–5 hops)*: 2000 paise (₹20.0 base fare). Rule ID: `RULE_HOP_MEDIUM_V1`.
  5. *Extended Corridor (6+ hops)*: 2500 paise (₹25.0 base fare). Rule ID: `RULE_HOP_EXTENDED_V1`.
- **Concession Policy**: 40% discount for Students and Senior Citizens. Nearest paise integer arithmetic:
  $$\text{payablePaise} = \left\lfloor \frac{\text{basePaise} \times (100 - \text{discountPercent}) + 50}{100} \right\rfloor$$
- **FareQuote Metadata**: Every calculated fare returns `basePaise`, `discountPaise`, `payablePaise`, `hopCount`, `ruleId`, and human-readable explanation.

### 2. P0.2 Singleton Ownership & Asynchronous Teardown
- **Disposal Hook**: Added `Future<void> dispose()` to `LocalTransportRepository`, safely closing all active `LiveBusMovementEngine` simulation timers and stream controllers.
- **Async Reset**: Upgraded `AppServiceLocator.resetForTesting()` to an asynchronous method awaiting `dispose()` on all active repository and controller instances before clearing references.

### 3. P0.3 Uncapped Platform Text Scaling
- **Preserve Platform Settings**: Removed the upper `2.0` clamp on `TextScaler` in `lib/main.dart`.
- **Responsive Reflow**: The system text scale factor chosen by low-vision commuters is fully respected. UI layouts in Phase 2 are required to reflow and wrap content responsively rather than imposing arbitrary scale ceilings.

### 4. Domain Collection & State Immutability
- **Defensive Copying**: `TransitRoute.orderedStopIds` is wrapped in `List.unmodifiable` at instantiation to prevent runtime mutation by callers.
- **Ticket State Machine**: Explicit `canTransitionTo()` and `transitionTo()` guard ticket lifecycle (`active -> used`, `active -> expired`) and reject transitions from terminal states.

---

## Consequences

- **Correctness**: Zero floating-point drift in fare quotes, tickets, and multi-passenger transactions.
- **Resource Safety**: No leaked timer loops or background CPU drain across navigation cycles or test executions.
- **WCAG 2.2 Alignment**: Uncapped platform text scaling conforms to accessibility standards for high-magnification users.
- **Verification**: All 214+ unit, widget, and domain tests pass deterministically.
