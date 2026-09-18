# Home-screen redesign — verification report

**Date:** 2026-08-29
**Verifier:** MiMo-v2.5 (automated)
**Brief:** `home-redesign-brief.md`

---

## Files inspected

| File | Status |
|------|--------|
| `lib/features/home/home_page.dart` | Present, ~280 lines. Implements all 6 brief sections: header, journey card, active trip, tickets, safety, voice. Uses semantic labels, `Semantics(header: true)` for headings, `liveRegion: true` for active-trip messaging, no bottom nav, no date input, full-width stacked actions, 56dp+ touch targets. |
| `lib/main.dart` | Present. Wires `HomePage` with `JourneyController`, `TransportRepository`, and `onRouteSelected`. Uses `AppTheme.light`. Preserves route-search navigation flow to `RouteDetailsPage`. |
| `test/features/home_page_test.dart` | Present, 21 tests across 8 groups (Header, Journey card, Active trip, Tickets, Safety, Voice, Accessibility, Preserved route-search). Includes `testApp()` helper and `_findSemanticsContaining()` utility. |

### Brief compliance checklist

| Brief requirement | Met? | Notes |
|-------------------|------|-------|
| Title "BusBuddy" (not TransitSafe) | ✅ | `Text('BusBuddy')` with `Semantics(header: true)` |
| Settings and accessibility action | ✅ | Full-width `OutlinedButton.icon`, visual-only, truthful label |
| "Plan your journey" heading | ✅ | `Semantics(header: true)` + `Text('Plan your journey')` |
| "Starting point" origin control | ⚠️ | Label exists in `Semantics(label:)` only; no visible `Text` widget with this label |
| "Choose starting stop" default text | ✅ | Visible in button label |
| "Where to?" destination control | ⚠️ | Same — label in `Semantics(label:)` only, not a visible `Text` widget |
| No date input | ✅ | "Depart now" as informational text only |
| "Plan a journey" semantic target preserved | ✅ | Primary `FilledButton.icon` with semantic label `Plan a journey` |
| No GPS / location permission requests | ✅ | No location code |
| Active trip card, "No active trip" | ✅ | Empty state with truthful explanation, `liveRegion: true` |
| Tickets placeholder | ✅ | Full-width stacked card, truthful label |
| Safety/location placeholder | ✅ | Full-width stacked card, truthful label, no permission requests |
| "Talk to BusBuddy" voice action | ✅ | Full-width `OutlinedButton.icon`, `onPressed: null` (disabled/demo) |
| No bottom navigation bar | ✅ | No `NavigationBar` or `BottomNavigationBar` |
| Large touch targets (≥48dp) | ✅ | All buttons use `minimumSize: Size.fromHeight(56)` or `64` |
| Accessibility focus order | ✅ | Top-to-bottom ListView order matches brief |

---

## Command results

### `dart format lib test`
```
Formatted 18 files (0 changed) in 0.15 seconds.
```
All source and test files are properly formatted.

### `flutter analyze`
```
warning • Unused import: 'package:busbuddy/features/route_search/route_search_page.dart'
           test/features/home_page_test.dart:11:8

error   • const_with_non_const — test/widget_test.dart:16:29
error   • missing_required_argument — test/widget_test.dart:16:35 (×2)
```
- **1 warning** in `home_page_test.dart` (unused `route_search_page.dart` import — cosmetic).
- **3 errors** in `test/widget_test.dart` — the default Flutter template test was not updated after `MyApp` gained required constructor parameters (`journeyController`, `repository`). This is a **pre-existing issue**, not introduced by the home redesign.

### `flutter test`
```
86 passed, 7 failed (full suite)
```

#### Home page test breakdown (21 tests): **16 passed, 5 failed**

| # | Test | Result | Failure detail |
|---|------|--------|----------------|
| 1 | displays BusBuddy as the title | ✅ | — |
| 2 | has a settings and accessibility action | ✅ | — |
| 3 | settings action has a truthful label | ✅ | — |
| 4 | shows Plan your journey heading | ✅ | — |
| 5 | starting point control labeled Starting point | ❌ | `find.text('Starting point')` — `Found 0 widgets`. Label is in `Semantics(label:)` only, not a visible `Text` widget. |
| 6 | starting point shows Choose starting stop | ✅ | — |
| 7 | destination control labeled Where to? | ❌ | `find.text('Where to?')` — `Found 0 widgets`. Same issue: label is in `Semantics(label:)` only. |
| 8 | does not show a Date input | ✅ | — |
| 9 | shows Depart now as informational text | ✅ | — |
| 10 | primary action semantic label Plan a journey | ✅ | — |
| 11 | tapping primary action navigates to RouteSearchPage | ✅ | — |
| 12 | shows Active trip heading | ✅ | — |
| 13 | shows No active trip empty state | ✅ | — |
| 14 | active trip message in live region | ✅ | — |
| 15 | shows My tickets and trip history | ❌ | `find.text('My tickets and trip history')` — `Found 0 widgets`. Text widget exists in source but not found at runtime. |
| 16 | shows Live location and safety sharing | ❌ | `find.text('Live location and safety sharing')` — `Found 0 widgets`. Same pattern. |
| 17 | shows Talk to BusBuddy | ❌ | `find.text('Talk to BusBuddy')` — `Found 0 widgets`. Same pattern. |
| 18 | no bottom navigation bar | ✅ | — |
| 19 | Plan your journey heading uses header semantics | ✅ | — |
| 20 | active trip uses live region semantics | ✅ | — |
| 21 | preserved route-search navigation | ✅ | — |

#### Other test failures (2, not related to home redesign)
- `test/widget_test.dart` — compilation error (stale template, not updated for new `MyApp` signature).
- `route_search_page_test.dart` — pre-existing failure ("accessibility-first purpose statement" expects `VIT Vellore` text that doesn't render).

---

## Findings

### F1 — Test/implementation mismatch on Semantics-only labels (2 tests)
**Severity:** Low (test bug, not a UI bug)
**Tests:** "Starting point", "Where to?"

The brief says *"Origin control labeled `Starting point`"* and *"Destination control labeled `Where to?`"*. The implementation correctly places these as `Semantics(label:)` properties on the button containers for screen-reader accessibility. However, the tests use `find.text(...)` which only locates `Text` widgets, not Semantics labels. The test file already contains a `_findSemanticsContaining()` helper that would correctly find these — it just isn't used in these two tests.

**Fix:** Either change the tests to use `_findSemanticsContaining('Starting point')` / `_findSemanticsContaining('Where to?')`, or add a visible `Text` widget with those labels above the buttons.

### F2 — Lower-ListView text widgets not found at test time (3 tests)
**Severity:** Medium (blocks test green)
**Tests:** "My tickets and trip history", "Live location and safety sharing", "Talk to BusBuddy"

The `Text` widgets for tickets, safety, and voice cards exist in `home_page.dart` source code and the code compiles without errors, yet `find.text(...)` returns zero matches at test time. All three affected widgets are in the lower portion of the `ListView`. This may indicate a runtime rendering issue (e.g., `colorScheme.surfaceContainerLowest` not available on the test Flutter SDK version causing a silent build failure for those `Container` widgets) or a stale test compilation cache. Further investigation is needed — try running `flutter clean && flutter test` and/or checking the Flutter SDK version for `surfaceContainerLowest` support (requires Flutter ≥ 3.22).

### F3 — Stale `test/widget_test.dart` (1 test, not home redesign)
**Severity:** Low (pre-existing, not introduced by this work)
The default Flutter template test calls `MyApp()` without the required `journeyController` and `repository` arguments. Needs updating or removal.

### F4 — Unused import warning (cosmetic)
**Severity:** Negligible
`test/features/home_page_test.dart` imports `route_search_page.dart` but never references the type directly.

---

## Conclusion

### CHANGES_REQUIRED

The widget implementation (`home_page.dart`) is well-structured and faithfully follows the brief's content, accessibility, and behavioral requirements. The wiring in `main.dart` is correct and preserves the existing navigation flow.

However, **5 of 21 home-page tests are failing**, which means the TDD green cycle is not complete:

1. **2 tests** (Starting point, Where to?) have a test/implementation mismatch — labels are in Semantics only, but tests search via `find.text()`. Quick fix: use the existing `_findSemanticsContaining()` helper.
2. **3 tests** (Tickets, Safety, Voice) fail because their `Text` widgets aren't found at test time despite being present in source. Root cause likely relates to a runtime rendering issue with `surfaceContainerLowest` on the test Flutter SDK or a stale build cache — needs `flutter clean` + SDK version check.
3. **1 pre-existing issue** (`widget_test.dart` compilation error) should also be addressed.

**Recommended next steps:**
1. Run `flutter clean && flutter get && flutter test` to rule out stale cache.
2. If tickets/safety/voice tests still fail, check Flutter SDK version for `surfaceContainerLowest` support and consider using `colorScheme.surface` or `colorScheme.surfaceVariant` as a fallback.
3. Fix the 2 Semantics-label tests to use `_findSemanticsContaining()`.
4. Update or remove `test/widget_test.dart`.
5. Remove unused `route_search_page.dart` import from `home_page_test.dart`.
