---
phase: 08-i18n-gap-closure-tts-hook-toast
plan: 01
subsystem: admin-i18n
tags: [i18n, tts, toast, testing]
dependency_graph:
  requires: []
  provides: [i18n-aware-tts-toasts, extended-cjk-scan]
  affects: [apps/admin/src/hooks/use-tts-player.ts, apps/admin/src/__tests__/hardcoded-strings.test.ts]
tech_stack:
  added: []
  patterns: [useTranslations-in-hooks, findSourceFiles-ts-tsx-scan]
key_files:
  modified:
    - apps/admin/src/hooks/use-tts-player.ts
    - apps/admin/src/__tests__/hardcoded-strings.test.ts
decisions:
  - Use flat keys regenerateSuccess/regenerateError (already in all 3 locale files) instead of nested regenerate.success/regenerate.error — avoids key duplication
  - Drop err.message from onError — always show i18n message; server error detail not needed by end users
metrics:
  duration: ~5m
  completed: "2026-04-02"
  tasks: 2
  files: 2
---

# Phase 08 Plan 01: i18n Gap Closure — TTS Hook Toast Summary

**One-liner:** Replace last 2 hardcoded Japanese toast strings in useTtsPlayer with useTranslations('tts') using existing flat locale keys, and extend the CJK scan test to cover .ts files.

## What Was Done

### Task 1: Replace hardcoded Japanese toast with useTranslations in useTtsPlayer (commit d0e4352)

Modified `apps/admin/src/hooks/use-tts-player.ts`:
- Added `import { useTranslations } from 'next-intl'`
- Added `const t = useTranslations('tts')` as first line inside hook body
- Replaced `toast.success('TTSを再生成しました')` with `toast.success(t('regenerateSuccess'))`
- Replaced `toast.error(err.message || '再生成に失敗しました。もう一度お試しください。')` with `toast.error(t('regenerateError'))`
- Removed unused `err: Error` parameter from `onError` callback

### Task 2: Extend hardcoded-strings test to scan .ts files (commit aa56761)

Modified `apps/admin/src/__tests__/hardcoded-strings.test.ts`:
- Renamed `findTsxFiles` to `findSourceFiles`
- Extended file filter to include both `.ts` and `.tsx` files
- Updated test description to `no .ts/.tsx source files contain CJK characters outside allowlist`
- Updated all call sites to use `findSourceFiles`
- Test passes green with zero CJK violations

## Verification Results

- `grep -c 'TTSを再生成しました\|再生成に失敗しました' apps/admin/src/hooks/use-tts-player.ts` → 0 (PASS)
- `pnpm vitest run src/__tests__/hardcoded-strings.test.ts` → 1 passed (PASS)
- Full vitest suite: 41 passed, 1 pre-existing failure in `nav-badge.test.tsx` (unrelated — bg-destructive class test fails due to component using bg-primary/15; pre-dates this plan)

## Deviations from Plan

None — plan executed exactly as written.

## Deferred Issues

- `nav-badge.test.tsx` — pre-existing failure: test expects `bg-destructive` class but component renders `bg-primary/15`. This is unrelated to i18n work. Logged for follow-up.

## Known Stubs

None — all locale keys were already fully populated in ko.json, ja.json, en.json. No placeholder data flows to UI.

## Self-Check: PASSED
