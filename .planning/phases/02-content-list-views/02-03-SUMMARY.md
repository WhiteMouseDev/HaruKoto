---
phase: 02-content-list-views
plan: 03
subsystem: admin-ui
tags: [tanstack-query, api-client, content-list, dashboard, stats]
dependency_graph:
  requires: [02-01, 02-02]
  provides:
    - fetchAdminContent/fetchContentStats (lib/api/admin-content.ts)
    - useContentList hook (URL-param synced TanStack Query)
    - useDashboardStats hook
    - ContentTable generic component
    - StatsCard with progress bar
    - /vocabulary, /grammar, /quiz, /conversation list pages
    - /dashboard with real stats
  affects: []
tech_stack:
  added:
    - NEXT_PUBLIC_FASTAPI_URL env var (client-side FastAPI URL)
  patterns:
    - fetchAdminContent: browser Supabase session token injected as Bearer JWT
    - useContentList: useSearchParams() maps URL params (q, jlpt, status, category, page) to API params
    - ContentTable: generic T extends {id: string} with loading/error/empty states
    - StatsCard: approved/total progress bar with bg-primary fill
key_files:
  created:
    - apps/admin/src/lib/api/admin-content.ts
    - apps/admin/src/hooks/use-content-list.ts
    - apps/admin/src/hooks/use-dashboard-stats.ts
    - apps/admin/src/components/content/content-table.tsx
    - apps/admin/src/components/features/dashboard/stats-card.tsx
    - apps/admin/src/app/(admin)/vocabulary/page.tsx
    - apps/admin/src/app/(admin)/grammar/page.tsx
    - apps/admin/src/app/(admin)/quiz/page.tsx
    - apps/admin/src/app/(admin)/conversation/page.tsx
    - apps/admin/.env.example
  modified:
    - apps/admin/src/app/(admin)/dashboard/page.tsx
    - apps/admin/messages/ja.json
    - apps/admin/messages/ko.json
    - apps/admin/messages/en.json
decisions:
  - fetchAdminContent uses browser Supabase client getSession() for JWT — consistent with client-side 'use client' pages
  - useContentList maps URL params to API params in hook (not in page) — single source of truth for param mapping
  - ContentTable is generic T extends {id: string} — type-safe render props without losing column flexibility
  - StatsCard fetches display name via useEffect + getUser() (not getSession()) — live DB validation consistent with auth strategy
  - error.retry i18n key added to ja/ko/en — Rule 2 auto-add for missing UI text
metrics:
  duration: ~5 minutes
  completed_date: 2026-03-26
  tasks_completed: 2
  files_created: 10
  files_modified: 4
---

# Phase 02 Plan 03: Content List Pages + Dashboard Stats Summary

**One-liner:** TanStack Query API client layer with Supabase JWT, 4 content list pages with search/filter/pagination, and dashboard StatsCard components with progress bars wired to FastAPI /stats endpoint.

## What Was Built

### Task 1: API client layer + TanStack Query hooks

- `lib/api/admin-content.ts`: `fetchAdminContent<T>()` fetches from `NEXT_PUBLIC_FASTAPI_URL` with Bearer JWT from Supabase browser session; `fetchContentStats()` hits `/stats`. TypeScript types: `PaginatedResponse<T>`, `VocabularyItem`, `GrammarItem`, `QuizItem`, `ConversationItem`, `ContentStatsResponse`.
- `hooks/use-content-list.ts`: `useContentList<T>(type)` reads URL search params (`q`→search, `jlpt`→jlpt_level, `status`→review_status, `category`, `page`) and feeds them to TanStack Query with `staleTime: 30_000`.
- `hooks/use-dashboard-stats.ts`: `useDashboardStats()` with `staleTime: 60_000`.
- `.env.example` created with `NEXT_PUBLIC_FASTAPI_URL` documented.
- `.env.local` created with localhost default for development.

### Task 2: Content list pages + dashboard stats + components

- `ContentTable<T extends { id: string }>`: Generic table with 10 skeleton rows (`animate-pulse`), error state with retry button, empty state with Search icon, data rows with `hover:bg-muted/30`. Includes `PaginationBar` below table when `totalPages > 1`.
- `StatsCard`: Card with 3 count rows (needs_review, approved, rejected at 28px/semibold), progress bar (`bg-primary` fill over `bg-border` track), `{n}% 承認済み` label.
- `/vocabulary/page.tsx`: 7-column table (単語/読み方/意味/JLPT/ステータス/更新日/Actions), `useContentList('vocabulary')`, `<FilterBar />`, `<Suspense>`.
- `/grammar/page.tsx`: 6-column table (パターン/説明/JLPT/ステータス/更新日/Actions).
- `/quiz/page.tsx`: 6-column table (問題文/種類/JLPT/ステータス/更新日/Actions), quiz_type shown as cloze/sentence-arrange.
- `/conversation/page.tsx`: 6-column table (タイトル/カテゴリ/JLPT/ステータス/更新日/Actions), `<FilterBar showCategory categories={SCENARIO_CATEGORIES} />`.
- `/dashboard/page.tsx`: Replaced Server Component with 'use client', uses `useDashboardStats()`, shows 4 `StatsCard` components in 2-column grid, loading skeleton, error state with retry.
- Actions column in all 4 pages: `詳細` link to `/{type}/{id}` — will 404 until Phase 3.
- Added `error.retry` to all 3 i18n message files (Rule 2 auto-add).

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| useContentList maps URL params in hook | Single source of truth; pages just call useContentList(type) and read searchParams for currentPage display |
| ContentTable generic with render props | Type-safe column definitions per content type without duplicating table structure |
| Dashboard changed to 'use client' | useDashboardStats() requires client hook; display name fetched via useEffect + getUser() |
| NEXT_PUBLIC_ prefix for FastAPI URL | Required for client-side (browser) access in 'use client' components |
| error.retry i18n key added | Missing translation for ContentTable retry button — auto-added Rule 2 |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Enhancement] Added error.retry i18n key**
- **Found during:** Task 2 implementation of ContentTable retry button
- **Issue:** Plan used `t('common.retry', { defaultValue: '再試行' })` but next-intl does not support `defaultValue` option; `common.retry` key did not exist in any message file
- **Fix:** Added `error.retry` key to ja.json (`再試行`), ko.json (`다시 시도`), en.json (`Try again`); updated ContentTable to use `tError('retry')`
- **Files modified:** apps/admin/messages/ja.json, ko.json, en.json, apps/admin/src/components/content/content-table.tsx
- **Commit:** 2e35578

## Known Stubs

- Actions column `詳細` links (`/vocabulary/{id}`, `/grammar/{id}`, `/quiz/{id}`, `/conversation/{id}`) will return 404 until Phase 3 adds detail pages. This is intentional per plan spec: "These links will 404 until Phase 3 adds detail pages."

## Self-Check: PASSED

Verified files exist:
- [x] apps/admin/src/lib/api/admin-content.ts — contains fetchAdminContent, fetchContentStats, PaginatedResponse
- [x] apps/admin/src/hooks/use-content-list.ts — contains useContentList, useSearchParams
- [x] apps/admin/src/hooks/use-dashboard-stats.ts — contains useDashboardStats
- [x] apps/admin/src/components/content/content-table.tsx — contains animate-pulse, ContentTable
- [x] apps/admin/src/components/features/dashboard/stats-card.tsx — contains bg-primary, StatsCard
- [x] apps/admin/src/app/(admin)/vocabulary/page.tsx — contains useContentList, ContentTable, FilterBar, Suspense
- [x] apps/admin/src/app/(admin)/grammar/page.tsx — FOUND
- [x] apps/admin/src/app/(admin)/quiz/page.tsx — FOUND
- [x] apps/admin/src/app/(admin)/conversation/page.tsx — FOUND
- [x] apps/admin/src/app/(admin)/dashboard/page.tsx — contains useDashboardStats, StatsCard

Verified commits exist:
- [x] d881193: feat(02-03): add API client layer and TanStack Query hooks
- [x] 2e35578: feat(02-03): content list pages, dashboard stats, StatsCard, ContentTable
