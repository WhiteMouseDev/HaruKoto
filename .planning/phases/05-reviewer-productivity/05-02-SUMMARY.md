---
phase: 05-reviewer-productivity
plan: "02"
subsystem: admin-ui
tags: [sidebar, badges, dashboard, i18n, bug-fix]
dependency_graph:
  requires: []
  provides: [NavBadge, SidebarNavWithBadges, quiz-stats-fix, phase5-i18n-keys]
  affects: [sidebar-nav, dashboard-page, locale-files]
tech_stack:
  added: []
  patterns: [TanStack Query badge counts, cloze+sentence_arrange merge pattern]
key_files:
  created:
    - apps/admin/src/components/layout/sidebar-badge.tsx
    - apps/admin/src/components/layout/sidebar-nav-with-badges.tsx
    - apps/admin/src/__tests__/nav-badge.test.tsx
    - apps/admin/src/__tests__/sidebar-nav-item.test.tsx
  modified:
    - apps/admin/src/components/layout/sidebar-nav-item.tsx
    - apps/admin/src/components/layout/sidebar.tsx
    - apps/admin/src/app/(admin)/dashboard/page.tsx
    - apps/admin/messages/ja.json
    - apps/admin/messages/en.json
    - apps/admin/messages/ko.json
decisions:
  - NavBadge is a separate file (sidebar-badge.tsx) to keep it importable without pulling in SidebarNavItem
  - SidebarNavWithBadges wraps nav in <nav> element so Sidebar no longer needs its own <nav> tag
  - getBadgeCount merges cloze+sentence_arrange for quiz key — same pattern as getStatsForKey in dashboard
metrics:
  duration: "3m"
  completed_date: "2026-03-27"
  tasks: 2
  files: 10
---

# Phase 5 Plan 02: Sidebar Badges + Dashboard Quiz Fix Summary

**One-liner:** Sidebar nav badges with needs_review counts via TanStack Query, plus dashboard quiz card fixed to sum cloze+sentence_arrange stats instead of returning 0.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | NavBadge + SidebarNavWithBadges + tests | 0a76b32 | sidebar-badge.tsx, sidebar-nav-with-badges.tsx, sidebar-nav-item.tsx (modified), sidebar.tsx (modified), nav-badge.test.tsx, sidebar-nav-item.test.tsx |
| 2 | Fix dashboard quiz stats bug + Phase 5 i18n keys | 2433551 | dashboard/page.tsx, ja.json, en.json, ko.json |

## What Was Built

### Task 1: Sidebar Badge System

- **NavBadge** (`sidebar-badge.tsx`): Renders null for count=0, digit string for 1-99, "99+" for >100. Uses `bg-destructive` Tailwind class for the red pill styling per UI-SPEC.
- **SidebarNavWithBadges** (`sidebar-nav-with-badges.tsx`): Client component that wraps nav items. Calls `useDashboardStats()` from TanStack Query. `getBadgeCount()` helper maps `contentTypeKey` to API stats — quiz sums cloze + sentence_arrange needsReview counts.
- **SidebarNavItem** modified: Added optional `badge?: number` prop. Renders `<NavBadge count={badge} />` when badge is non-zero.
- **Sidebar** modified: Replaced inline `<nav>` + `<SidebarNavItem>` with `<SidebarNavWithBadges navItems={navItems} />`. Added `contentTypeKey` to vocabulary, grammar, quiz, conversation nav items (dashboard has no contentTypeKey).

### Task 2: Dashboard Fix + i18n

- **Dashboard quiz stats bug fixed**: Added `getStatsForKey()` helper. Quiz key now merges `cloze` + `sentence_arrange` content types. All four CONTENT_TYPE_CONFIG items now use `getStatsForKey()`.
- **Phase 5 i18n keys added** to `review` object in all three locales (ja/en/ko): `startQueue`, `startQueueEmpty`, `queueCapped`, `queuePosition`, `prevItem`, `nextItem`, `exitQueue`, `autoAdvance`, `queueComplete`, `queueLoadError`.
- **D-04 progressLabel confirmed**: All three locales already had `"progressLabel"` in the `dashboard` object. StatsCard renders `progressPct` bar with `bg-primary` and `t('progressLabel', { n: progressPct })` — D-04 complete.

## Test Results

All 12 tests pass (3 test files, 10 todo tests skipped):
- `nav-badge.test.tsx`: 4 tests (renders null for 0, digit for 1-99, 99+ for >99, bg-destructive class)
- `sidebar-nav-item.test.tsx`: 3 tests (renders badge when non-zero, not for 0, not when undefined)
- `status-badge.test.tsx`: 5 tests (pre-existing, unmodified)

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. All badge data is wired to live TanStack Query data from `useDashboardStats()`.

## Self-Check

- [x] `apps/admin/src/components/layout/sidebar-badge.tsx` exists
- [x] `apps/admin/src/components/layout/sidebar-nav-with-badges.tsx` exists
- [x] Commits `0a76b32` and `2433551` exist
- [x] TypeScript exits 0
- [x] All 7 new tests pass

## Self-Check: PASSED
