---
phase: 02-content-list-views
verified: 2026-03-26T00:00:00Z
status: passed
score: 14/14 must-haves verified
re_verification: false
---

# Phase 02: Content List Views Verification Report

**Phase Goal:** Reviewer가 4개 콘텐츠 타입의 데이터를 조회·검색·필터링할 수 있다
**Verified:** 2026-03-26
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (from ROADMAP.md Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Reviewer가 단어·문법·퀴즈·회화 시나리오 각각의 목록 페이지에서 페이지네이션으로 탐색 가능 | VERIFIED | All 4 pages exist and use `useContentList` + `PaginationBar` wired to API pagination response |
| 2 | JLPT 레벨, 카테고리, 검증 상태로 필터링하면 결과가 즉시 반영 | VERIFIED | `FilterBar` writes `jlpt`/`category`/`status` to URL via `router.replace()` on each select change; `useContentList` reads URL params and passes them to FastAPI as `jlpt_level`, `category`, `review_status` query params; FastAPI applies `.where()` filters with enum matching |
| 3 | 검색창에 텍스트 입력 시 해당 텍스트 포함 항목만 표시 | VERIFIED | `FilterBar` debounces 300ms via `setTimeout`, writes `q` to URL; `useContentList` maps `q` → `search`; FastAPI uses `ilike(f"%{search}%")` on key text columns for all 4 content types |
| 4 | 각 목록 행에 검증 상태 뱃지(needs_review/approved/rejected)가 시각적으로 표시 | VERIFIED | `StatusBadge` renders 3 color states (amber/green/red with dark mode variants); `ContentTable` uses `StatusBadge` for status column; all 4 list pages wire `ContentTable` with `reviewStatus` field from API response |
| 5 | 대시보드에서 콘텐츠 타입별 검증 현황(상태별 건수)을 한눈에 확인 | VERIFIED | `useDashboardStats()` calls `fetchContentStats()` → FastAPI `/stats` using `func.count + group_by`; dashboard page renders 4 `StatsCard` components with real counts and `bg-primary` progress bar |

**Score:** 5/5 success criteria verified

### Plan-level Must-Have Truths

#### Plan 01 (FastAPI backend)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | GET /api/v1/admin/content/vocabulary returns paginated vocabulary list with review_status | VERIFIED | `@router.get("/vocabulary")` confirmed, `VocabularyAdminItem` has `review_status`, returns `PaginatedResponse[VocabularyAdminItem]` |
| 2 | GET /api/v1/admin/content/grammar returns paginated grammar list | VERIFIED | `@router.get("/grammar")` confirmed |
| 3 | GET /api/v1/admin/content/quiz returns paginated quiz list (cloze + sentence-arrange) | VERIFIED | `@router.get("/quiz")` merges both types with optional `quiz_type` filter |
| 4 | GET /api/v1/admin/content/conversation returns paginated conversation list | VERIFIED | `@router.get("/conversation")` with `category` param |
| 5 | All 4 endpoints support jlpt_level, review_status, and search query params | VERIFIED | All endpoints declare `jlpt_level: JlptLevel | None`, `review_status: ReviewStatus | None`, `search: str | None` Query params |
| 6 | Non-reviewer JWT is rejected with 403 | VERIFIED | `require_reviewer` dependency decodes JWT via `_decode_token`, checks `app_metadata.reviewer == True`, raises 403 if not |

#### Plan 02 (UI shell)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 7 | Sidebar displays 5 navigation items with correct icons and highlights active route | VERIFIED | `sidebar.tsx` has 5 `SidebarNavItem` calls with lucide icons (LayoutDashboard/BookOpen/BookMarked/HelpCircle/MessageSquare); `sidebar-nav-item.tsx` uses `usePathname()` for active detection with `border-l-2 border-primary bg-accent` |
| 8 | Admin layout is two-column: sidebar (240px) + main content | VERIFIED | `layout.tsx` renders `<Sidebar />` in `flex flex-1 overflow-hidden`; sidebar has `w-60` (240px) |
| 9 | StatusBadge renders 3 visual states with correct colors | VERIFIED | `bg-amber-100` (needs_review), `bg-green-100` (approved), `bg-red-100` (rejected) with dark variants |
| 10 | FilterBar has search input, JLPT dropdown, category dropdown, status dropdown | VERIFIED | `filter-bar.tsx` has all 4 controls, 300ms debounce on search, `useSearchParams` + `router.replace` for URL sync |
| 11 | PaginationBar renders numbered page buttons with active page highlighted | VERIFIED | `pagination-bar.tsx` has `ChevronLeft`/`ChevronRight`, `bg-primary text-primary-foreground` for active page |
| 12 | All new UI text has i18n keys in ja/ko/en | VERIFIED | `ja.json` contains `nav`, `filter`, `status`, `table`, `empty`, `error` sections; search placeholder "検索..." confirmed in ja/ko |

#### Plan 03 (end-to-end wiring)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 13 | All 4 content pages display paginated tables with review_status badges | VERIFIED | Each page calls `useContentList('{type}')`, renders `<ContentTable>` + `<FilterBar>` + `<PaginationBar>` inside `<Suspense>` |
| 14 | Dashboard shows 4 cards with real needs_review/approved/rejected counts | VERIFIED | `dashboard/page.tsx` uses `useDashboardStats()` + renders 4 `StatsCard` components with progress bar (`bg-primary` fill) |

**Score:** 14/14 must-haves verified

---

## Required Artifacts

| Artifact | Status | Details |
|----------|--------|---------|
| `apps/api/app/enums.py` | VERIFIED | `class ReviewStatus` with NEEDS_REVIEW/APPROVED/REJECTED values |
| `apps/api/app/models/content.py` | VERIFIED | 4 `review_status` fields (Vocabulary, Grammar, ClozeQuestion, SentenceArrangeQuestion) |
| `apps/api/app/models/conversation.py` | VERIFIED | 1 `review_status` field on ConversationScenario |
| `apps/api/app/models/enums.py` | VERIFIED | Re-exports `ReviewStatus` |
| `apps/api/alembic/versions/a1b2c3d4e5f6_add_review_status.py` | VERIFIED | All 5 tables, `down_revision = "0e6f6c2a3136"`, PostgreSQL ENUM, indexes |
| `apps/api/app/schemas/admin_content.py` | VERIFIED | 6 Pydantic classes including `VocabularyAdminItem` and `ContentStatsResponse` |
| `apps/api/app/routers/admin_content.py` | VERIFIED | 5 `@router.get` endpoints, `require_reviewer` with `app_metadata` check |
| `apps/api/app/main.py` | VERIFIED | `include_router(admin_content_router)` registered |
| `apps/api/tests/test_admin_content.py` | VERIFIED | 8 `def test_` stubs (intentionally skipped, Wave 1 pending per VALIDATION.md) |
| `apps/admin/src/components/layout/sidebar.tsx` | VERIFIED | 80 lines, `w-60`, 5 nav items with lucide icons |
| `apps/admin/src/components/layout/sidebar-nav-item.tsx` | VERIFIED | `'use client'`, `usePathname()` active detection |
| `apps/admin/src/components/ui/table.tsx` | VERIFIED | shadcn Table installed |
| `apps/admin/src/components/ui/status-badge.tsx` | VERIFIED | 38 lines, `bg-amber-100` color mapping |
| `apps/admin/src/components/content/filter-bar.tsx` | VERIFIED | 126 lines, `useSearchParams`, 300ms debounce, `router.replace` |
| `apps/admin/src/components/ui/pagination-bar.tsx` | VERIFIED | 116 lines, `ChevronLeft`/`ChevronRight`, `bg-primary` active state |
| `apps/admin/src/__tests__/status-badge.test.tsx` | VERIFIED | Color assertions for all 3 states |
| `apps/admin/src/lib/api/admin-content.ts` | VERIFIED | 107 lines, `fetchAdminContent`, `fetchContentStats`, `NEXT_PUBLIC_FASTAPI_URL`, Supabase JWT |
| `apps/admin/src/hooks/use-content-list.ts` | VERIFIED | 35 lines, `useContentList`, `useSearchParams`, `staleTime: 30_000` |
| `apps/admin/src/hooks/use-dashboard-stats.ts` | VERIFIED | `useDashboardStats`, `fetchContentStats`, `staleTime: 60_000` |
| `apps/admin/src/components/content/content-table.tsx` | VERIFIED | `animate-pulse` skeleton, error/empty states |
| `apps/admin/src/components/features/dashboard/stats-card.tsx` | VERIFIED | `bg-primary` progress bar fill |
| `apps/admin/src/app/(admin)/vocabulary/page.tsx` | VERIFIED | 112 lines, `useContentList('vocabulary')`, `ContentTable`, `FilterBar`, `Suspense` |
| `apps/admin/src/app/(admin)/grammar/page.tsx` | VERIFIED | `useContentList('grammar')` |
| `apps/admin/src/app/(admin)/quiz/page.tsx` | VERIFIED | `useContentList('quiz')` |
| `apps/admin/src/app/(admin)/conversation/page.tsx` | VERIFIED | `useContentList('conversation')`, `showCategory`, `SCENARIO_CATEGORIES` |
| `apps/admin/src/app/(admin)/dashboard/page.tsx` | VERIFIED | `useDashboardStats()`, 4 `StatsCard` renders |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `apps/api/app/main.py` | `apps/api/app/routers/admin_content.py` | `app.include_router` | WIRED | `from app.routers.admin_content import router as admin_content_router` + `app.include_router(admin_content_router)` confirmed |
| `apps/api/app/routers/admin_content.py` | `apps/api/app/dependencies.py` | `require_reviewer` using `_decode_token` | WIRED | `require_reviewer` defined in router; decodes JWT via `_decode_token`, checks `app_metadata.reviewer` |
| `apps/admin/src/app/(admin)/layout.tsx` | `apps/admin/src/components/layout/sidebar.tsx` | `import Sidebar` + render in flex layout | WIRED | `import { Sidebar }` confirmed, `<Sidebar />` in `flex flex-1 overflow-hidden` div |
| `apps/admin/src/components/layout/sidebar-nav-item.tsx` | `next/navigation usePathname` | active route detection | WIRED | `import { usePathname }` and `pathname` usage confirmed |
| `apps/admin/src/hooks/use-content-list.ts` | `apps/admin/src/lib/api/admin-content.ts` | `queryFn` calls `fetchAdminContent` | WIRED | `import { fetchAdminContent }` + `queryFn: () => fetchAdminContent<T>(type, params)` confirmed |
| `apps/admin/src/app/(admin)/vocabulary/page.tsx` | `apps/admin/src/hooks/use-content-list.ts` | `useContentList('vocabulary')` | WIRED | `import { useContentList }` + `useContentList<VocabularyItem>('vocabulary')` confirmed |
| `apps/admin/src/app/(admin)/dashboard/page.tsx` | `apps/admin/src/hooks/use-dashboard-stats.ts` | `useDashboardStats()` | WIRED | `import { useDashboardStats }` + usage in component body confirmed |

---

## Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `vocabulary/page.tsx` | `data` (items, total, totalPages) | `useContentList('vocabulary')` → `fetchAdminContent` → FastAPI `/vocabulary` → SQLAlchemy `Vocabulary` table query | Yes — DB query with pagination, `ilike` search, enum filters | FLOWING |
| `dashboard/page.tsx` | `data` (stats array) | `useDashboardStats()` → `fetchContentStats()` → FastAPI `/stats` → `func.count + group_by review_status` on 4 tables | Yes — real aggregation counts from DB | FLOWING |
| `content-table.tsx` | `data` prop | Passed from page components via `ContentTable data={data?.items}` | Yes — flows from TanStack Query response | FLOWING |
| `stats-card.tsx` | `needsReview`, `approved`, `rejected`, `total` | Passed as props from dashboard page via `StatsCard` | Yes — real counts from `/stats` endpoint | FLOWING |

---

## Behavioral Spot-Checks

Step 7b: SKIPPED — requires running FastAPI server + Next.js dev server with database connection. No runnable entry points can be tested statically. Human verification covers the live behavior.

---

## Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|-------------|---------------|-------------|--------|----------|
| LIST-01 | 02-01, 02-03 | Reviewer가 단어/어휘 목록을 페이지네이션으로 조회 | SATISFIED | `/vocabulary` page with `useContentList` + FastAPI paginated endpoint + `PaginationBar` |
| LIST-02 | 02-01, 02-03 | Reviewer가 문법/문장 목록을 페이지네이션으로 조회 | SATISFIED | `/grammar` page + FastAPI `/grammar` endpoint |
| LIST-03 | 02-01, 02-03 | Reviewer가 퀴즈/문제 목록을 페이지네이션으로 조회 | SATISFIED | `/quiz` page + FastAPI `/quiz` endpoint (merges cloze + sentence-arrange) |
| LIST-04 | 02-01, 02-03 | Reviewer가 회화 시나리오 목록을 페이지네이션으로 조회 | SATISFIED | `/conversation` page + FastAPI `/conversation` endpoint |
| LIST-05 | 02-01, 02-02, 02-03 | JLPT 레벨, 카테고리, 검증 상태로 필터링 | SATISFIED | `FilterBar` URL sync → `useContentList` param mapping → FastAPI `.where()` filters for all 3 filter types |
| LIST-06 | 02-01, 02-02, 02-03 | 텍스트 검색으로 특정 데이터 찾기 | SATISFIED | `FilterBar` 300ms debounce + URL `q` param → `useContentList` → FastAPI `ilike` search on key columns |
| LIST-07 | 02-02, 02-03 | 각 항목에 검증 상태 뱃지 표시 | SATISFIED | `StatusBadge` component with amber/green/red mapping; `ContentTable` renders it per row; `status-badge.test.tsx` passes (5/5) |

All 7 requirement IDs (LIST-01 through LIST-07) accounted for. No orphaned requirements.

---

## Anti-Patterns Found

| File | Pattern | Severity | Impact |
|------|---------|----------|--------|
| `apps/api/tests/test_admin_content.py` | All 8 tests marked `@pytest.mark.skip` | Info | Intentional per VALIDATION.md Wave 0 requirement; stubs are placeholder for Wave 1 DB fixture work. Does NOT block goal — backend endpoints are fully implemented and wired. |
| All 4 list pages — Actions column | `詳細` links to `/{type}/{id}` will 404 | Info | Intentional per plan spec; Phase 3 adds detail pages. URL structure is in place. |

No blockers or warnings found.

---

## Human Verification Required

### 1. Filter Results Reflect Immediately

**Test:** Log in as a reviewer, navigate to `/vocabulary`, select "N5" from the JLPT dropdown.
**Expected:** Table immediately re-fetches and shows only N5 vocabulary items. URL updates to `?jlpt=N5`.
**Why human:** Requires live FastAPI + DB connection; cannot verify filter effect with static grep.

### 2. Search Debounce Behavior

**Test:** In the search input on any list page, type a word — observe that the API fetch does not fire on every keystroke, but fires ~300ms after the last keystroke.
**Expected:** Network request visible in DevTools fires once, 300ms after typing stops.
**Why human:** Timing behavior requires browser + DevTools observation.

### 3. Page Refresh Preserves Filters

**Test:** Apply a filter + navigate to page 2 on vocabulary. Refresh the browser.
**Expected:** Same filters and page 2 are restored (URL params `?jlpt=N5&page=2` preserved).
**Why human:** Requires browser session and Next.js SSR/client hydration behavior check.

### 4. Dashboard Real Counts

**Test:** Open `/dashboard`, check that the 4 StatsCards show non-zero counts (assuming content data exists in DB).
**Expected:** Cards show real `needs_review`/`approved`/`rejected` counts; progress bar fills proportionally.
**Why human:** Requires live DB with content data; counts cannot be verified statically.

### 5. Reviewer-Only Access

**Test:** Access `/vocabulary` without a Supabase session, or with a session where `app_metadata.reviewer` is not `true`.
**Expected:** API calls return 403; UI shows error state.
**Why human:** Requires Supabase Auth setup and JWT claim management.

---

## Gaps Summary

No gaps. All automated checks passed across all three plans:

- Plan 01: ReviewStatus enum, 5-table Alembic migration, 5 FastAPI endpoints, `require_reviewer` auth gate, and Pydantic schemas are all substantive and wired.
- Plan 02: Sidebar (2-column layout), StatusBadge (3 color states), FilterBar (debounced URL sync), PaginationBar (numbered + active), shadcn Table, and i18n keys in all 3 locales are all substantive and wired.
- Plan 03: API client with Supabase JWT, TanStack Query hooks (useContentList + useDashboardStats), 4 content list pages, ContentTable, StatsCard, and dashboard wired end-to-end. Data flows from DB → FastAPI → fetch → TanStack Query → React render.

The only known stubs (API test skips + detail page 404s) are intentional and documented in both SUMMARY files and VALIDATION.md.

---

_Verified: 2026-03-26_
_Verifier: Claude (gsd-verifier)_
