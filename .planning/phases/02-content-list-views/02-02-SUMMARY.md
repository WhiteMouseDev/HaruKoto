---
phase: 02-content-list-views
plan: 02
subsystem: admin-ui
tags: [ui, sidebar, i18n, components, shadcn]
dependency_graph:
  requires: [02-01]
  provides: [sidebar-layout, status-badge, filter-bar, pagination-bar, shadcn-table, phase2-i18n]
  affects: [02-03]
tech_stack:
  added: [shadcn-table]
  patterns: [client-component-url-sync, debounced-search, active-route-detection]
key_files:
  created:
    - apps/admin/src/components/layout/sidebar-nav-item.tsx
    - apps/admin/src/components/layout/sidebar.tsx
    - apps/admin/src/components/ui/table.tsx
    - apps/admin/src/components/ui/status-badge.tsx
    - apps/admin/src/components/ui/pagination-bar.tsx
    - apps/admin/src/components/content/filter-bar.tsx
    - apps/admin/src/__tests__/status-badge.test.tsx
  modified:
    - apps/admin/src/app/(admin)/layout.tsx
    - apps/admin/messages/ja.json
    - apps/admin/messages/ko.json
    - apps/admin/messages/en.json
    - apps/admin/src/global.d.ts
decisions:
  - "Sidebar bottom section reuses existing LocaleSwitcher + LogoutButton (moved from header context) — avoids duplication"
  - "FilterBar uses native <select> for dropdowns — simpler than DropdownMenu, no click-outside handling needed for 1-3 user admin"
  - "Search debounced 300ms via setTimeout/useEffect — React 19 useDeferredValue not used to keep URL sync explicit"
  - "PaginationBar returns null when totalPages <= 1 — prevents empty pagination row rendering"
metrics:
  duration: "10m"
  completed_date: "2026-03-26"
  tasks_completed: 2
  files_changed: 11
---

# Phase 02 Plan 02: Admin UI Shell — Sidebar, Shared Components, i18n

Sidebar layout + StatusBadge/FilterBar/PaginationBar components with debounced URL-synced filtering and all Phase 2 i18n keys in ja/ko/en.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Install shadcn Table, Sidebar, layout update, i18n keys | f94b0ed | 8 files |
| 2 | StatusBadge, FilterBar, PaginationBar, status-badge test | c669e08 | 4 files |

## What Was Built

### Sidebar Navigation
- `sidebar-nav-item.tsx`: 'use client' component using `usePathname()` for active route detection with `border-l-2 border-primary bg-accent` active style and `hover:bg-accent/50` inactive style
- `sidebar.tsx`: Async Server Component, 240px (`w-60`), 5 nav items with lucide icons (LayoutDashboard, BookOpen, BookMarked, HelpCircle, MessageSquare), locale/logout at bottom via `mt-auto`
- `layout.tsx` updated to `flex flex-1 overflow-hidden` with `<Sidebar />` before `<main>`

### shadcn Table
- Installed via `pnpm dlx shadcn@latest add table` — creates `src/components/ui/table.tsx` with new-york style

### Status Badge
- `status-badge.tsx`: 3 states (needs_review=amber, approved=green, rejected=red) with dark mode variants, uses `useTranslations('status')` for labels

### Filter Bar
- `filter-bar.tsx`: Search input (300ms debounce via setTimeout), JLPT select (120px), optional Category select (160px), Status select (144px); all synced to URL params via `router.replace()`; any filter change resets page to 1

### Pagination Bar
- `pagination-bar.tsx`: Numbered pages with ellipsis for gaps (first, last, current ±2), cherry pink active state (`bg-primary`), ChevronLeft/ChevronRight nav buttons, returns null when totalPages ≤ 1

### i18n Keys
All Phase 2 strings added to ja/ko/en: `nav`, `filter`, `status`, `table`, `empty`, `error`, `page`, `dashboard` (extended)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed pre-existing ESLint error in global.d.ts**
- **Found during:** Task 1 lint verification
- **Issue:** `interface IntlMessages extends Messages {}` triggered `@typescript-eslint/no-empty-object-type` — pre-existing lint failure
- **Fix:** Added `// eslint-disable-next-line @typescript-eslint/no-empty-object-type` comment — this pattern is required by next-intl for TypeScript type inference
- **Files modified:** `apps/admin/src/global.d.ts`
- **Commit:** f94b0ed

## Test Results

- `status-badge.test.tsx`: 5/5 tests pass
  - needs_review renders with bg-amber-100
  - approved renders with bg-green-100
  - rejected renders with bg-red-100
  - renders as span element
  - has inline-flex rounded-full classes

## Known Stubs

None. All components are fully implemented. FilterBar and PaginationBar depend on URL params from consuming pages (Plan 03 will wire the actual data).

## Self-Check: PASSED

- [x] `apps/admin/src/components/ui/table.tsx` — FOUND
- [x] `apps/admin/src/components/layout/sidebar-nav-item.tsx` — FOUND
- [x] `apps/admin/src/components/layout/sidebar.tsx` — FOUND
- [x] `apps/admin/src/components/ui/status-badge.tsx` — FOUND
- [x] `apps/admin/src/components/ui/pagination-bar.tsx` — FOUND
- [x] `apps/admin/src/components/content/filter-bar.tsx` — FOUND
- [x] `apps/admin/src/__tests__/status-badge.test.tsx` — FOUND
- [x] commit f94b0ed — FOUND
- [x] commit c669e08 — FOUND
