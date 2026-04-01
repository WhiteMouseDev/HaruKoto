---
phase: 07-i18n-completion-accessibility
plan: 03
subsystem: admin-accessibility
tags: [accessibility, aria, skip-link, landmark, screen-reader, testing]
dependency_graph:
  requires: [07-01]
  provides: [a11y-aria-current, a11y-skip-link, a11y-landmark-labels, a11y-search-label]
  affects: []
tech_stack:
  added: []
  patterns: [aria-current-page, skip-link-sr-only, landmark-aria-labels, associated-label-htmlfor]
key_files:
  created:
    - apps/admin/src/__tests__/filter-bar.test.tsx
  modified:
    - apps/admin/src/components/layout/sidebar-nav-item.tsx
    - apps/admin/src/components/layout/sidebar-nav-with-badges.tsx
    - apps/admin/src/components/layout/sidebar.tsx
    - apps/admin/src/app/(admin)/layout.tsx
    - apps/admin/src/components/content/filter-bar.tsx
    - apps/admin/src/__tests__/sidebar-nav-item.test.tsx
    - apps/admin/src/__tests__/layout.test.tsx
decisions:
  - "Used plain HTML <label> with sr-only class instead of shadcn Label component — avoids import overhead for a visually hidden element"
  - "Layout tests render structural markup directly rather than full AdminLayout async Server Component — full integration is E2E scope"
  - "Mutable mockPathname variable pattern in sidebar-nav-item test enables per-test active/inactive state control"
metrics:
  duration: 8m
  completed_date: "2026-04-01"
  tasks_completed: 2
  files_modified: 8
---

# Phase 07 Plan 03: Accessibility Improvements Summary

**One-liner:** Four targeted ARIA attribute additions — aria-current on nav, skip link, landmark labels, and sr-only search label — fulfilling A11Y-01 through A11Y-04.

## What Was Built

### A11Y-01: aria-current on active sidebar nav items
`sidebar-nav-item.tsx` — Added `aria-current={isActive ? 'page' : undefined}` to the `<Link>` element. Uses `undefined` (not `false`) so React omits the attribute entirely when inactive, conforming to the ARIA spec.

### A11Y-02: Skip link in AdminLayout
`apps/admin/src/app/(admin)/layout.tsx` — Added a visually hidden skip link as the first child of the wrapper div, targeting `#main-content`. Visible only on keyboard focus via `focus:not-sr-only`. Uses `getTranslations('a11y')` for i18n text.

### A11Y-03: Landmark aria-labels
- `sidebar.tsx` — Added `aria-label={tA11y('sidebarNav')}` to the `<aside>` element using a new `tA11y` translation call.
- `sidebar-nav-with-badges.tsx` — Added `useTranslations('a11y')` import and `aria-label={tA11y('primaryNav')}` to the `<nav>` element.
- `layout.tsx` — Added `aria-label={t('mainContent')}` and `id="main-content"` to the `<main>` element.

### A11Y-04: Explicit label on search input
`filter-bar.tsx` — Added `<label htmlFor="search-input" className="sr-only">` before the `<Input>` and `id="search-input"` to the Input, creating a programmatic label association for screen readers.

## Tests

- `sidebar-nav-item.test.tsx` — Extended with 2 new tests: aria-current='page' when active, attribute absent when inactive. Refactored global mock to mutable variable for per-test control.
- `layout.test.tsx` — Extended with 3 new tests: skip link href, main id, main aria-label. Tests render structural markup directly (async Server Component integration is E2E scope).
- `filter-bar.test.tsx` — New file. 2 tests: `getByLabelText('Search')` finds the input, label has `sr-only` class. Mocks next-intl and next/navigation.

All 10 tests pass.

## Commits

- `6fe7f05` feat(07-03): add a11y attributes — aria-current, skip link, landmark labels, search label
- `1d38960` test(07-03): add accessibility tests for A11Y-01 to A11Y-04

## Deviations from Plan

### Out-of-scope lint errors deferred

Pre-existing ESLint errors in `apps/admin/src/components/content/content-table.tsx` (react-hooks/set-state-in-effect rule) were present before this plan and are unrelated to our changes. Deferred per scope boundary rule — our 5 modified source files pass lint with zero errors.

## Known Stubs

None — all accessibility attributes are fully wired with i18n translations from existing message keys.

## Self-Check: PASSED
