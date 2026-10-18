# Gemini Navigation and Brand Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Route Gemini SOS requests to the existing confirmation screen, preserve the existing live assistant session during navigation, and polish the Home-only BusBuddy mark.

**Architecture:** Keep existing `Navigator.push` behavior and single Gemini audio/session owner. Add the missing emergency action route and accurate confirmation language. Update the shared logo widget using existing theme and spacing tokens.

**Spec:** `docs/superpowers/specs/2026-10-18-busbuddy-gemini-navigation-polish-design.md`

## Global constraints

- Preserve current user changes and repository contracts.
- Do not modify Gemini transport or microphone/audio lifecycle code.
- Keep SOS behind explicit user confirmation; no automatic transmission.
- Use `AppTheme.colors(context)` and existing spacing/radius tokens.
- Do not add or run tests unless explicitly requested. Run targeted Dart analysis, formatting, source review, and `git diff --check`.

## Tasks

### 1. Complete Gemini action routing and truthful SOS copy

**Files:** `lib/features/ai_assistant/gemini_live_screen.dart`, `lib/features/ai_assistant/gemini_live_service.dart`

- [x] Route `emergency_sos` to `SafetySharingPage(activeTicket: _activeTicket)`.
- [x] Add a specific action button label for SOS review/confirmation.
- [x] Update assistant copy so it says the passenger can review and continue, never that an alert has already been broadcast.
- [x] Preserve push navigation so Gemini’s single live session remains mounted underneath.

### 2. Polish the Home-only brand mark

**Files:** `lib/core/widgets/bus_buddy_logo.dart`

- [x] Add a compact transit mark using the semantic primary colors and radius/spacing tokens.
- [x] Use theme-driven wordmark and subtitle colors while keeping one “BusBuddy” semantics label.
- [x] Keep this widget’s only app-page usage on Home.

### 3. Verify the slice

- [x] Review the action path, SOS wording, logo semantics, and existing audio owner.
- [x] Run Dart formatter and targeted `dart analyze` on touched files.
- [x] Run `git diff --check`; report that physical Gemini microphone continuity still needs device verification.
