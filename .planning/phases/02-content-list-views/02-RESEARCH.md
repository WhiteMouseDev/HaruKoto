# Phase 02: Content List Views - Research

**Researched:** 2026-03-26
**Domain:** Next.js 16.1 Admin UI + FastAPI admin endpoints + Alembic DDL migration
**Confidence:** HIGH

## Summary

Phase 2 adds four content list pages (vocabulary, grammar, quiz, conversation scenarios) to the admin app, backed by new FastAPI admin endpoints at `/api/v1/admin/content/*`. The core DDL change is adding a `review_status` column (enum: `needs_review` / `approved` / `rejected`) to five tables via a single Alembic migration. The admin Next.js app already has TanStack Query, shadcn/ui, and next-intl wired up from Phase 1; no new infrastructure is needed.

The main design choices are: (1) where admin authentication happens on the FastAPI side — a new `require_admin_role` dependency mirroring the Supabase `app_metadata.reviewer` check; (2) how the Next.js admin app calls FastAPI — recommended pattern is Server Components fetching FastAPI directly (with Supabase service role token or a dedicated admin API key), **not** duplicating the route through a BFF Next.js API route (api-plane.md forbids new domain logic in Next API routes); (3) the Table component is not yet installed in `apps/admin/src/components/ui/` — it must be added via `shadcn add table`.

**Primary recommendation:** Build three separable units in sequence: (A) Alembic migration + SQLAlchemy model patches + FastAPI admin router, (B) shadcn Table install + Sidebar component + content page shell + i18n keys, (C) TanStack Query hooks + search/filter/pagination wiring + dashboard stats swap.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** review_status added to existing tables (vocabularies, grammars, cloze_questions, sentence_arrange_questions, conversation_scenarios) via Alembic migration
- **D-02:** review_status enum values: `needs_review` (default), `approved`, `rejected`
- **D-03:** Content queries via FastAPI admin-only endpoints `/api/v1/admin/content/*` using SQLAlchemy
- **D-04:** No changes to existing mobile/web API — admin router is isolated
- **D-05:** Table layout with columns: word/pattern, reading/explanation, meaning, JLPT level, review status (adjusted per content type)
- **D-06:** Left sidebar navigation — Dashboard, 単語, 文法, クイズ, 会話 (5 items). Phase 1 layout modified to add sidebar
- **D-07:** Paginated by page number, 20 items per page, numbered page controls
- **D-08:** Status badges: needs_review=yellow, approved=green, rejected=red
- **D-09:** Dashboard cards — replace placeholder with real counts (needs_review / approved / rejected per content type) + progress bar
- **D-10:** Search with 300ms debounce
- **D-11:** Filters inline above table: search + JLPT level dropdown + category dropdown + status dropdown
- **D-12:** URL query params preserve filter state (survives refresh/share)

### Claude's Discretion
- FastAPI admin endpoint detailed design (pagination params, response schema)
- Alembic migration script implementation detail
- shadcn Table component structure
- TanStack Query caching strategy
- Sidebar responsive behavior (collapse, etc.)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LIST-01 | Reviewer가 단어/어휘 목록을 페이지네이션으로 조회할 수 있다 | FastAPI `/api/v1/admin/content/vocabulary` with `page`/`page_size` params; `PaginatedResponse[VocabularyAdminItem]` schema already exists as base class |
| LIST-02 | Reviewer가 문법/문장 목록을 페이지네이션으로 조회할 수 있다 | FastAPI `/api/v1/admin/content/grammar`; same pattern |
| LIST-03 | Reviewer가 퀴즈/문제 목록을 페이지네이션으로 조회할 수 있다 | Two quiz tables (cloze_questions, sentence_arrange_questions); single `/quiz` endpoint with `quiz_type` param or split endpoints — Claude's discretion |
| LIST-04 | Reviewer가 회화 시나리오 목록을 페이지네이션으로 조회할 수 있다 | FastAPI `/api/v1/admin/content/conversation` |
| LIST-05 | JLPT 레벨, 카테고리, 검증 상태로 필터링 | SQLAlchemy `.where()` clauses on `jlpt_level`, `category`, `review_status`; URL query params in Next.js |
| LIST-06 | 텍스트 검색으로 특정 데이터를 찾을 수 있다 | SQLAlchemy `ilike` on key text columns (word/pattern/sentence/title); 300ms debounce client-side, query param server-side |
| LIST-07 | 검증 상태 뱃지 표시 | Client-side badge component with color mapping; data comes from `review_status` field in API response |
</phase_requirements>

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| shadcn/ui (Table) | installed via `shadcn add table` | Data table rendering | Project uses shadcn style "new-york"; Table not yet in ui/ dir |
| TanStack Query | ^5.90.21 (already in package.json) | Server state, caching, pagination | Already wired via QueryProvider |
| next-intl | ^4.8.3 (already installed) | i18n for new UI strings | Phase 1 established pattern |
| SQLAlchemy async | >=2.0 (already in API) | Admin content queries | Project ORM for FastAPI |
| Alembic | >=1.14 (already in API) | DDL — add review_status column | Sole DDL authority per api-plane.md |
| Pydantic v2 | >=2.10 (already in API) | Request/response schemas | Project standard |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `usePathname`, `useRouter`, `useSearchParams` (Next.js built-in) | Next.js 16.1 | URL query param sync for filters | Filter state management without extra state lib |
| `lucide-react` | ^0.575.0 (already installed) | Icons in sidebar, badges | Project icon standard |
| `CamelModel` (app.schemas.common) | — | FastAPI response serialization | All existing schemas use this; camelCase JSON keys |
| `PaginatedResponse[T]` (app.schemas.common) | — | Paginated list responses | Already defined, use as-is |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| URL query params for filter state | Zustand store | URL params allow sharing/bookmarking (D-12 requires this) |
| Server Component fetch to FastAPI | Next.js BFF API route proxy | BFF route forbidden per api-plane.md for domain logic |
| shadcn Table | TanStack Table (headless) | shadcn Table is sufficient; TanStack Table adds complexity not needed at this scale |

**Installation (shadcn Table — only missing component):**
```bash
cd apps/admin && pnpm dlx shadcn@latest add table
```

---

## Architecture Patterns

### Recommended Project Structure (additions to Phase 1)
```
apps/admin/src/
├── app/(admin)/
│   ├── layout.tsx              # MODIFY: add sidebar, change flex layout
│   ├── dashboard/page.tsx      # MODIFY: real stats from API
│   ├── vocabulary/page.tsx     # NEW: list page
│   ├── grammar/page.tsx        # NEW: list page
│   ├── quiz/page.tsx           # NEW: list page
│   └── conversation/page.tsx   # NEW: list page
├── components/
│   ├── layout/
│   │   └── sidebar.tsx         # NEW: sidebar nav component
│   ├── content/
│   │   ├── content-table.tsx   # NEW: shared table with badge
│   │   ├── filter-bar.tsx      # NEW: search + dropdowns
│   │   └── pagination.tsx      # NEW: page number controls
│   └── ui/
│       └── table.tsx           # NEW: shadcn add table
├── hooks/
│   ├── use-content-list.ts     # NEW: TanStack Query hook per content type
│   └── use-dashboard-stats.ts  # NEW: TanStack Query hook for stats
└── lib/
    └── api/
        └── admin-content.ts    # NEW: fetch helpers for FastAPI admin endpoints

apps/api/app/
├── routers/
│   └── admin_content.py        # NEW: admin content router
├── schemas/
│   └── admin_content.py        # NEW: Pydantic schemas for admin responses
├── models/
│   ├── content.py              # MODIFY: add review_status field
│   ├── conversation.py         # MODIFY: add review_status field
│   └── enums.py                # MODIFY: add ReviewStatus enum
└── alembic/versions/
    └── i9j0k1l2m3n4_add_review_status.py  # NEW: migration
```

### Pattern 1: Alembic Migration for review_status

**What:** Add PostgreSQL ENUM type `ReviewStatus` and `review_status` column to 5 tables.
**When to use:** DDL changes — exclusively via Alembic per api-plane.md.

```python
# apps/api/alembic/versions/i9j0k1l2m3n4_add_review_status.py
import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "i9j0k1l2m3n4"
down_revision = "h8i9j0k1l2m3"

TABLES = [
    "vocabularies",
    "grammars",
    "cloze_questions",
    "sentence_arrange_questions",
    "conversation_scenarios",
]

review_status_enum = postgresql.ENUM(
    "needs_review", "approved", "rejected",
    name="reviewstatus",
    create_type=True,
)

def upgrade() -> None:
    review_status_enum.create(op.get_bind(), checkfirst=True)
    for table in TABLES:
        op.add_column(
            table,
            sa.Column(
                "review_status",
                sa.Enum("needs_review", "approved", "rejected", name="reviewstatus"),
                nullable=False,
                server_default="needs_review",
            ),
        )
        op.create_index(f"idx_{table}_review_status", table, ["review_status"])

def downgrade() -> None:
    for table in TABLES:
        op.drop_index(f"idx_{table}_review_status", table_name=table)
        op.drop_column(table, "review_status")
    review_status_enum.drop(op.get_bind(), checkfirst=True)
```

**Critical:** The `JlptLevel` enum in `app/enums.py` includes `ABSOLUTE_ZERO` but the DB DDL (initial snapshot) only has `N5`-`N1`. For `ReviewStatus`, define a new enum — do NOT extend `JlptLevel`.

### Pattern 2: FastAPI Admin Router with require_admin dependency

**What:** New router at `/api/v1/admin/content/*` with a new dependency checking `app_metadata.reviewer`.
**When to use:** All admin-only FastAPI endpoints.

```python
# apps/api/app/routers/admin_content.py
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Annotated

from app.db.session import get_db
from app.models.content import Vocabulary
from app.models.enums import JlptLevel, ReviewStatus
from app.schemas.admin_content import (
    VocabularyAdminItem,
    ContentStatsResponse,
)
from app.schemas.common import PaginatedResponse
from app.dependencies import get_current_user
from app.models.user import User

router = APIRouter(prefix="/api/v1/admin/content", tags=["admin-content"])


async def require_admin_role(
    user: Annotated[User, Depends(get_current_user)],
    # Note: reviewer claim is in Supabase app_metadata, not in the User DB row.
    # The JWT payload contains app_metadata. We need to verify from the token, not DB.
) -> User:
    # IMPORTANT: reviewer claim comes from Supabase JWT app_metadata,
    # not stored in the users table. Must extract from JWT payload.
    # See Phase 1 pattern: proxy.ts checks user.app_metadata.reviewer === true
    # FastAPI equivalent: decode JWT and check app_metadata claim.
    raise HTTPException(status_code=403, detail="Not a reviewer")


@router.get("/vocabulary", response_model=PaginatedResponse[VocabularyAdminItem])
async def list_vocabulary(
    db: Annotated[AsyncSession, Depends(get_db)],
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    jlpt_level: JlptLevel | None = Query(default=None),
    review_status: ReviewStatus | None = Query(default=None),
    search: str | None = Query(default=None),
):
    ...
```

**CRITICAL DESIGN NOTE on admin auth:** The current `get_current_user` dependency validates the JWT and fetches the User from the DB. However, the `reviewer` flag lives in Supabase `app_metadata` (JWT claim), NOT in the `users` table. Two options:

1. **Option A (recommended):** Create `require_reviewer_token` dependency that decodes the JWT and checks `app_metadata.reviewer` from the JWT payload directly — similar to how `_decode_token` works in `dependencies.py`. Does NOT require a DB round-trip.
2. **Option B:** Add a `is_reviewer` boolean column to the `users` table and sync it — more complex, requires migration.

Option A is simpler and consistent with the Phase 1 proxy.ts pattern.

**Revised dependency approach:**
```python
async def require_reviewer(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(bearer_scheme)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> User:
    payload = _decode_token(credentials.credentials)  # reuse from dependencies.py
    # app_metadata is embedded in the JWT by Supabase
    app_metadata = payload.get("app_metadata", {})
    if not app_metadata.get("reviewer"):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Reviewer role required")
    # ... fetch and return user from DB
```

### Pattern 3: TanStack Query Hook + URL Param Sync

**What:** Client component reads URL search params for filter state, fires TanStack Query based on params.
**When to use:** All four content list pages (shared hook pattern).

```typescript
// apps/admin/src/hooks/use-content-list.ts
'use client';
import { useQuery } from '@tanstack/react-query';
import { useSearchParams } from 'next/navigation';

type ContentType = 'vocabulary' | 'grammar' | 'quiz' | 'conversation';

export function useContentList(type: ContentType) {
  const searchParams = useSearchParams();
  const page = Number(searchParams.get('page') ?? '1');
  const search = searchParams.get('search') ?? '';
  const jlptLevel = searchParams.get('jlpt_level') ?? '';
  const reviewStatus = searchParams.get('review_status') ?? '';

  return useQuery({
    queryKey: ['admin-content', type, { page, search, jlptLevel, reviewStatus }],
    queryFn: () => fetchAdminContent(type, { page, search, jlptLevel, reviewStatus }),
    staleTime: 30 * 1000,
  });
}
```

**URL update pattern (filter bar):**
```typescript
// Use router.push() with updated searchParams — resets page to 1 on filter change
const router = useRouter();
const pathname = usePathname();

function updateFilter(key: string, value: string) {
  const params = new URLSearchParams(searchParams.toString());
  params.set(key, value);
  if (key !== 'page') params.set('page', '1');  // reset page on filter change
  router.push(`${pathname}?${params.toString()}`);
}
```

### Pattern 4: How Admin Next.js Calls FastAPI

**Current state:** The admin app has NO existing FastAPI integration. Phase 1 only calls Supabase. There is no `apiFetch` equivalent in admin.

**Recommended approach:** Server Components fetch FastAPI directly using the reviewer's Supabase JWT (obtained server-side), OR a dedicated `ADMIN_API_KEY` env var for internal service-to-service calls.

**Preferred for this phase:** Server-side fetch from Next.js Server Components using the user's Supabase session token as Bearer:

```typescript
// apps/admin/src/lib/api/admin-content.ts
import { createClient } from '@/lib/supabase/server';

export async function fetchAdminContentServer(
  type: string,
  params: Record<string, string>
) {
  const supabase = await createClient();
  const { data: { session } } = await supabase.auth.getSession();
  const token = session?.access_token;

  const url = new URL(`${process.env.FASTAPI_URL}/api/v1/admin/content/${type}`);
  Object.entries(params).forEach(([k, v]) => v && url.searchParams.set(k, v));

  const res = await fetch(url.toString(), {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json();
}
```

**For Client Components (TanStack Query):** The existing admin app does NOT have a browser-side API call utility that passes JWT. A client-side `apiFetch`-equivalent must forward the Supabase token from the browser session.

**Alternative:** Make list pages full Server Components that fetch and render — simpler, no TanStack Query needed on client. Then progressive enhancement for search/filter could use `useRouter`/URL param updates that trigger page navigation (which re-runs Server Component). This avoids browser-to-FastAPI auth complexity.

**Decision for planner (Claude's Discretion):** Choose one approach:
- **A) Server Component + URL navigation** (simpler, no client auth needed) — recommended for Phase 2 given no existing client-FastAPI pattern
- **B) Client Component + TanStack Query** (richer UX, requires client-side JWT forwarding)

Both are valid. Option A aligns with Next.js App Router patterns and avoids browser-to-FastAPI CORS/auth surface.

### Pattern 5: Sidebar Layout Modification

**What:** Admin layout currently is `flex-col` (header + main). Add sidebar by wrapping in `flex-row`.
**When to use:** `apps/admin/src/app/(admin)/layout.tsx` modification.

```tsx
// Modified layout structure
return (
  <div className="flex min-h-screen flex-col">
    <Header user={user} locale={locale} />
    <div className="flex flex-1 overflow-hidden">
      <Sidebar />
      <main className="flex-1 overflow-y-auto p-8">{children}</main>
    </div>
  </div>
);
```

### Anti-Patterns to Avoid

- **BFF duplication:** Do NOT create Next.js API routes that proxy admin content endpoints. api-plane.md forbids this.
- **Prisma for DDL:** Do NOT use `prisma db push` or `prisma migrate` for review_status. Alembic only.
- **Enum name collision:** The PostgreSQL enum `ReviewStatus` does not exist yet — use `create_type=True` in the Alembic migration. The `JlptLevel` ABSOLUTE_ZERO exists in Python enum but NOT in initial DB DDL; treat as a template for the pattern.
- **getSession() in FastAPI:** The admin dependency must call Supabase JWKS / JWT decode, not rely on a session cookie.
- **Direct DB writes from Next.js for content:** All content data lives in FastAPI/SQLAlchemy domain. Do not use Prisma to read `vocabularies` / `grammars` etc. for admin (though technically possible — it violates the domain separation established by api-plane.md).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Paginated list response | Custom pagination logic | `PaginatedResponse[T]` from `app.schemas.common` | Already defined, used throughout API |
| camelCase JSON serialization | Manual alias | `CamelModel` from `app.schemas.common` | All existing schemas use it; clients expect camelCase |
| Table component | Custom HTML table | `shadcn add table` | Consistent with Phase 1 shadcn style "new-york" |
| Debounce for search | Custom setTimeout | `use-debounce` npm package OR `useDeferredValue` (React 19) | React 19 already included; `useDeferredValue` is zero-dep |
| Status badge colors | Tailwind custom logic | Inline variant map in component | Simple enough to inline; no lib needed |
| Admin auth dependency | New JWT library | Reuse `_decode_token` from `app.dependencies` | Already handles ES256/HS256 with JWKS caching |

**Key insight:** Phase 1 built solid infrastructure. Phase 2 extends it — don't re-invent what already exists.

---

## Common Pitfalls

### Pitfall 1: review_status PostgreSQL ENUM vs Python StrEnum
**What goes wrong:** Creating the Python `ReviewStatus` enum as `StrEnum` but the Alembic migration creates it as a native PostgreSQL ENUM. PostgreSQL's native ENUM and SQLAlchemy's `Enum()` type must match exactly.
**Why it happens:** The existing enums in `app/enums.py` use `str, enum.Enum` pattern (not `StrEnum`). The initial DDL snapshot uses native PG ENUM types. Follow this exact pattern.
**How to avoid:** Add `ReviewStatus` to `app/enums.py` as `class ReviewStatus(str, enum.Enum)`. Alembic migration uses `postgresql.ENUM(..., name="reviewstatus", create_type=True)`. SQLAlchemy model column uses `sa.Enum("needs_review", ..., name="reviewstatus")`.
**Warning signs:** SQLAlchemy emits `CREATE TYPE reviewstatus AS ENUM` on every test run — means `create_type=True` not respected.

### Pitfall 2: JlptLevel ABSOLUTE_ZERO missing from DB
**What goes wrong:** Filtering by JLPT level using the Python `JlptLevel.ABSOLUTE_ZERO` value causes a DB error because the initial DDL only has `N5..N1`.
**Why it happens:** The Python enum was extended after initial migration (see `f6g7h8i9j0k1_add_goals_and_absolute_zero.py` adds ABSOLUTE_ZERO to the JlptLevel PG enum).
**How to avoid:** Check that migration `f6g7h8i9j0k1` added ABSOLUTE_ZERO to the DB. The admin filter UI should map to valid DB values.
**Warning signs:** `invalid input value for enum "JlptLevel": "ABSOLUTE_ZERO"` error from Postgres.

### Pitfall 3: CamelModel alias_generator breaks Query params
**What goes wrong:** FastAPI route handlers using `CamelModel` for request bodies work, but Query parameters with snake_case names also get aliased — causing `jlptLevel` to be expected instead of `jlpt_level` as query param name.
**Why it happens:** `alias_generator` applies to Pydantic models, but FastAPI Query params are defined as function arguments (not model fields). Query params remain snake_case as written. This is fine — just document that query params are snake_case, response JSON is camelCase.
**How to avoid:** Use plain function arguments for Query params. Reserve `CamelModel` for response schemas.

### Pitfall 4: Next.js 16 `useSearchParams` requires Suspense boundary
**What goes wrong:** Using `useSearchParams()` in a Client Component causes build errors or hydration issues without a `<Suspense>` wrapper.
**Why it happens:** Next.js 16 App Router requires `useSearchParams()` callers to be wrapped in `<Suspense>` during static rendering.
**How to avoid:** Wrap the filter bar / pagination client components in `<Suspense fallback={...}>` at the page level.
**Warning signs:** `useSearchParams() should be wrapped in a suspense boundary` build warning.

### Pitfall 5: Sidebar makes layout.tsx no longer a pure Server Component
**What goes wrong:** If Sidebar uses `usePathname()` for active state highlighting, it becomes a Client Component, which forces layout.tsx to become a Client Component.
**Why it happens:** Server Components can't use client hooks.
**How to avoid:** Extract sidebar link highlighting into a small `'use client'` child component (`sidebar-nav-item.tsx`) while keeping `sidebar.tsx` and `layout.tsx` as Server Components.

### Pitfall 6: FASTAPI_URL env var not set in admin app
**What goes wrong:** Admin app has no existing FastAPI integration. `FASTAPI_URL` / `NEXT_PUBLIC_API_URL` env var is not defined in admin's deployment config.
**Why it happens:** Phase 1 admin app only uses Supabase. No FastAPI connection was established.
**How to avoid:** Plan a Wave 0 task to add `FASTAPI_URL` to admin `.env.local` and Vercel project env vars.
**Warning signs:** `fetch` calls to undefined URL silently fail or throw.

---

## Code Examples

### Example 1: ReviewStatus enum in SQLAlchemy model
```python
# apps/api/app/enums.py — add this
class ReviewStatus(str, enum.Enum):
    NEEDS_REVIEW = "needs_review"
    APPROVED = "approved"
    REJECTED = "rejected"

# apps/api/app/models/content.py — add to Vocabulary
from app.models.enums import JlptLevel, PartOfSpeech, ReviewStatus

class Vocabulary(Base):
    # ... existing fields ...
    review_status: Mapped[ReviewStatus] = mapped_column(
        nullable=False,
        server_default="needs_review",
    )
```

### Example 2: Admin content list query with filters
```python
# apps/api/app/routers/admin_content.py
@router.get("/vocabulary", response_model=PaginatedResponse[VocabularyAdminItem])
async def list_vocabulary(
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_reviewer)],
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    jlpt_level: JlptLevel | None = Query(default=None),
    review_status: ReviewStatus | None = Query(default=None),
    search: str | None = Query(default=None),
) -> PaginatedResponse[VocabularyAdminItem]:
    stmt = select(Vocabulary)
    if jlpt_level:
        stmt = stmt.where(Vocabulary.jlpt_level == jlpt_level)
    if review_status:
        stmt = stmt.where(Vocabulary.review_status == review_status)
    if search:
        stmt = stmt.where(
            or_(
                Vocabulary.word.ilike(f"%{search}%"),
                Vocabulary.reading.ilike(f"%{search}%"),
                Vocabulary.meaning_ko.ilike(f"%{search}%"),
            )
        )
    total = (await db.execute(select(func.count()).select_from(stmt.subquery()))).scalar_one()
    items = (await db.execute(stmt.offset((page - 1) * page_size).limit(page_size))).scalars().all()
    return PaginatedResponse(
        items=[VocabularyAdminItem.model_validate(v) for v in items],
        total=total,
        page=page,
        page_size=page_size,
        total_pages=(total + page_size - 1) // page_size,
    )
```

### Example 3: Dashboard stats endpoint
```python
# apps/api/app/routers/admin_content.py
@router.get("/stats", response_model=AdminStatsResponse)
async def get_admin_stats(
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_reviewer)],
) -> AdminStatsResponse:
    # Single query per content type, grouped by review_status
    async def count_by_status(model):
        result = await db.execute(
            select(model.review_status, func.count(model.id)).group_by(model.review_status)
        )
        counts = {row[0]: row[1] for row in result.all()}
        return ContentStatusCounts(
            needs_review=counts.get(ReviewStatus.NEEDS_REVIEW, 0),
            approved=counts.get(ReviewStatus.APPROVED, 0),
            rejected=counts.get(ReviewStatus.REJECTED, 0),
        )
    return AdminStatsResponse(
        vocabulary=await count_by_status(Vocabulary),
        grammar=await count_by_status(Grammar),
        quiz=await count_by_status(ClozeQuestion),  # or combine cloze + sentence
        conversation=await count_by_status(ConversationScenario),
    )
```

### Example 4: Status badge component
```tsx
// apps/admin/src/components/content/status-badge.tsx
import { cn } from '@/lib/utils';

type ReviewStatus = 'needs_review' | 'approved' | 'rejected';

const STATUS_STYLES: Record<ReviewStatus, string> = {
  needs_review: 'bg-yellow-100 text-yellow-800 border-yellow-200',
  approved: 'bg-green-100 text-green-800 border-green-200',
  rejected: 'bg-red-100 text-red-800 border-red-200',
};

type StatusBadgeProps = { status: ReviewStatus; label: string };

export function StatusBadge({ status, label }: StatusBadgeProps) {
  return (
    <span
      className={cn(
        'inline-flex items-center rounded-full border px-2 py-0.5 text-xs font-medium',
        STATUS_STYLES[status],
      )}
    >
      {label}
    </span>
  );
}
```

### Example 5: i18n keys to add (ja.json additions)
```json
{
  "nav": {
    "dashboard": "ダッシュボード",
    "vocabulary": "単語",
    "grammar": "文法",
    "quiz": "クイズ",
    "conversation": "会話"
  },
  "content": {
    "status": {
      "needs_review": "レビュー待ち",
      "approved": "承認済み",
      "rejected": "却下"
    },
    "filter": {
      "search": "検索...",
      "jlptLevel": "JLPTレベル",
      "status": "ステータス",
      "category": "カテゴリ",
      "all": "すべて"
    },
    "table": {
      "word": "単語",
      "reading": "読み方",
      "meaning": "意味",
      "jlptLevel": "JLPT",
      "status": "ステータス"
    },
    "pagination": {
      "prev": "前へ",
      "next": "次へ",
      "of": "/ {total}ページ"
    }
  },
  "dashboard": {
    "statsNeeds": "レビュー待ち",
    "statsApproved": "承認済み",
    "statsRejected": "却下",
    "progress": "進捗"
  }
}
```

---

## Runtime State Inventory

> Phase 2 adds new DB columns — this is an additive DDL change, not a rename/refactor. No existing runtime state holds `review_status` values because the column does not exist yet.

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | No `review_status` column exists in any table (confirmed by grep — no hits in app code) | Alembic migration will CREATE and backfill with `server_default="needs_review"` |
| Live service config | No existing admin API endpoints exist at `/api/v1/admin/*` | New router registration in `main.py` |
| OS-registered state | None | None |
| Secrets/env vars | `FASTAPI_URL` env var not set in admin app — this is a gap | Add to admin `.env.local` and Vercel project settings |
| Build artifacts | None relevant | None |

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node.js | admin Next.js build | ✓ | >=20 (CI uses 22) | — |
| pnpm | workspace install | ✓ | 10.19.0 | — |
| Python 3.12 + uv | FastAPI dev/test | ✓ | per CLAUDE.md | — |
| PostgreSQL (Supabase) | Alembic migration | ✓ (remote Supabase) | 16 | — |
| `shadcn` CLI | Add Table component | ✓ | ^3.8.5 (devDep) | — |
| `FASTAPI_URL` env var | Admin → FastAPI calls | ✗ | — | Block: must set before API calls work |

**Missing dependencies with no fallback:**
- `FASTAPI_URL` env var — admin app has never called FastAPI before. Must add to `.env.local` and Vercel before any admin → FastAPI feature works.

**Missing dependencies with fallback:**
- None.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Vitest ^4.0.18 |
| Config file | `apps/admin/vitest.config.ts` |
| Quick run command | `cd apps/admin && pnpm test` |
| Full suite command | `cd apps/admin && pnpm test` (no separate watch mode needed for CI) |
| Python tests | `cd apps/api && uv run pytest tests/ -x -q` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LIST-01 | Vocabulary list pagination | unit (Python) | `cd apps/api && uv run pytest tests/test_admin_content.py::test_vocabulary_list -x` | ❌ Wave 0 |
| LIST-02 | Grammar list pagination | unit (Python) | `cd apps/api && uv run pytest tests/test_admin_content.py::test_grammar_list -x` | ❌ Wave 0 |
| LIST-03 | Quiz list pagination | unit (Python) | `cd apps/api && uv run pytest tests/test_admin_content.py::test_quiz_list -x` | ❌ Wave 0 |
| LIST-04 | Conversation list pagination | unit (Python) | `cd apps/api && uv run pytest tests/test_admin_content.py::test_conversation_list -x` | ❌ Wave 0 |
| LIST-05 | Filter by JLPT/category/status | unit (Python) | `cd apps/api && uv run pytest tests/test_admin_content.py::test_filter_params -x` | ❌ Wave 0 |
| LIST-06 | Text search | unit (Python) | `cd apps/api && uv run pytest tests/test_admin_content.py::test_search -x` | ❌ Wave 0 |
| LIST-07 | Status badge display | unit (TS) | `cd apps/admin && pnpm test -- --reporter=verbose` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `cd apps/api && uv run ruff check app/ tests/` + `cd apps/admin && pnpm lint`
- **Per wave merge:** `cd apps/api && uv run pytest tests/test_admin_content.py -x` + `cd apps/admin && pnpm test`
- **Phase gate:** Both test suites green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `apps/api/tests/test_admin_content.py` — covers LIST-01 through LIST-06; needs pytest fixtures for admin reviewer token
- [ ] `apps/admin/src/__tests__/status-badge.test.tsx` — covers LIST-07
- [ ] `apps/admin/src/components/ui/table.tsx` — install via `shadcn add table` (not a test gap, but required before component tests)

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `middleware.ts` in Next.js | `proxy.ts` (established in Phase 1) | Phase 1 | Do NOT create middleware.ts — Next.js 16 forbids both |
| `getSession()` for auth | `getUser()` for live DB validation | Phase 1 | AUTH-03 compliance — do NOT use getSession |
| Prisma for all DB | Dual ORM: Prisma (web) + SQLAlchemy (API) | Pre-Phase 1 | Admin reads content via FastAPI/SQLAlchemy, not Prisma |

---

## Open Questions

1. **Admin auth on FastAPI: where does `reviewer` claim come from in JWT?**
   - What we know: Supabase embeds `app_metadata` in the JWT. The Phase 1 proxy.ts checks `user.app_metadata.reviewer === true`.
   - What's unclear: Does the standard Supabase JWT include `app_metadata` at the top level or nested under a custom claim? Need to verify the JWT payload structure.
   - Recommendation: Log a decoded JWT in development to confirm the claim path. The safe assumption is `payload.get("app_metadata", {}).get("reviewer")` based on Supabase docs.

2. **Quiz list — one endpoint or two?**
   - What we know: Two quiz tables: `cloze_questions` and `sentence_arrange_questions`. Both have `jlpt_level` and will have `review_status`.
   - What's unclear: Should the admin show them combined (one Quiz list page) or separate?
   - Recommendation: Single `/quiz` endpoint with a `quiz_type` query param (`cloze` | `sentence_arrange` | `all`). The page tab/filter makes it clear which sub-type is showing. This avoids a fifth page and matches the D-06 sidebar decision (only 5 items).

3. **FASTAPI_URL for admin app — internal or public URL?**
   - What we know: FastAPI deploys to Google Cloud Run (asia-northeast3). Admin deploys to Vercel.
   - What's unclear: Should admin call the public Cloud Run URL or a private VPC endpoint?
   - Recommendation: Use the public Cloud Run URL for now (simplest). Add `FASTAPI_URL` env var to admin Vercel project pointing to Cloud Run URL.

---

## Project Constraints (from CLAUDE.md)

Directives that constrain this phase's implementation:

- **DDL authority:** Alembic ONLY. No `prisma db push` / `prisma migrate` for content tables.
- **Domain logic:** FastAPI first. New admin content API = FastAPI router, not Next.js BFF.
- **BFF restriction:** Next.js API routes only for auth bridging, cron, push. Admin content queries go directly to FastAPI.
- **TypeScript strict mode:** `noUncheckedIndexedAccess: true` — array accesses must be guarded.
- **No `any` types:** Use `unknown` + type guard or explicit types.
- **File naming:** kebab-case for files (`admin-content.ts`, `status-badge.tsx`), PascalCase exports.
- **Python naming:** snake_case files (`admin_content.py`), PascalCase Pydantic models.
- **Ruff before commit:** `cd apps/api && uv run ruff check app/ tests/ && uv run ruff format --check app/ tests/`
- **ESLint before commit:** `pnpm lint`
- **Codex cross-verification:** API contract changes + new FastAPI endpoints require Codex review before commit.
- **Commit convention:** `feat:` for new features, `chore:` for migrations/config.
- **No middleware.ts:** Phase 1 established proxy.ts as the canonical middleware. Do not create middleware.ts.

---

## Sources

### Primary (HIGH confidence)
- Codebase direct inspection: `apps/api/app/models/content.py`, `conversation.py`, `enums.py` — confirmed no `review_status` column
- Codebase direct inspection: `apps/api/app/schemas/common.py` — `PaginatedResponse[T]` confirmed available
- Codebase direct inspection: `apps/api/app/dependencies.py` — `_decode_token`, `get_current_user` pattern confirmed
- Codebase direct inspection: `apps/api/alembic/versions/h8i9j0k1l2m3_add_srs_columns.py` — Alembic migration pattern confirmed
- Codebase direct inspection: `apps/admin/src/app/(admin)/layout.tsx` — current layout structure confirmed
- Codebase direct inspection: `apps/admin/package.json` — all dependencies confirmed (TanStack Query, next-intl, shadcn)
- Codebase direct inspection: `apps/admin/src/components/ui/` — Table NOT present, must add
- Codebase direct inspection: `.claude/rules/api-plane.md` — BFF restriction confirmed
- Phase 1 CONTEXT.md decisions — all Phase 1 patterns documented

### Secondary (MEDIUM confidence)
- Next.js 16 App Router docs pattern: `useSearchParams` requires Suspense boundary — consistent with React 18+ behavior, Next.js 16 enforces this at build time
- Supabase JWT `app_metadata` claim placement — standard Supabase behavior, confirmed by Phase 1 proxy.ts implementation

### Tertiary (LOW confidence)
- FastAPI JWT `app_metadata` payload path (`payload.get("app_metadata", {})`) — inferred from Supabase standard JWT structure; should be verified by logging a decoded token in dev

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries confirmed in package.json, codebase
- Architecture: HIGH — patterns derived from existing Phase 1 code and project rules
- Pitfalls: HIGH — derived from actual code inspection (enum patterns, migration patterns, Next.js layout)
- Admin auth design: MEDIUM — `reviewer` claim path in FastAPI JWT needs runtime verification

**Research date:** 2026-03-26
**Valid until:** 2026-04-25 (30 days — stable stack)
