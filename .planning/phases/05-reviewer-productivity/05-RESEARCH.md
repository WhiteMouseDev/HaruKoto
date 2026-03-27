# Phase 5: Reviewer Productivity - Research

**Researched:** 2026-03-27
**Domain:** Admin UX — Review Queue Navigation, Dashboard Progress Bar, Sidebar Badge Notifications
**Confidence:** HIGH

## Summary

Phase 5 adds three UX improvements to the existing HaruKoto Admin app. All three requirements (UX-01, UX-02, UX-03) are purely frontend enhancements that extend Phase 2 and Phase 3 deliverables. No new database tables or migrations are required — the existing `review_status` field and `/api/v1/admin/content/stats` endpoint already supply everything needed.

The review queue (UX-01) is the most complex piece: a new FastAPI endpoint returns an ordered list of `needs_review` item IDs for a given content type + filter combination. The edit page reads this list from URL state or sessionStorage, tracks the current index, and adds Prev/Next navigation. On approve/reject, `onSuccess` fires a `router.push` to the next ID automatically. The dashboard progress bar (UX-02) is already implemented — `StatsCard` already renders `progressPct` and a visual bar, confirmed by reading `stats-card.tsx`. UX-02 is already done; only i18n string and display polish may be needed if missing. The sidebar badge (UX-03) requires converting `Sidebar` from a server component to a hybrid: a new `SidebarBadge` client component fetches `needs_review` counts via TanStack Query on page load and renders a number badge beside each nav item.

**Primary recommendation:** Implement UX-01 (review queue) as the core wave, confirm UX-02 is already satisfied by existing StatsCard, and add client-side badge polling for UX-03 using existing stats data.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** 목록 페이지에서 진입 — 「リビュー開始」 버튼 클릭 시 첫 번째 needs_review 항목 편집 페이지로 이동. 현재 필터 상태(JLPT, 카테고리)를 유지하면서 탐색
- **D-02:** 다음/이전 네비게이션 — 편집 페이지에 다음/이전 버튼 표시. needs_review 항목만 대상으로 순서대로 이동
- **D-03:** 승인/반려 후 자동 이동 — 승인 또는 반려 완료 시 토스트 표시 후 자동으로 다음 needs_review 항목으로 이동. 마지막 항목이면 목록 페이지로 복귀
- **D-04:** 프로그레스 바 추가 — 기존 StatsCard에 approved/(total) 비율 프로그레스 바 + 퍼센트 표시 추가. 카테고리별로 각각 표시
- **D-05:** 헤더/사이드바 뱃지 — 각 콘텐츠 타입 메뉴 옆에 needs_review 상태 항목 수 뱃지 표시. 클릭하면 해당 목록으로 이동
- **D-06:** 기준은 needs_review 상태 항목 수 — 추가 테이블이나 시간 추적 불필요. 기존 review_status 필드를 카운트

### Claude's Discretion

- 리뷰 큐 정렬 순서 (created_at ASC가 자연스러움)
- 다음/이전 버튼 위치와 디자인
- 뱃지 폴링 주기 (페이지 로드 시 vs 주기적 갱신)
- 프로그레스 바 색상과 스타일
- 리뷰 큐 내 현재 위치 표시 (N/M 형식)

### Deferred Ideas (OUT OF SCOPE)

- 999.1: TTS 필드 UI 개선 (select → 전체 필드 목록 표시) — 별도 백로그
- v2 AUX-01: 키보드 단축키 (J/K, A/R) — v2 요구사항
- v2 AUX-02: 수정 전/후 비교(diff) 뷰 — v2 요구사항
- v2 AUX-03: 리뷰어 간 코멘트/토론 — v2 요구사항
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UX-01 | needs_review 항목을 순서대로 탐색하는 리뷰 큐(다음/이전)가 있다 | New FastAPI endpoint returns ordered ID list; edit pages gain Prev/Next navigation; auto-advance on approve/reject via `onSuccess` callback |
| UX-02 | 대시보드에서 검증 진행률과 카테고리별 현황을 확인할 수 있다 | StatsCard already renders progressPct bar; dashboard page already shows per-category stats — verify i18n completeness and confirm visual sufficiency |
| UX-03 | 새로 추가되거나 변경된 데이터에 대한 알림이 표시된다 | Sidebar nav items gain badge showing needs_review count per content type; data sourced from existing /stats endpoint via TanStack Query |
</phase_requirements>

## Standard Stack

### Core (already installed — no new installs needed)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `next/navigation` (`useRouter`, `useSearchParams`) | Next.js 16.1.6 | Review queue navigation, URL state | Already used in all list pages |
| `@tanstack/react-query` | ^5.90.21 | Badge count fetch, stats polling | Established pattern across admin |
| `sonner` | ^2.0.7 | Toast on approve/reject before auto-advance | Already used in edit pages |
| `next-intl` | — | i18n for new strings (queue UI, badge aria-labels) | Project-wide i18n system |
| `lucide-react` | ^0.575.0 | Prev/Next arrow icons, badge visual | Already used in layout |

### No New Packages Required

All Phase 5 features build on existing libraries. No `npm install` step needed.

## Architecture Patterns

### Recommended Project Structure (additions only)

```
apps/admin/src/
├── hooks/
│   └── use-review-queue.ts       # NEW: review queue ID list + index management
├── components/
│   └── layout/
│       └── sidebar-badge.tsx     # NEW: client component for badge count display
├── app/(admin)/
│   ├── vocabulary/
│   │   └── [id]/page.tsx         # MODIFY: add queue nav props
│   ├── grammar/
│   │   └── [id]/page.tsx         # MODIFY: add queue nav props
│   ├── quiz/
│   │   └── [id]/page.tsx         # MODIFY: add queue nav props
│   └── conversation/
│       └── [id]/page.tsx         # MODIFY: add queue nav props
├── components/content/
│   └── review-header.tsx         # MODIFY: add onNext prop + queue position display
└── components/layout/
    └── sidebar.tsx               # MODIFY: inject SidebarBadge into nav items
```

### Pattern 1: Review Queue — New FastAPI Endpoint

**What:** A new GET endpoint returns an ordered list of `needs_review` item IDs for a content type, filtered by JLPT/category if provided. The frontend stores this list and tracks current index.

**When to use:** Called once when "リビュー開始" is clicked; ID list stored in URL query param or sessionStorage for the queue session.

**FastAPI endpoint design:**
```python
# Source: existing pattern in admin_content.py list endpoints
@router.get("/{content_type}/review-queue", response_model=ReviewQueueResponse)
async def get_review_queue(
    content_type: str,
    db: Annotated[AsyncSession, Depends(get_db)],
    _reviewer: Annotated[User, Depends(require_reviewer)],
    jlpt_level: JlptLevel | None = Query(default=None),
    category: str | None = Query(default=None),
) -> ReviewQueueResponse:
    """Return ordered list of needs_review item IDs for sequential review."""
    ...
    return ReviewQueueResponse(ids=[str(item.id) for item in items], total=len(items))
```

**Pydantic schema (following CamelModel pattern):**
```python
class ReviewQueueResponse(CamelModel):
    ids: list[str]
    total: int
```

**Important:** The existing list endpoint uses `order_by(Model.created_at.desc())`. The review queue should use `created_at ASC` (oldest first = natural queue order). This is a deliberate reversal.

**Important — Quiz content type:** Quiz has two sub-types (`quiz/cloze/{id}` and `quiz/sentence-arrange/{id}`). The review queue endpoint for `quiz` must handle both subtypes by querying both `ClozeQuestion` and `SentenceArrangeQuestion` tables and merging by `created_at ASC`. Each item in the ID list must carry a `quiz_type` discriminator (`cloze` or `sentence_arrange`) so the frontend can construct the correct edit URL.

### Pattern 2: Review Queue — Frontend State Management

**What:** Queue state flows through URL search params. When "リビュー開始" is clicked, the list page pushes to the first item's edit URL with queue context encoded in search params.

**Design:** Pass queue as a comma-separated `queue` param and current index as `qi` (queue index):

```
/vocabulary/abc-123?queue=abc-123,def-456,ghi-789&qi=0
```

**Why URL params over sessionStorage:** Shareable, survives page refresh, consistent with existing `URL searchParams` state management pattern established in Phase 3.

**Frontend hook:**
```typescript
// apps/admin/src/hooks/use-review-queue.ts
'use client';

import { useRouter, useSearchParams } from 'next/navigation';
import { useCallback } from 'react';

export function useReviewQueue(contentType: string) {
  const router = useRouter();
  const searchParams = useSearchParams();

  const queueParam = searchParams.get('queue');
  const qiParam = searchParams.get('qi');
  const ids = queueParam ? queueParam.split(',') : [];
  const currentIndex = qiParam ? Number(qiParam) : -1;
  const isInQueue = ids.length > 0 && currentIndex >= 0;
  const total = ids.length;
  const position = currentIndex + 1; // 1-based for display

  const goNext = useCallback(() => {
    if (currentIndex < ids.length - 1) {
      const nextId = ids[currentIndex + 1];
      // Reconstruct URL with updated qi
      router.push(`/${contentType}/${nextId}?queue=${queueParam}&qi=${currentIndex + 1}`);
    } else {
      // Last item — back to list
      router.push(`/${contentType}`);
    }
  }, [ids, currentIndex, contentType, queueParam, router]);

  const goPrev = useCallback(() => {
    if (currentIndex > 0) {
      const prevId = ids[currentIndex - 1];
      router.push(`/${contentType}/${prevId}?queue=${queueParam}&qi=${currentIndex - 1}`);
    }
  }, [ids, currentIndex, contentType, queueParam, router]);

  return { isInQueue, position, total, goNext, goPrev, hasPrev: currentIndex > 0, hasNext: currentIndex < ids.length - 1 };
}
```

**Queue length limit:** URL length limit in browsers is ~2000 characters. A UUID is 36 chars + comma = 37 chars. At 2000 char limit, max ~50 items in URL. For safety, cap queue fetch at 200 items and use the full list. If the needs_review count exceeds 200, the reviewer handles the batch and triggers a new queue session. Document this limitation explicitly in the endpoint.

### Pattern 3: ReviewHeader Extension (onNext + position display)

**What:** `ReviewHeader` gains an optional `onNext` callback invoked after approve/reject succeeds. The edit page wires `reviewMutation.onSuccess → toast → onNext()`.

**Current signature:**
```typescript
type ReviewHeaderProps = {
  reviewStatus: 'needs_review' | 'approved' | 'rejected';
  onApprove: () => void;
  onReject: () => void;
  isLoading: boolean;
};
```

**New signature:**
```typescript
type ReviewHeaderProps = {
  reviewStatus: 'needs_review' | 'approved' | 'rejected';
  onApprove: () => void;
  onReject: () => void;
  isLoading: boolean;
  // Queue nav (optional — only present when in review queue session)
  queuePosition?: number;   // 1-based current position
  queueTotal?: number;      // total items
  onPrev?: () => void;
  onNext?: () => void;
  hasPrev?: boolean;
  hasNext?: boolean;
};
```

**Auto-advance pattern (from Phase 4 precedent):**
```typescript
// In edit page handleApprove:
function handleApprove() {
  reviewMutation.mutate(
    { action: 'approve' },
    {
      onSuccess: () => {
        toast.success(tReview('approveSuccess'));
        // Auto-advance after toast
        if (onNext) setTimeout(onNext, 800); // brief pause for toast readability
      },
    }
  );
}
```

### Pattern 4: "リビュー開始" Button on List Pages

**What:** Each list page (vocabulary, grammar, quiz, conversation) adds a button above the table. When clicked, it calls the review-queue API then navigates to the first item.

**Implementation:** A new `ReviewStartButton` client component that:
1. Reads current filter params from `useSearchParams()`
2. On click, calls `fetchReviewQueue(contentType, filters)` (new API function in `admin-content.ts`)
3. If `ids.length === 0`, shows a toast "レビュー待ち項目はありません"
4. If items exist, pushes to `/${contentType}/${ids[0]}?queue=${ids.join(',')}&qi=0`

**Placement:** Inside each list page's `<h1>` header row as a secondary button (not inside ContentTable to avoid prop drilling).

### Pattern 5: Sidebar Badge (UX-03)

**What:** The `Sidebar` is currently an async Server Component. Badges require live client data (needs_review counts). The solution: keep `Sidebar` as a server component, extract the nav items rendering to a `SidebarNavWithBadges` client component that fetches stats.

**Stats data source:** Reuse existing `/api/v1/admin/content/stats` endpoint (already used by dashboard). The response contains `needs_review` per content type.

**Stats data mapping:**
- `vocabulary` → vocabulary nav item badge
- `grammar` → grammar nav item badge
- `cloze + sentence_arrange` (merged) → quiz nav item badge
- `conversation` → conversation nav item badge

**Polling strategy:** Page-load only (no interval polling). `staleTime: 60_000` matches the existing `useDashboardStats` hook. If the reviewer wants fresh counts, they navigate to dashboard or refresh. This is appropriate for 1-3 user scale.

**Badge component:**
```typescript
// apps/admin/src/components/layout/sidebar-badge.tsx
'use client';

export function NavBadge({ count }: { count: number }) {
  if (count === 0) return null;
  return (
    <span className="ml-auto flex h-5 min-w-5 items-center justify-center rounded-full bg-destructive px-1 text-[10px] font-semibold text-destructive-foreground">
      {count > 99 ? '99+' : count}
    </span>
  );
}
```

**SidebarNavItem extension:** `SidebarNavItem` gains an optional `badge?: number` prop. When non-zero, renders `<NavBadge count={badge} />` inside the link.

### Pattern 6: UX-02 — Dashboard Progress Bar (Already Implemented)

**Finding (HIGH confidence):** Reading `stats-card.tsx` directly confirms the progress bar is already implemented:
- `progressPct = total > 0 ? Math.round((approved / total) * 100) : 0`
- Visual `<div>` bar with `style={{ width: `${progressPct}%` }}`
- Text label using `t('progressLabel', { n: progressPct })` with `ja.json` value `"{n}% 承認済み"`

**UX-02 is already satisfied by Phase 2 output.** The only potential gap is if the i18n keys for `progressLabel` are missing in `en.json` or `ko.json`. The planner should add a verification task to confirm all three locale files have `progressLabel`.

### Anti-Patterns to Avoid

- **Polling with setInterval for badge counts:** Overkill for 1-3 users. TanStack Query refetch on window focus is sufficient and already configured by default.
- **Global Zustand store for queue state:** URL params are the right primitive — they survive refresh and back-navigation without extra state management.
- **Modifying ContentTable to add "リビュー開始":** ContentTable is a generic reusable component. The button belongs in individual page components.
- **Sidebar becomes fully client:** Keep Server Component shell; only the badge data fetch is client-side. Avoids losing RSC benefits for the static nav structure.
- **Separate queue endpoint per content type:** Use a single `/{content_type}/review-queue` pattern consistent with existing list endpoints. Quiz sub-type handling is an internal implementation detail of that one endpoint.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Toast before auto-navigate | Custom delay/timer system | `sonner` toast + `setTimeout(onNext, 800)` | Already in use, handles dismiss state |
| Badge number display | Custom bubble CSS | Tailwind utility classes (`bg-destructive`, `rounded-full`) | Consistent with design system |
| Review queue ID list fetch | Paginate and pre-fetch incrementally | One-shot endpoint returning all `needs_review` IDs | At 1-3 user scale, fetching 200 IDs upfront is simpler and more reliable than mid-queue pagination |
| Queue position persistence | localStorage/cookie | URL search params | Already established pattern, survives refresh |

**Key insight:** This phase has no genuinely novel problems. Every piece reuses an existing pattern from Phases 2-4. The main implementation work is wiring patterns together correctly.

## Common Pitfalls

### Pitfall 1: Quiz Sub-type URL Routing

**What goes wrong:** The review queue for `quiz` must produce URLs like `/quiz/abc-123?type=cloze&queue=...` because the quiz edit page uses `searchParams.get('type')` to branch between cloze and sentence_arrange forms.

**Why it happens:** Quiz is the only content type with two sub-types sharing one list page. The review-queue endpoint for `quiz` must include a `quiz_type` field per ID, and the frontend must embed `type=cloze` or `type=sentence_arrange` in the navigation URL.

**How to avoid:** In the review queue response for quiz, return `[{ id: "...", quiz_type: "cloze" }, ...]` not just a flat string list. Alternatively, encode as `"cloze:uuid"` in the comma-separated queue param and parse on navigation.

**Warning signs:** Clicking "次へ" from a cloze quiz goes to a blank page or fails to load the form.

### Pitfall 2: Sidebar Server/Client Boundary

**What goes wrong:** `Sidebar` is an async Server Component using `getTranslations` and `getLocale` (server-only next-intl APIs). If you convert it to a client component to add badge state, it breaks because these APIs cannot be called from client components.

**Why it happens:** next-intl has separate client and server APIs. `getTranslations()` is server-only; `useTranslations()` is client-only.

**How to avoid:** Keep `Sidebar` as a server component. Extract only the "nav list with badges" portion into a `SidebarNavWithBadges` client component. Pass translations as props from the server component, or use `useTranslations()` inside the client component (both work — next-intl client hooks work inside client components).

**Warning signs:** Runtime error "this hook is only available in client components" or "cannot use server-only module in client component".

### Pitfall 3: URL Length with Large Queue

**What goes wrong:** If `needs_review` count is very large (e.g., 500+ items), the comma-separated UUID list in the URL exceeds browser URL length limits (~2000 chars).

**Why it happens:** 500 UUIDs × 37 chars each = ~18,500 chars — far exceeds the limit.

**How to avoid:** Cap the review queue endpoint at 200 items. Add a `capped: boolean` flag to the response. If `capped: true`, show a toast "リビューキューは最初の200件のみ表示しています" when starting the queue session.

**Warning signs:** Browser silently truncates the URL; the queue param arrives malformed; `ids.split(',')` produces garbage entries.

### Pitfall 4: Auto-Advance Fires Before Toast Displays

**What goes wrong:** `onNext()` called synchronously in `onSuccess` navigates before the toast has time to render, resulting in the success toast appearing on the next item's page (wrong context) or not at all.

**Why it happens:** `router.push()` triggers a navigation that unmounts the current component, tearing down the toast.

**How to avoid:** Use `setTimeout(onNext, 800)` to let the toast render for ~1 second. The 800ms delay is intentional UX — reviewers should see confirmation before the item disappears. The `sonner` toast has its own lifecycle and will persist across navigation if configured; but a small delay is simpler and clearer.

**Warning signs:** Success toast flashes briefly and disappears, or appears on wrong page.

### Pitfall 5: Stats Endpoint Content Type Mismatch

**What goes wrong:** The `/stats` endpoint returns `content_type` values `"cloze"` and `"sentence_arrange"` separately. The sidebar badge for the "quiz" nav item must sum both.

**Why it happens:** The stats API was designed around DB model names, not UI content types. The dashboard page already handles this by finding `statsItem` by key and the dashboard uses `vocabulary`, `grammar`, `quiz`, `conversation` as keys — but these don't match the API's `cloze`/`sentence_arrange`.

**Reading the code:** `dashboard/page.tsx` uses `data?.stats.find((s) => s.contentType === key)` where key is `quiz` — but the API returns `cloze` and `sentence_arrange`, never `quiz`. This means the quiz StatsCard currently shows 0 for `needsReview` and may always show 0!

**How to avoid:** When computing sidebar badge for quiz, sum `cloze.needs_review + sentence_arrange.needs_review`. Also verify and fix the dashboard's `quiz` stats lookup — it may be a latent bug from Phase 2.

**Warning signs:** Quiz dashboard card always shows 0 for all counts despite data existing.

## Code Examples

### New API Function in admin-content.ts

```typescript
// Source: established pattern in fetchAdminContent
export type ReviewQueueItem = {
  id: string;
  quizType?: string; // only for quiz content type
};

export type ReviewQueueResponse = {
  ids: ReviewQueueItem[];
  total: number;
  capped: boolean;
};

export async function fetchReviewQueue(
  contentType: string,
  params: { jlptLevel?: string; category?: string }
): Promise<ReviewQueueResponse> {
  const headers = await getAuthHeaders();
  const url = new URL(`${API_URL}/api/v1/admin/content/${contentType}/review-queue`);
  if (params.jlptLevel) url.searchParams.set('jlpt_level', params.jlptLevel);
  if (params.category) url.searchParams.set('category', params.category);
  const res = await fetch(url.toString(), { headers });
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json() as Promise<ReviewQueueResponse>;
}
```

### Sidebar Badge Integration

```typescript
// apps/admin/src/components/layout/sidebar.tsx (modified)
// Keep as async Server Component — pass stats data to client child

// New: SidebarNavWithBadges (client component)
'use client';
import { useDashboardStats } from '@/hooks/use-dashboard-stats';
import { SidebarNavItem } from './sidebar-nav-item';
import { NavBadge } from './sidebar-badge';

export function SidebarNavWithBadges({ navItems }: { navItems: NavItemDef[] }) {
  const { data } = useDashboardStats();

  function getBadgeCount(contentTypeKey: string): number {
    if (!data) return 0;
    if (contentTypeKey === 'quiz') {
      // Sum cloze + sentence_arrange
      const cloze = data.stats.find((s) => s.contentType === 'cloze')?.needsReview ?? 0;
      const sa = data.stats.find((s) => s.contentType === 'sentence_arrange')?.needsReview ?? 0;
      return cloze + sa;
    }
    return data.stats.find((s) => s.contentType === contentTypeKey)?.needsReview ?? 0;
  }

  return (
    <nav className="flex flex-1 flex-col gap-1 py-4">
      {navItems.map((item) => (
        <SidebarNavItem
          key={item.href}
          href={item.href}
          icon={item.icon}
          label={item.label}
          badge={getBadgeCount(item.contentTypeKey)}
        />
      ))}
    </nav>
  );
}
```

### i18n Keys to Add (all three locale files)

```json
// ja.json additions
{
  "review": {
    "startQueue": "レビュー開始",
    "startQueueEmpty": "レビュー待ち項目はありません",
    "queuePosition": "{current} / {total}",
    "queueCapped": "最初の200件を表示しています",
    "prevItem": "前へ",
    "nextItem": "次へ",
    "autoAdvance": "次の項目へ移動します"
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Server-side pagination for sequential review | Client-held ID list with URL state | Phase 5 | Simpler, no server roundtrip per navigation |
| Manual next-item navigation | Auto-advance on approve/reject | Phase 5 | Faster review throughput |

## Open Questions

1. **UX-02 Latent Bug — Quiz Stats**
   - What we know: `dashboard/page.tsx` looks up stats by key `"quiz"` but the API returns `"cloze"` and `"sentence_arrange"` as separate entries. The `find()` will return `undefined`.
   - What's unclear: Whether this was intentional (quiz shows 0) or a bug from Phase 2.
   - Recommendation: Treat as a bug. Fix the dashboard stats lookup to sum `cloze + sentence_arrange` for the quiz card. This is a small fix but should be part of the UX-02 verification task.

2. **Queue Encoding for Quiz Sub-types**
   - What we know: Quiz IDs need a type discriminator to navigate to the correct URL.
   - What's unclear: Whether to encode as JSON array (cleaner but long), comma+colon format `"cloze:uuid"`, or a separate `queue_types` param.
   - Recommendation: Use `"cloze:uuid,sentence_arrange:uuid"` encoding — simple to split and parse, no JSON serialization overhead.

## Environment Availability

Step 2.6: SKIPPED (no external dependencies — this phase adds frontend UI and one new FastAPI endpoint on existing infrastructure)

## Validation Architecture

`workflow.nyquist_validation` key is absent from `.planning/config.json` — treat as enabled.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Vitest 4.x + Testing Library |
| Config file | `apps/admin/vitest.config.ts` |
| Quick run command | `cd apps/admin && pnpm vitest run` |
| Full suite command | `cd apps/admin && pnpm vitest run --coverage` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| UX-01 | `useReviewQueue` returns correct next/prev navigation values | unit | `cd apps/admin && pnpm vitest run src/__tests__/use-review-queue.test.ts` | Wave 0 |
| UX-01 | `useReviewQueue` returns `isInQueue: false` when no queue params | unit | same file | Wave 0 |
| UX-01 | ReviewHeader renders Prev/Next buttons when queuePosition/queueTotal props provided | unit | `cd apps/admin && pnpm vitest run src/__tests__/review-header.test.tsx` | Wave 0 |
| UX-02 | StatsCard renders progress bar with correct percentage | unit | `cd apps/admin && pnpm vitest run src/__tests__/stats-card.test.tsx` | Wave 0 |
| UX-03 | `NavBadge` renders count badge when count > 0, renders null when count is 0 | unit | `cd apps/admin && pnpm vitest run src/__tests__/nav-badge.test.tsx` | Wave 0 |
| UX-03 | `SidebarNavItem` renders badge when badge prop is non-zero | unit | `cd apps/admin && pnpm vitest run src/__tests__/sidebar-nav-item.test.tsx` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `cd apps/admin && pnpm vitest run`
- **Per wave merge:** `cd apps/admin && pnpm vitest run --coverage`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `apps/admin/src/__tests__/use-review-queue.test.ts` — covers UX-01 queue navigation logic
- [ ] `apps/admin/src/__tests__/review-header.test.tsx` — covers UX-01 Prev/Next button rendering
- [ ] `apps/admin/src/__tests__/stats-card.test.tsx` — covers UX-02 progress bar rendering
- [ ] `apps/admin/src/__tests__/nav-badge.test.tsx` — covers UX-03 badge display
- [ ] `apps/admin/src/__tests__/sidebar-nav-item.test.tsx` — covers UX-03 badge integration (file does not exist)

## Project Constraints (from CLAUDE.md)

| Directive | Impact on Phase 5 |
|-----------|-------------------|
| TypeScript strict mode + no `any` | All new hooks/components must be fully typed |
| File naming: kebab-case | `use-review-queue.ts`, `sidebar-badge.tsx`, `review-start-button.tsx` |
| `type` alias preferred over `interface` | Use `type ReviewQueueProps = {...}` |
| DDL authority: Alembic only | No schema changes needed — this phase is DDL-free |
| New domain logic goes to FastAPI, not Next API Routes | Review queue endpoint goes in `apps/api/app/routers/admin_content.py` |
| CamelModel for admin schemas | New `ReviewQueueResponse` extends `CamelModel` |
| Codex cross-validation before commit on feature changes | New FastAPI endpoint + new hooks require Codex verification |
| ruff lint before API commits | `cd apps/api && uv run ruff check app/ tests/ && uv run ruff format --check app/ tests/` |
| pnpm lint before frontend commits | `pnpm lint` from monorepo root |
| Conventional commits | `feat: add review queue navigation for UX-01` |

## Sources

### Primary (HIGH confidence)
- Direct file reads: `apps/admin/src/components/content/review-header.tsx` — confirmed current props signature
- Direct file reads: `apps/admin/src/components/features/dashboard/stats-card.tsx` — confirmed progress bar already implemented
- Direct file reads: `apps/admin/src/hooks/use-content-list.ts` — confirmed URL searchParams state pattern
- Direct file reads: `apps/admin/src/hooks/use-content-detail.ts` — confirmed `onSuccess` callback pattern for mutations
- Direct file reads: `apps/admin/src/components/layout/sidebar.tsx` — confirmed Server Component structure
- Direct file reads: `apps/api/app/routers/admin_content.py` lines 127-167, 1096-1131 — confirmed list endpoint pattern and stats endpoint

### Secondary (MEDIUM confidence)
- Next.js 16 App Router docs: URL search params are the idiomatic way to share state between pages — consistent with project's Phase 3 established pattern

### Tertiary (LOW confidence)
- Browser URL length limit of ~2000 chars: industry-known limitation; specific browser limits vary (Chrome: 2MB, practical limit for server routing: 2000 chars)

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — all libraries already installed and in use
- Architecture: HIGH — all patterns are direct extensions of existing Phase 2-4 code, read directly from source
- Pitfalls: HIGH — identified from direct code analysis (quiz stats bug is confirmed from reading dashboard/page.tsx + stats endpoint)

**Research date:** 2026-03-27
**Valid until:** 2026-04-27 (stable project, no external dependency changes expected)
