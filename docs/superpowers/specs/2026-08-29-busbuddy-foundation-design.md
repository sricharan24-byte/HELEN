# BusBuddy Foundation Design

**Date:** 2026-08-29  
**Status:** Proposed for review

## Goal

Build the first working BusBuddy vertical slice for the VIT Vellore → Katpadi Railway Station demonstration corridor. The slice will let a commuter choose an origin and destination, inspect deterministic route options, select a route, and enter a basic journey state through an Android-first Flutter interface that is usable with TalkBack.

## Product boundary

The first implementation includes:

- Flutter Android-first application shell.
- Home screen with a clear next action.
- Origin and destination selection from curated local Vellore places/stops.
- Deterministic route results for the initial corridor.
- Route details including route name, direction, stop sequence, and boarding stop.
- Basic journey state after route selection.
- Accessible labels, focus order, state announcements, readable text, and touch targets of at least 48×48 logical pixels.

The first implementation does not depend on maps, external geocoding, Firebase, live fleet feeds, Gemini, computer vision, UWB, authentication, payments, or user accounts. Those features remain replaceable later layers.

## Recommended architecture

Use a small feature-based Flutter application with a layered core:

```text
Presentation → application state/controllers → repositories → local data source
```

Transport facts are represented by Dart models and returned through repository interfaces. The UI does not embed route data, and future remote or simulated sources can implement the same repository boundary without changing the journey screens.

Proposed structure:

```text
lib/
  core/theme/
  core/accessibility/
  data/models/
  data/datasources/
  data/repositories/
  features/home/
  features/route_search/
  features/route_details/
  features/journey/
  main.dart
test/
```

Keep the first slice intentionally dependency-light. Flutter SDK widgets and local Dart data are sufficient until the core flow is validated.

## Core user flow

```text
Open BusBuddy
  → choose origin
  → choose destination
  → view route options
  → select route
  → view boarding stop and route details
  → start journey
  → view current journey state
```

The initial fixture corridor is VIT Vellore to Katpadi Railway Station with approximately 10–20 curated stops. The exact stop names and coordinates will be stored in one local fixture source so they can be corrected without changing presentation code.

## Accessibility requirements

- Every interactive control has a meaningful semantic label and action.
- Route facts are available as text and do not rely on map imagery, color, or icons.
- Focus order follows the user’s task order.
- Selected, disabled, loading, and error states are exposed to assistive technology.
- Tap targets are at least 48×48 logical pixels.
- Dynamic text scaling must not hide the primary action or route facts.
- Errors explain what happened and how to recover.
- Widget tests inspect the semantics tree for the primary journey screens.
- Manual Android testing with TalkBack is required before declaring the slice complete.

## State and error behavior

The route-search flow has explicit states: idle, origin selected, destination selected, results available, route selected, journey active, and error. Empty selections prevent route submission and explain what remains to be chosen. A destination with no matching fixture route displays a recoverable message and keeps the search controls available. Journey state is local and deterministic in this phase.

## Testing strategy

Start with model/repository tests for the corridor fixture and route matching. Add widget tests for semantic labels, route result rendering, route selection, and journey-state transition. Run formatting and static analysis, then perform a manual TalkBack pass on an Android device or emulator if available.

## Deferred decisions

After the first slice is usable, decide the OSM tile provider and routing engine, whether to add Firebase or a local simulator first, the exact speech package, and the shape of the usability study. These decisions must not block the local accessible journey flow.

