---
phase: 05-reviewer-productivity
verified: 2026-03-27T16:46:00Z
status: human_needed
score: 13/14 must-haves verified
re_verification: false
human_verification:
  - test: "Visit each content type list page and click 'レビュー開始' button. Verify navigation to first needs_review item with queue URL params."
    expected: "Browser navigates to /{contentType}/{firstId}?queue=...&qi=0"
    why_human: "ReviewStartButton calls live API endpoint; requires running dev server with seeded DB data"
  - test: "On a content edit page with queue params in URL, verify QueueNavigationBar renders with position counter and Prev/Next buttons."
    expected: "Full-width bar appears above ReviewHeader showing e.g. '1 / 5' with navigation buttons"
    why_human: "Conditional rendering of QueueNavigationBar requires queue URL params in browser context"
  - test: "Click Approve on a content item while in queue mode. Verify auto-advance fires after approximately 800ms."
    expected: "Success toast appears, then after ~800ms browser navigates to next item in queue"
    why_human: "setTimeout(goNext, 800) behavior requires live user interaction and running app"
  - test: "Check sidebar badges after page load. Verify vocabulary, grammar, quiz, conversation nav items show red number badges."
    expected: "Red pill badges with needs_review counts appear on content type nav items (not dashboard)"
    why_human: "Badge counts come from live TanStack Query fetch to /api/v1/admin/content/stats"
  - test: "Visit dashboard and verify quiz StatsCard shows non-zero values if quiz data exists."
    expected: "Quiz card displays merged cloze + sentence_arrange totals instead of 0"
    why_human: "Requires live DB data with cloze/sentence_arrange rows in needs_review status"
---

# Phase 5: Reviewer Productivity Verification Report

**Phase Goal:** Reviewer productivity features — review queue navigation, sidebar badges, dashboard fix
**Verified:** 2026-03-27T16:46:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | GET /review-queue/{content_type} returns ordered list of needs_review item IDs (created_at ASC) | VERIFIED | `admin_content.py:1059` — route exists, `order_by(model.created_at.asc())` at line 1085 |
| 2 | Quiz review-queue returns items with quiz_type discriminator (cloze or sentence_arrange) | VERIFIED | `_get_quiz_review_queue` at line 1099, merges both types with `quiz_type` field |
| 3 | Review queue is capped at 200 items and response includes capped boolean | VERIFIED | `REVIEW_QUEUE_LIMIT = 200` at line 1056, `capped: bool` in `ReviewQueueResponse` schema |
| 4 | Frontend fetchReviewQueue function can call the endpoint with JLPT/category filters | VERIFIED | `admin-content.ts:250` — function exists with jlptLevel/category params, URL matches backend route |
| 5 | Sidebar nav items display needs_review count badges | VERIFIED | `SidebarNavWithBadges` wired into `sidebar.tsx`, `NavBadge` renders count from `useDashboardStats()` |
| 6 | NavBadge renders null when count is 0 and red pill when count > 0 | VERIFIED | `sidebar-badge.tsx:4` — `if (count === 0) return null`, `bg-destructive` class applied |
| 7 | NavBadge shows 99+ when count exceeds 99 | VERIFIED | `sidebar-badge.tsx:7` — `count > 99 ? '99+' : count` |
| 8 | Quiz badge sums cloze + sentence_arrange needs_review counts | VERIFIED | `sidebar-nav-with-badges.tsx:20-23` — explicit merge logic for `contentTypeKey === 'quiz'` |
| 9 | Dashboard quiz StatsCard receives merged cloze + sentence_arrange stats | VERIFIED | `dashboard/page.tsx` — `getStatsForKey()` helper at line 11, merges cloze+sentence_arrange for key='quiz' |
| 10 | StatsCard progress bar displays approved/total percentage per category | VERIFIED | `stats-card.tsx:25,66-71` — `progressPct`, `bg-primary` bar, `t('progressLabel', { n: progressPct })` |
| 11 | progressLabel i18n key exists in ja.json, en.json, and ko.json | VERIFIED | `grep -c progressLabel` returns 1 in each file |
| 12 | Reviewer can start queue and navigate sequentially through needs_review items | VERIFIED (code) | `ReviewStartButton`, `useReviewQueue`, `QueueNavigationBar` all wired into all 4 content type pages |
| 13 | Auto-advance fires after approve/reject with 800ms delay | VERIFIED (code) | `setTimeout(goNext, 800)` in all 4 edit pages; `queueComplete` toast + `exitQueue` on last item |
| 14 | End-to-end review queue flow (live app) | ? HUMAN NEEDED | Requires running dev server with seeded DB |

**Score:** 13/14 truths verified (automated); 5 items flagged for human verification

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `apps/api/app/schemas/admin_content.py` | ReviewQueueItem and ReviewQueueResponse schemas | VERIFIED | `ReviewQueueItem` at line 237, `ReviewQueueResponse` at line 242 |
| `apps/api/app/routers/admin_content.py` | GET /review-queue/{content_type} endpoint | VERIFIED | Route at line 1059, real DB query logic |
| `apps/api/tests/test_admin_review_queue.py` | pytest tests for review queue endpoint | PARTIAL — STUBS | 5 tests exist but all have `@pytest.mark.skip(reason="Wave 1 — DB fixture setup pending")`. File exists with correct test function names but no executable test logic. |
| `apps/admin/src/lib/api/admin-content.ts` | fetchReviewQueue frontend API function | VERIFIED | Function at line 250, types at 239/244, URL matches backend route |
| `apps/admin/src/components/layout/sidebar-badge.tsx` | NavBadge component | VERIFIED | `export function NavBadge` with correct behavior |
| `apps/admin/src/components/layout/sidebar-nav-with-badges.tsx` | SidebarNavWithBadges client component | VERIFIED | Wires `useDashboardStats()` to nav item badges with quiz merge logic |
| `apps/admin/src/__tests__/nav-badge.test.tsx` | Tests for NavBadge | VERIFIED | 4 tests, all pass |
| `apps/admin/src/__tests__/sidebar-nav-item.test.tsx` | Tests for SidebarNavItem badge integration | VERIFIED | 3 tests, all pass |
| `apps/admin/src/hooks/use-review-queue.ts` | useReviewQueue hook | VERIFIED | Reads queue/qi URL params, exports goNext/goPrev/exitQueue/isLastItem |
| `apps/admin/src/components/content/queue-navigation-bar.tsx` | QueueNavigationBar component | VERIFIED | Prev/Next buttons, position counter, exit link |
| `apps/admin/src/components/content/review-start-button.tsx` | ReviewStartButton component | VERIFIED | Calls `fetchReviewQueue`, navigates to first item |
| `apps/admin/src/__tests__/use-review-queue.test.ts` | Tests for useReviewQueue hook | VERIFIED | 5 tests, all pass |
| `apps/admin/src/__tests__/review-header.test.tsx` | Tests for ReviewHeader callbacks | VERIFIED | 5 tests, all pass |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `apps/admin/src/lib/api/admin-content.ts` | `apps/api/app/routers/admin_content.py` | GET /review-queue/{content_type} HTTP call | WIRED | Frontend URL `review-queue/${contentType}` matches backend route `/review-queue/{content_type}` under prefix `/api/v1/admin/content` |
| `apps/admin/src/components/layout/sidebar-nav-with-badges.tsx` | `apps/admin/src/hooks/use-dashboard-stats.ts` | useDashboardStats() hook for badge count data | WIRED | `import { useDashboardStats }` at line 4, called at line 29 |
| `apps/admin/src/components/layout/sidebar.tsx` | `apps/admin/src/components/layout/sidebar-nav-with-badges.tsx` | Server component renders client SidebarNavWithBadges | WIRED | `import { SidebarNavWithBadges }` at line 10, rendered at line 66 |
| `apps/admin/src/components/content/review-start-button.tsx` | `apps/admin/src/lib/api/admin-content.ts` | fetchReviewQueue() call on button click | WIRED | `import { fetchReviewQueue }` at line 10, called at line 28 in `handleStart()` |
| `apps/admin/src/hooks/use-review-queue.ts` | URL search params | useSearchParams() reads queue and qi params | WIRED | `searchParams.get('queue')` at line 10, `searchParams.get('qi')` at line 11 |
| `apps/admin/src/app/(admin)/vocabulary/[id]/page.tsx` | `apps/admin/src/hooks/use-review-queue.ts` | useReviewQueue hook for auto-advance | WIRED | `import { useReviewQueue }` at line 14, called at line 71, `setTimeout(goNext, 800)` at line 130 |
| All 4 edit pages | `apps/admin/src/components/content/queue-navigation-bar.tsx` | Conditional render when isInQueue | WIRED | All 4 edit pages: `import { QueueNavigationBar }`, conditional `{isInQueue && <QueueNavigationBar .../>}` |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `sidebar-nav-with-badges.tsx` | `data` from `useDashboardStats()` | FastAPI `/stats` endpoint — `func.count()` GROUP BY `review_status` in `admin_content.py:1200` | Yes — real DB aggregation query | FLOWING |
| `dashboard/page.tsx` (StatsCard) | `merged` from `getStatsForKey(data?.stats, key)` | Same `/stats` endpoint as above | Yes | FLOWING |
| `review-start-button.tsx` | `data` from `fetchReviewQueue()` | FastAPI `/review-queue/{content_type}` — real DB SELECT with WHERE `review_status == NEEDS_REVIEW` | Yes | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| TypeScript compiles without errors | `pnpm --filter @harukoto/admin exec tsc --noEmit` | Exits 0 (no output) | PASS |
| Frontend test suite — 17 tests | `pnpm vitest run` in apps/admin | 17/17 passed, 4 test files | PASS |
| fetchReviewQueue URL matches backend route | grep comparison | Frontend: `review-queue/${contentType}`, Backend: `/review-queue/{content_type}` under `/api/v1/admin/content` | PASS |
| Live review queue end-to-end | Requires running server | Not testable without running server + seeded DB | SKIP |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| UX-01 | Plans 01 + 03 | needs_review 항목을 순서대로 탐색하는 리뷰 큐(다음/이전)가 있다 | SATISFIED (code) | Backend review-queue endpoint, frontend useReviewQueue hook, QueueNavigationBar, ReviewStartButton all wired across all 4 content types. Human verification needed for live flow. |
| UX-02 | Plans 02 | 대시보드에서 검증 진행률과 카테고리별 현황을 확인할 수 있다 | SATISFIED | Dashboard quiz bug fixed with `getStatsForKey()` merging cloze+sentence_arrange. StatsCard renders `progressPct` bar with `progressLabel` i18n key in all 3 locales. |
| UX-03 | Plans 02 | 새로 추가되거나 변경된 데이터에 대한 알림이 표시된다 | SATISFIED (code) | Sidebar badges implemented via `NavBadge` + `SidebarNavWithBadges` wired to live `useDashboardStats()`. Human verification needed to confirm badge counts display correctly with live data. |

No orphaned requirements found — all 3 IDs (UX-01, UX-02, UX-03) are claimed by plans and implementation evidence exists.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `apps/api/tests/test_admin_review_queue.py` | 14,20,26,32,38 | All 5 pytest tests are `@pytest.mark.skip` stubs | Warning | Backend endpoint is not covered by executable tests. SUMMARY documents this as intentional ("Wave 1 — DB fixture setup pending"). Backend logic is real but untested by automated tests. |
| `apps/admin/src/components/layout/sidebar-badge.tsx` | 4 | `return null` | Info | Intentional behavior — badge should not render when count=0. Not a stub. |

**Stub classification note:** The `return null` in `sidebar-badge.tsx` is correct behavior confirmed by tests (`renders null when count is 0`). The skipped pytest tests are a known deferred item, not a functional blocker — the backend endpoint logic is complete and the frontend relies on it correctly.

### Plan vs. Implementation Deviation

**Route path deviation (non-breaking):** The PLAN specified the route as `/{content_type}/review-queue` but the implementation uses `/review-queue/{content_type}`. Both the backend and frontend agree on the implemented path, so the API contract is internally consistent. This deviation from the PLAN text has no functional impact.

### Human Verification Required

#### 1. Review Queue Start Flow

**Test:** Visit the vocabulary list page in the running admin app. Verify the "レビュー開始" button appears in the page header row next to the title.
**Expected:** Button labeled "レビュー開始" (with Play icon) is visible. Clicking it calls the review-queue API and navigates to `/vocabulary/{firstId}?queue=...&qi=0`.
**Why human:** ReviewStartButton calls the live FastAPI endpoint; requires running dev server with seeded vocabulary data in needs_review status.

#### 2. QueueNavigationBar Render

**Test:** Navigate to a vocabulary edit page with `?queue=id1,id2,id3&qi=1` URL params manually appended.
**Expected:** A full-width navigation bar appears above the ReviewHeader showing "2 / 3" position counter, enabled Prev button (since qi=1), enabled Next button (since not last), and "キューを終了" exit link.
**Why human:** Conditional rendering requires URL params in browser; not testable with static grep.

#### 3. Auto-advance Behavior

**Test:** While in queue mode (queue URL params present), click Approve on a needs_review item.
**Expected:** Toast success message appears. After approximately 800ms, browser automatically navigates to the next item in the queue.
**Why human:** `setTimeout(goNext, 800)` timing requires live interaction.

#### 4. Sidebar Badge Counts

**Test:** Log into the admin app and observe the sidebar navigation.
**Expected:** Vocabulary, grammar, quiz, and conversation nav items show red number badges with their respective needs_review counts. Dashboard nav item has no badge (no contentTypeKey). Badges update after approving/rejecting items.
**Why human:** Badge counts depend on live TanStack Query fetch to `/api/v1/admin/content/stats`.

#### 5. Dashboard Quiz Card Stats

**Test:** Visit the dashboard. Observe the quiz StatsCard.
**Expected:** Quiz card shows non-zero total/approved/needs_review values (if quiz data exists), not 0 across all fields.
**Why human:** Requires DB rows in cloze and sentence_arrange tables to verify the merge fix is visible.

### Gaps Summary

No functional gaps found in code artifacts. All 13 automatically verifiable truths pass. One known deferred item exists (pytest stubs) which is intentional per SUMMARY documentation and does not block the phase goal.

The single unresolved item is human verification of the live end-to-end flow. All code is wired correctly; the verification requires a running dev server with seeded review data.

---

_Verified: 2026-03-27T16:46:00Z_
_Verifier: Claude (gsd-verifier)_
