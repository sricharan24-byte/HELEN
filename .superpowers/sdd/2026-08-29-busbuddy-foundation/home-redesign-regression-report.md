# Home Redesign Regression Fix — Report

**Date:** 2026-08-29  
**Model:** MiMo-v2.5 (Xiaomi LLM Core Team)  
**Working directory:** `/home/pavan/BusBuddy`

---

## Status

✅ **Complete** — Regression fixed, all verification gates pass.

---

## Problem

The home-page test suite expected visible corridor context mentioning "VIT Vellore" on the home screen, but the redesigned `HomePage` lacked any purpose/context text linking the app to the VIT Vellore ↔ Katpadi Railway Station corridor. This was the single regression in the full suite.

---

## Fix Applied

### 1. Home screen copy (`lib/features/home/home_page.dart`)

Added a non-interactive corridor-context `Text` widget directly below the "Plan your journey" heading:

```dart
Semantics(
  label: 'BusBuddy helps plan journeys from VIT Vellore to Katpadi Railway Station',
  child: Text(
    'BusBuddy helps plan journeys from VIT Vellore to Katpadi Railway Station.',
    style: textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
    ),
  ),
),
```

**What was preserved:**
- Redesigned layout (ListView with stacked cards, no bottom nav, no date input, no floating AI button)
- All existing accessibility semantics (headers, live regions, button labels)
- The `Plan a journey` semantic target and navigation flow

### 2. Focused test (`test/features/home_page_test.dart`)

Added one new test in the `Journey card` group:

```dart
testWidgets('shows corridor context about VIT Vellore to Katpadi Railway Station', (
  tester,
) async {
  await tester.pumpWidget(testApp());
  await tester.pumpAndSettle();

  expect(
    find.text(
      'BusBuddy helps plan journeys from VIT Vellore to Katpadi Railway Station.',
    ),
    findsOneWidget,
  );
});
```

---

## Test Summary

| Gate | Result |
|---|---|
| `dart format lib test` | ✅ Formatted 17 files (2 changed) |
| `flutter analyze` | ✅ No issues found |
| `flutter test` | ✅ **93 / 93 passed** |

### Test file breakdown

| File | Tests |
|---|---|
| `test/data/transport_models_test.dart` | model tests |
| `test/data/transport_repository_test.dart` | 12 |
| `test/features/route_details_page_test.dart` | 26 |
| `test/features/home_page_test.dart` | 22 (1 new) |
| `test/features/route_search_page_test.dart` | 32 |
| `test/placeholder_test.dart` | 1 |
| **Total** | **93** |

---

## Concerns

1. **Snap Flutter toolchain warning** — Build output emits a note that `clang`, `ninja`, `pkg-config`, and `libgtk-3-dev` are missing for Linux desktop builds. This does not affect widget tests (they run headless) but would block `flutter build linux` on this machine.

2. **No date input / no bottom nav — intentional constraints** — The brief explicitly forbids reintroducing a date input, bottom navigation, separate icon-only controls, or a floating AI button. The current implementation respects all four constraints.

3. **Corridor copy is hard-coded** — The VIT Vellore ↔ Katpadi Railway Station string is currently a literal. If the app expands to additional corridors in the future, this should be moved to a localization/config constant.

---

## Files Changed

| File | Change |
|---|---|
| `lib/features/home/home_page.dart` | Added corridor-context paragraph below "Plan your journey" |
| `test/features/home_page_test.dart` | Added 1 test for corridor-context visibility |

**No Git commit was created** per the brief's instruction.

---

## Report Path

`.superpowers/sdd/2026-08-29-busbuddy-foundation/home-redesign-regression-report.md`
