---
phase: 07-i18n-completion-accessibility
plan: 01
subsystem: admin-i18n
tags: [i18n, locale, testing, validation]
dependency_graph:
  requires: []
  provides: [i18n-locale-foundation, locale-parity-test, hardcoded-string-detector]
  affects: [07-02-i18n-replacements, 07-03-accessibility]
tech_stack:
  added: []
  patterns: [locale-key-parity-test, cjk-detection-test]
key_files:
  created:
    - apps/admin/src/__tests__/locale-key-parity.test.ts
    - apps/admin/src/__tests__/hardcoded-strings.test.ts
  modified:
    - apps/admin/messages/ko.json
    - apps/admin/messages/ja.json
    - apps/admin/messages/en.json
decisions:
  - "New namespaces appended at end of locale files to minimize diff conflicts with parallel plan 02"
  - "hardcoded-strings.test.ts expected to fail until plan 02 completes all i18n replacements"
metrics:
  duration: 3m
  completed_date: "2026-04-01"
  tasks_completed: 2
  files_changed: 5
---

# Phase 7 Plan 01: i18n Foundation — Locale Keys + Validation Tests Summary

**One-liner:** Added 49 new i18n keys (4 namespaces + 5 namespace extensions) across ko/ja/en with key parity Vitest test and CJK hardcoded-string detector.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add all new i18n keys to three locale files | cae70e9 | ko.json, ja.json, en.json |
| 2 | Create locale key parity and hardcoded string validation tests | 0891ee3 | locale-key-parity.test.ts, hardcoded-strings.test.ts |

## What Was Built

### Task 1 — Locale file updates

All three locale files updated with 49 new keys (173 total keys per file, up from 124):

**New namespaces added:**
- `category` — 8 conversation scenario categories (TRAVEL, SHOPPING, RESTAURANT, BUSINESS, DAILY_LIFE, EMERGENCY, TRANSPORTATION, HEALTHCARE)
- `validation` — JSON array validation error message
- `time` — Relative time strings (justNow, minutesAgo, hoursAgo, daysAgo) with ICU plural format in en.json
- `a11y` — Accessibility labels (skipToMain, mainContent, sidebarNav, primaryNav)

**Namespace extensions:**
- `table.col` — 11 column header keys (word, reading, meaningKo, pattern, explanation, sentence, quizType, title, category, status, updatedAt)
- `table.selectAll`, `table.selectRow` — bulk selection strings
- `edit.noChanges`, `edit.placeholder` — form state strings with placeholder sub-keys
- `review.cancel` — cancel action
- `filter.searchLabel` — accessible search label

All three files maintain identical key structure; only values differ per language.

### Task 2 — Validation tests

- `locale-key-parity.test.ts`: Imports all 3 locale JSONs, flattens keys, asserts exact set equality with per-missing-key error messages. **Passes now.**
- `hardcoded-strings.test.ts`: Scans all `.tsx` source files for CJK Unicode characters (ranges U+3000–U+9FFF, U+AC00–U+D7AF, U+FF00–U+FFEF). Allowlists `locale-switcher.tsx`. **Expected to fail until Plan 02 completes i18n replacements.**

## Deviations from Plan

None — plan executed exactly as written.

**Out-of-scope issue deferred:** Pre-existing ESLint error in `apps/admin/src/components/content/content-table.tsx:82` (`react-hooks/set-state-in-effect`) — introduced in commit `da60f8d`, unrelated to this plan's changes. Logged for separate fix.

## Known Stubs

None — this plan adds translation keys only. No UI components modified.

## Verification Results

- `npx vitest run src/__tests__/locale-key-parity.test.ts` — PASSED (1 test, 173 keys verified)
- Key parity node.js check — PASSED (ko/ja/en identical key sets)
- All namespaces present: category, validation, time, a11y — CONFIRMED
- en.time.minutesAgo uses ICU plural syntax — CONFIRMED

## Self-Check: PASSED

Files created:
- apps/admin/src/__tests__/locale-key-parity.test.ts — FOUND
- apps/admin/src/__tests__/hardcoded-strings.test.ts — FOUND
- apps/admin/messages/ko.json — FOUND (updated)
- apps/admin/messages/ja.json — FOUND (updated)
- apps/admin/messages/en.json — FOUND (updated)

Commits:
- cae70e9 — feat(07-01): add new i18n keys to all three locale files
- 0891ee3 — test(07-01): add locale key parity and hardcoded string detection tests
