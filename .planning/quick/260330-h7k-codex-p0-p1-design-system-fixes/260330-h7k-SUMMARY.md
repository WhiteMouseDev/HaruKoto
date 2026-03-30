---
phase: quick
plan: 260330-h7k
subsystem: admin-ui
tags: [layout, wcag, accessibility, sticky, sidebar]
dependency_graph:
  requires: []
  provides: [viewport-fixed-sidebar, wcag-aa-contrast, sticky-action-bars]
  affects: [apps/admin]
tech_stack:
  added: []
  patterns: [h-screen overflow-hidden admin layout, sticky top-0 z-10 action bars, WCAG AA primary-foreground]
key_files:
  created: []
  modified:
    - apps/admin/src/app/(admin)/layout.tsx
    - apps/admin/src/components/layout/sidebar.tsx
    - apps/admin/src/app/globals.css
    - apps/admin/src/components/content/review-header.tsx
    - apps/admin/src/components/content/queue-navigation-bar.tsx
decisions:
  - primary-foreground changed to #4A1A2A (dark cherry) for WCAG AA compliance — ~6.2:1 on #F6A5B3
  - h-screen overflow-hidden admin layout pattern with sidebar having independent overflow-y-auto scroll
metrics:
  duration: 8m
  completed: 2026-03-30
  tasks: 2
  files_changed: 5
---

# Phase quick Plan 260330-h7k: Codex P0/P1 Design System Fixes Summary

**One-liner:** Fixed viewport-fixed sidebar layout (h-screen), WCAG AA primary contrast (#4A1A2A on cherry pink), and sticky action bars for ReviewHeader and QueueNavigationBar.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Viewport-fixed sidebar layout | d492efd | layout.tsx, sidebar.tsx |
| 2 | WCAG contrast + sticky action bars | bda7a4c | globals.css, review-header.tsx, queue-navigation-bar.tsx |

## Changes Made

### Task 1: Viewport-Fixed Sidebar Layout (P0-1)

- `apps/admin/src/app/(admin)/layout.tsx`: Changed root div from `flex min-h-screen` to `flex h-screen overflow-hidden`. Main element retains `overflow-y-auto` for independent scroll.
- `apps/admin/src/components/layout/sidebar.tsx`: Changed aside from `flex h-full w-60 flex-col` to `flex h-screen w-60 shrink-0 flex-col overflow-y-auto`. Sidebar is now viewport-fixed with its own scrollbar if nav items exceed viewport height. Logout/LocaleSwitcher at the bottom always visible.

### Task 2: WCAG Contrast + Sticky Action Bars (P0-2, P1)

- `apps/admin/src/app/globals.css`: Changed `--primary-foreground` from `#FFFFFF` to `#4A1A2A` in both `:root` (light) and `.dark` themes. White on #F6A5B3 was ~2.1:1 (fails WCAG AA). Dark cherry #4A1A2A on #F6A5B3 is ~6.2:1 (passes WCAG AA 4.5:1 threshold).
- `apps/admin/src/components/content/review-header.tsx`: Added `sticky top-0 z-10` to outer div. Pins to top of the overflow-y-auto main scroll container when scrolling long edit forms.
- `apps/admin/src/components/content/queue-navigation-bar.tsx`: Added `sticky top-0 z-10` to outer div. Same sticky pattern; stacks in document order below QueueNavigationBar when both render together.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- `apps/admin/src/app/(admin)/layout.tsx` — contains `h-screen overflow-hidden`: FOUND
- `apps/admin/src/components/layout/sidebar.tsx` — contains `h-screen`: FOUND
- `apps/admin/src/app/globals.css` — contains `#4A1A2A`: FOUND
- `apps/admin/src/components/content/review-header.tsx` — contains `sticky`: FOUND
- `apps/admin/src/components/content/queue-navigation-bar.tsx` — contains `sticky`: FOUND
- Commit d492efd: FOUND
- Commit bda7a4c: FOUND
- Build: PASSED (no TypeScript or lint errors)
