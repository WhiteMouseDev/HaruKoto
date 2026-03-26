# Phase 03: Content Editing & Review Workflow - Research

**Researched:** 2026-03-26
**Domain:** FastAPI PATCH endpoints + Alembic DDL + React Hook Form + TanStack Query mutations + shadcn Dialog
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**편집 폼 레이아웃**
- D-01: 전용 편집 페이지 — `/vocabulary/[id]`, `/grammar/[id]` 등 상세 페이지에서 직접 편집. 편집 폼 + 승인/반려 + 감사 로그가 한 페이지에
- D-02: 편집 후 같은 페이지 유지 + 성공 토스트 표시. 연속 수정에 편리하도록 리다이렉트 없음
- D-03: 필드 검증은 submit 시에만 (Phase 1 D-03 유지). 에러는 필드 옆에 인라인 표시

**승인/반려 워크플로우**
- D-04: 승인/반려 버튼은 편집 페이지 상단 — 현재 상태 뱃지와 함께 표시. 수정 후 바로 승인 가능
- D-05: 반려 시 모달 다이얼로그 — 텍스트 입력 + 확인 버튼. 사유 필수 입력
- D-06: 일괄 처리 — 목록 테이블에 체크박스 추가, 선택 시 상단에 "선택 {N}개: 승인 | 반려" 툴바 표시
- D-07: 일괄 반려도 사유 모달 표시 (선택된 모든 항목에 동일 사유 적용)

**감사 로그 & 이력**
- D-08: 감사 로그는 타임라인 형식 — 시간순으로 이력 표시: 시간 + 작업자 + 액션(수정/승인/반려) + 변경 요약
- D-09: 감사 로그 위치는 편집 페이지 하단 — 편집 폼 아래에 감사 로그 섹션
- D-10: audit_logs 테이블 신규 생성 (Alembic migration) — content_type, content_id, action, changes(JSON), reason, reviewer_id, created_at

**데이터 수정 API**
- D-11: PATCH 방식 — 변경된 필드만 전송. 1-3명 사용이라 동시 충돌 처리 불필요
- D-12: FastAPI 어드민 전용 엔드포인트 확장 — 기존 `/api/v1/admin/content/*` 라우터에 PATCH/POST 추가
- D-13: 승인/반려 전용 엔드포인트 — `POST /api/v1/admin/content/{type}/{id}/review` (action: approve/reject, reason)

### Claude's Discretion

- 편집 폼 필드 레이아웃 세부 배치 (그리드, 순서)
- React Hook Form + Zod 스키마 설계
- audit_logs 테이블 인덱스 전략
- 타임라인 컴포넌트 디자인 세부
- 일괄 처리 API 설계 (배치 엔드포인트 구조)
- 편집 페이지 로딩 스켈레톤

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| EDIT-01 | Reviewer가 단어/어휘 데이터를 개별 수정할 수 있다 (일본어, 읽기, 뜻, 예문) | Vocabulary model fields confirmed: word, reading, meaning_ko, example_sentence, example_reading, example_translation. PATCH endpoint pattern established. |
| EDIT-02 | Reviewer가 문법/문장 데이터를 개별 수정할 수 있다 | Grammar model fields confirmed: pattern, meaning_ko, explanation, example_sentences (JSON). |
| EDIT-03 | Reviewer가 퀴즈/문제 데이터를 개별 수정할 수 있다 (문제, 선택지, 정답, 해설) | ClozeQuestion fields: sentence, translation, correct_answer, options (JSON), explanation. SentenceArrangeQuestion: korean_sentence, japanese_sentence, tokens (JSON), explanation. |
| EDIT-04 | Reviewer가 회화 시나리오 데이터를 개별 수정할 수 있다 | ConversationScenario fields confirmed: title, title_ja, description, situation, your_role, ai_role, system_prompt, key_expressions. |
| REVW-01 | Reviewer가 개별 항목을 승인(approved) 또는 반려(rejected)할 수 있다 | review_status column exists on all 5 tables. POST /review endpoint pattern decided (D-13). |
| REVW-02 | Reviewer가 여러 항목을 선택하여 일괄 승인/반려할 수 있다 | ContentTable checkbox extension pattern. Batch endpoint discretion (D-06). |
| REVW-03 | 반려 시 사유를 입력할 수 있다 | Dialog component needed — NOT in current ui/. Must add. audit_logs.reason field captures it. |
| REVW-04 | 모든 수정/승인/반려에 대한 이력(audit log)이 기록된다 | audit_logs table does NOT exist yet — Alembic migration required (D-10). |
</phase_requirements>

---

## Summary

Phase 3 builds on the read-only content listing of Phase 2 by adding write capabilities: per-item editing, individual approve/reject, bulk approve/reject with reason dialog, and full audit log recording. All four content types (Vocabulary, Grammar, Quiz/ClozeQuestion+SentenceArrangeQuestion, ConversationScenario) already have a `review_status` column. None have `review_note` or `reviewer_id` — those live exclusively in the new `audit_logs` table.

The FastAPI backend needs: GET single-item endpoints (needed for detail page data fetching), PATCH update endpoints, POST review endpoints, a batch review endpoint, and audit log read endpoint. The frontend needs: four new dynamic route pages (`/vocabulary/[id]`, `/grammar/[id]`, `/quiz/[id]`, `/conversation/[id]`), a rejection reason Dialog component (not yet in `apps/admin/src/components/ui/`), checkbox additions to ContentTable, and a bulk action toolbar.

The critical new DDL artifact is the `audit_logs` table (Alembic migration). The existing `reviewstatus` PostgreSQL ENUM already covers `needs_review`, `approved`, `rejected` — no enum changes needed.

**Primary recommendation:** Build in this order — (1) Alembic migration for `audit_logs`, (2) FastAPI GET single + PATCH + POST review + batch endpoint, (3) shadcn Dialog component install, (4) detail page UI with React Hook Form, (5) bulk checkbox + toolbar in ContentTable.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| React Hook Form | ^7.71.2 | Edit form state management | Already installed in admin; project CLAUDE.md mandates it |
| Zod | ^3.25.76 | Schema validation for edit forms | Already installed; pairs with RHF via @hookform/resolvers |
| @hookform/resolvers | ^5.2.2 | Connects Zod to RHF | Already installed |
| TanStack Query | ^5.90.21 | useMutation for PATCH/review calls, useQuery for detail fetch | Established Phase 2 pattern |
| sonner | ^2.0.7 | Toast notifications on save/approve/reject | Already configured in root layout |
| shadcn/ui Dialog | radix-based | Rejection reason modal (D-05) | Not yet in ui/ — must add via shadcn CLI |
| shadcn/ui Textarea | radix-based | Reason text input inside Dialog | Not yet in ui/ — must add via shadcn CLI |
| shadcn/ui Checkbox | radix-based | Row selection for bulk actions (D-06) | Not yet in ui/ — must add via shadcn CLI |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| next-intl | ^3.x | i18n for new edit/review/audit keys | Add new keys to all 3 message files (ja/ko/en) |
| SQLAlchemy asyncio | ^2.0 | Async DB writes for PATCH + audit inserts | Existing pattern in admin_content.py |
| Alembic | ^1.14 | audit_logs DDL migration | DDL authority per api-plane.md |

### Installation

**shadcn components to add (admin app):**
```bash
cd apps/admin
npx shadcn@latest add dialog textarea checkbox
```

These three are not yet in `apps/admin/src/components/ui/` and are required for D-05 (rejection dialog), multi-line reason textarea, and D-06 (bulk checkbox). No new npm packages needed — shadcn generates from Radix which is already a dependency.

---

## Architecture Patterns

### Recommended Project Structure (new files)

```
apps/
├── api/
│   ├── alembic/versions/
│   │   └── {hash}_add_audit_logs_table.py    # NEW: audit_logs DDL
│   └── app/
│       ├── models/
│       │   └── admin.py                       # NEW: AuditLog model
│       ├── schemas/
│       │   └── admin_content.py               # EXTEND: add request + detail schemas
│       └── routers/
│           └── admin_content.py               # EXTEND: GET single, PATCH, POST review, batch
└── admin/
    └── src/
        ├── components/
        │   ├── ui/
        │   │   ├── dialog.tsx                 # NEW: shadcn Dialog
        │   │   ├── textarea.tsx               # NEW: shadcn Textarea
        │   │   └── checkbox.tsx               # NEW: shadcn Checkbox
        │   └── content/
        │       ├── content-table.tsx          # EXTEND: checkbox column + bulk toolbar
        │       └── reject-reason-dialog.tsx   # NEW: reusable rejection modal
        ├── hooks/
        │   ├── use-content-detail.ts          # NEW: single item fetch + mutations
        │   └── use-bulk-review.ts             # NEW: bulk approve/reject mutation
        ├── lib/api/
        │   └── admin-content.ts               # EXTEND: add fetch/patch/review functions
        └── app/(admin)/
            ├── vocabulary/[id]/page.tsx       # NEW
            ├── grammar/[id]/page.tsx          # NEW
            ├── quiz/[id]/page.tsx             # NEW
            └── conversation/[id]/page.tsx     # NEW
```

### Pattern 1: FastAPI PATCH endpoint (partial update)

Use Pydantic model with all fields `Optional` and `exclude_unset=True` for partial updates:

```python
# Source: Project convention in schemas/common.py (CamelModel pattern)
class VocabularyUpdateRequest(CamelModel):
    word: str | None = None
    reading: str | None = None
    meaning_ko: str | None = None
    example_sentence: str | None = None
    example_reading: str | None = None
    example_translation: str | None = None

@router.patch("/vocabulary/{item_id}", response_model=VocabularyDetailResponse)
async def patch_vocabulary(
    item_id: uuid.UUID,
    body: VocabularyUpdateRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    reviewer: Annotated[User, Depends(require_reviewer)],
) -> VocabularyDetailResponse:
    result = await db.execute(select(Vocabulary).where(Vocabulary.id == item_id))
    item = result.scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="Not found")

    changes: dict = {}
    for field, value in body.model_dump(exclude_unset=True).items():
        # field is snake_case here (populate_by_name=True)
        old_value = getattr(item, field)
        if old_value != value:
            changes[field] = {"before": old_value, "after": value}
            setattr(item, field, value)

    if changes:
        db.add(AuditLog(
            content_type="vocabulary",
            content_id=item_id,
            action="edit",
            changes=changes,
            reviewer_id=reviewer.id,
        ))
        await db.commit()
        await db.refresh(item)

    return VocabularyDetailResponse.model_validate(item)
```

**CRITICAL:** `body.model_dump(exclude_unset=True)` uses snake_case field names (not camelCase aliases) because `populate_by_name=True` in CamelModel.

### Pattern 2: Review endpoint (approve/reject)

```python
# Source: Project convention, D-13 decision
class ReviewRequest(CamelModel):
    action: Literal["approve", "reject"]
    reason: str | None = None  # required when action == "reject"

@router.post("/vocabulary/{item_id}/review", response_model=VocabularyDetailResponse)
async def review_vocabulary(
    item_id: uuid.UUID,
    body: ReviewRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    reviewer: Annotated[User, Depends(require_reviewer)],
) -> VocabularyDetailResponse:
    if body.action == "reject" and not body.reason:
        raise HTTPException(status_code=422, detail="reason required for reject")
    # ... update review_status, insert AuditLog, commit
```

### Pattern 3: Batch review endpoint

```python
# Batch endpoint — Claude's discretion on structure
class BatchReviewRequest(CamelModel):
    content_type: Literal["vocabulary", "grammar", "cloze", "sentence_arrange", "conversation"]
    ids: list[uuid.UUID]
    action: Literal["approve", "reject"]
    reason: str | None = None

@router.post("/batch-review", response_model=OkResponse)
async def batch_review(...):
    # Runs in one transaction; one AuditLog per item
```

### Pattern 4: React Hook Form + Zod for edit form

```typescript
// Source: CLAUDE.md mandated pattern; existing form.tsx in admin/src/components/ui/
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';

const vocabularySchema = z.object({
  word: z.string().min(1),
  reading: z.string().min(1),
  meaningKo: z.string().min(1),
  exampleSentence: z.string().optional(),
  exampleReading: z.string().optional(),
  exampleTranslation: z.string().optional(),
});

// D-03: mode: 'onSubmit' — validate on submit only
const form = useForm({ resolver: zodResolver(vocabularySchema), mode: 'onSubmit' });
```

### Pattern 5: TanStack Query mutation for PATCH

```typescript
// Source: Phase 2 established pattern (fetchAdminContent in admin-content.ts)
import { useMutation, useQueryClient } from '@tanstack/react-query';

export function useUpdateContent(type: ContentType, id: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (data: Record<string, unknown>) => patchAdminContent(type, id, data),
    onSuccess: () => {
      // D-02: stay on same page, show toast
      toast.success(t('saveSuccess'));
      void queryClient.invalidateQueries({ queryKey: ['admin-content-detail', type, id] });
      void queryClient.invalidateQueries({ queryKey: ['admin-content', type] });
    },
    onError: (err) => toast.error(err.message),
  });
}
```

### Pattern 6: Checkbox bulk selection in ContentTable

ContentTable currently takes `columns: Column<T>[]` and data rows. To add bulk selection without breaking existing call sites:

```typescript
// Extend ContentTableProps with optional bulk props
type ContentTableProps<T> = {
  // ... existing props ...
  selectable?: boolean;
  selectedIds?: Set<string>;
  onSelectionChange?: (ids: Set<string>) => void;
};
```

When `selectable` is false (default), existing pages work unchanged. Vocabulary/Grammar/Quiz/Conversation list pages opt in by passing `selectable={true}`.

### Pattern 7: audit_logs SQLAlchemy model

```python
# Source: Project model convention (UUID PK, DateTime timezone)
class AuditLog(Base):
    __tablename__ = "audit_logs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    content_type: Mapped[str] = mapped_column(Text, nullable=False)   # "vocabulary"|"grammar"|etc.
    content_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    action: Mapped[str] = mapped_column(Text, nullable=False)          # "edit"|"approve"|"reject"
    changes: Mapped[dict | None] = mapped_column(JSON, nullable=True)  # {field: {before, after}}
    reason: Mapped[str | None] = mapped_column(Text, nullable=True)    # rejection reason
    reviewer_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
```

### Anti-Patterns to Avoid

- **Using Prisma for DDL:** audit_logs table MUST be created via Alembic. `pnpm db:sync` can follow but DDL authority is Alembic-only per `api-plane.md`.
- **Next.js API route for content mutation:** All content mutations go through FastAPI per `api-plane.md`. Admin app calls `NEXT_PUBLIC_FASTAPI_URL` directly.
- **Real-time validation:** D-03 mandates submit-only validation. Do not set `mode: 'onChange'` or `mode: 'onBlur'` in React Hook Form.
- **Redirect after save:** D-02 mandates staying on the same page. Do not call `router.push()` after successful mutation.
- **Omitting CamelModel alias mapping:** `body.model_dump(exclude_unset=True)` returns snake_case keys (Python field names), not camelCase. Iterate over snake_case names when doing `setattr(item, field, value)`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Form state & validation | Custom form state with useState | React Hook Form + Zod | Already installed; handles touched state, error display, submit-only validation (D-03) |
| Rejection reason modal | Custom modal with CSS | shadcn Dialog + Textarea | Adds correctly (accessibility, focus trap) — install via `npx shadcn@latest add dialog textarea` |
| Row checkbox selection | Manual DOM checkbox handling | shadcn Checkbox + controlled Set state | shadcn Checkbox handles indeterminate state for header "select all" |
| Toast notifications | Alert div components | sonner (already configured in layout) | Zero setup needed, already in RootLayout |
| Partial update serialization | Manual field diff | Pydantic `model_dump(exclude_unset=True)` | Built-in Pydantic feature — returns only fields present in the request body |
| Audit log timeline UI | Custom timeline CSS | Tailwind flex+border-left vertical timeline | Standard pattern; no library needed for 1-3 user admin tool |

**Key insight:** All primitives (form, dialog, checkbox, toast) are either installed or one `npx shadcn` command away. Never build custom alternatives.

---

## Common Pitfalls

### Pitfall 1: review_note / reviewer_id columns don't exist on content models
**What goes wrong:** Planner assumes `review_note` or `reviewer_id` columns are already on `vocabularies` / `grammars` tables (common assumption). They are NOT. Only `review_status` exists.
**Why it happens:** The Phase 2 Alembic migration only added `review_status`. The STATE.md explicitly flags this: "Confirm review_status, review_note, reviewer_id columns do NOT already exist in schema before writing Alembic migration."
**How to avoid:** All rejection reasons and reviewer identity are stored in `audit_logs` only. The content tables are NOT modified for Phase 3 except via status update.
**Warning signs:** If plan references `ALTER TABLE vocabularies ADD COLUMN reviewer_id` — that's wrong.

### Pitfall 2: Dialog component missing from admin ui/
**What goes wrong:** Implementation tries to import `@/components/ui/dialog` and gets a module-not-found error.
**Why it happens:** Phase 2 only added button, card, input, label, form, table, status-badge. Dialog, Textarea, Checkbox were not added.
**How to avoid:** Wave 0 must run `npx shadcn@latest add dialog textarea checkbox` from `apps/admin/`.
**Warning signs:** Import errors on `@/components/ui/dialog`, `@/components/ui/textarea`, `@/components/ui/checkbox`.

### Pitfall 3: CamelModel alias causes wrong field names in model_dump
**What goes wrong:** `body.model_dump(exclude_unset=True)` returns `{'meaningKo': 'test'}` (camelCase alias), then `setattr(item, 'meaningKo', ...)` silently adds a non-model attribute rather than updating the DB column.
**Why it happens:** CamelModel uses `alias_generator=to_camel`. When iterating `model_dump()`, by default returns alias keys.
**How to avoid:** Use `body.model_dump(exclude_unset=True, by_alias=False)` — this returns snake_case Python field names that match SQLAlchemy column names.
**Warning signs:** DB updates silently fail (no error, no change in DB).

### Pitfall 4: Bulk action state leaks between list pages
**What goes wrong:** User selects 5 items on vocabulary page, navigates to grammar page — checkboxes still "selected" from stale state.
**Why it happens:** Checkbox selection state stored in React state at page component level; if moved to a parent or URL param, it persists.
**How to avoid:** Keep `selectedIds: Set<string>` as local state in each list page component. Reset on page navigation (Next.js page remounts handle this naturally).

### Pitfall 5: i18n type safety — missing ja.json keys cause compile errors
**What goes wrong:** Adding `useTranslations('edit')` without adding `edit` key to `messages/ja.json` causes TypeScript error (project uses `global.d.ts` type extraction from `ja.json`).
**Why it happens:** `apps/admin/src/global.d.ts` declares `IntlMessages` as `typeof messages` from `ja.json`. All keys must exist in ja.json first.
**How to avoid:** Add all new i18n keys to ja.json, ko.json, and en.json in the same commit before using them in components.

### Pitfall 6: GET single-item endpoint missing — detail pages have no data source
**What goes wrong:** Detail page `/vocabulary/[id]` has no API to fetch the full item data (Phase 2 only has list endpoints, not single-item GET).
**Why it happens:** Phase 2 was list-only. No `GET /api/v1/admin/content/vocabulary/{id}` exists.
**How to avoid:** Add GET single-item endpoints for all 4 content types as part of this phase. The detail page needs full field data for the edit form.

---

## Code Examples

### audit_logs Alembic Migration

```python
# Source: Established migration pattern from a1b2c3d4e5f6_add_review_status.py
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql
from alembic import op

def upgrade() -> None:
    op.create_table(
        "audit_logs",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("content_type", sa.Text, nullable=False),
        sa.Column("content_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("action", sa.Text, nullable=False),
        sa.Column("changes", postgresql.JSON, nullable=True),
        sa.Column("reason", sa.Text, nullable=True),
        sa.Column("reviewer_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
    )
    # Index for per-item history lookups (D-08 timeline query)
    op.create_index("idx_audit_logs_content", "audit_logs",
                    ["content_type", "content_id", "created_at"])
    # Index for reviewer activity queries
    op.create_index("idx_audit_logs_reviewer", "audit_logs", ["reviewer_id"])
```

### Frontend: patchAdminContent API function

```typescript
// Source: Extends existing pattern in apps/admin/src/lib/api/admin-content.ts
export async function patchAdminContent<T>(
  type: string,
  id: string,
  data: Record<string, unknown>
): Promise<T> {
  const headers = await getAuthHeaders();
  const url = `${API_URL}/api/v1/admin/content/${type}/${id}`;
  const res = await fetch(url, {
    method: 'PATCH',
    headers: { ...headers, 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json() as Promise<T>;
}

export async function reviewContent(
  type: string,
  id: string,
  action: 'approve' | 'reject',
  reason?: string
): Promise<void> {
  const headers = await getAuthHeaders();
  const url = `${API_URL}/api/v1/admin/content/${type}/${id}/review`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { ...headers, 'Content-Type': 'application/json' },
    body: JSON.stringify({ action, reason }),
  });
  if (!res.ok) throw new Error(`API error: ${res.status}`);
}

export async function batchReviewContent(
  contentType: string,
  ids: string[],
  action: 'approve' | 'reject',
  reason?: string
): Promise<void> {
  const headers = await getAuthHeaders();
  const url = `${API_URL}/api/v1/admin/content/batch-review`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { ...headers, 'Content-Type': 'application/json' },
    body: JSON.stringify({ contentType, ids, action, reason }),
  });
  if (!res.ok) throw new Error(`API error: ${res.status}`);
}
```

### Frontend: RejectReasonDialog component skeleton

```typescript
// Source: D-05 decision + shadcn Dialog pattern
'use client';
import { useState } from 'react';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from '@/components/ui/dialog';
import { Textarea } from '@/components/ui/textarea';
import { Button } from '@/components/ui/button';

type RejectReasonDialogProps = {
  open: boolean;
  onConfirm: (reason: string) => void;
  onCancel: () => void;
};

export function RejectReasonDialog({ open, onConfirm, onCancel }: RejectReasonDialogProps) {
  const [reason, setReason] = useState('');
  return (
    <Dialog open={open} onOpenChange={(o) => { if (!o) onCancel(); }}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>반려 사유 입력</DialogTitle>
        </DialogHeader>
        <Textarea value={reason} onChange={(e) => setReason(e.target.value)} rows={4} />
        <DialogFooter>
          <Button variant="outline" onClick={onCancel}>취소</Button>
          <Button disabled={!reason.trim()} onClick={() => { onConfirm(reason); setReason(''); }}>
            확인
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Full PUT (replace all fields) | PATCH with `exclude_unset=True` | Pydantic v2+ | Partial update — only send changed fields; cleaner audit log |
| Server-side form handling | React Hook Form + Zod client-side | React ecosystem matured | Type-safe form with inline error display; already installed |

---

## Open Questions

1. **Textarea component — install command target**
   - What we know: Textarea not in `apps/admin/src/components/ui/`; shadcn is the pattern
   - What's unclear: Whether to install to admin only or also packages/ui
   - Recommendation: Install to `apps/admin` only (admin-specific UI; packages/ui is for main app)

2. **Quiz type discrimination on detail page `/quiz/[id]`**
   - What we know: ClozeQuestion and SentenceArrangeQuestion are two different tables with different fields; the list view merges them under `quiz_type` field
   - What's unclear: How does the detail page know which table to query given only an `id`?
   - Recommendation: Add `quiz_type` query param to the detail page URL (e.g., `/quiz/[id]?type=cloze`) — this is already available from the list page's link render. The GET single-item endpoint for quiz must accept a `type` query param.

3. **audit_logs.reviewer_id — what happens if user is deleted**
   - What we know: Foreign key to `users.id`; scale is 1-3 users
   - What's unclear: Whether to use `ON DELETE SET NULL` or `ON DELETE RESTRICT`
   - Recommendation: `ON DELETE SET NULL` with `reviewer_id` nullable — preserves audit history even if reviewer account deleted. Change `reviewer_id: Mapped[uuid.UUID]` to `Mapped[uuid.UUID | None]`.

---

## Environment Availability

Step 2.6: This phase is backend + frontend code changes with no new external service dependencies.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|---------|
| Python/FastAPI | PATCH + review endpoints | ✓ | 3.12 / >=0.115 | — |
| Alembic | audit_logs migration | ✓ | >=1.14 | — |
| PostgreSQL | DB writes | ✓ | Supabase-managed | — |
| Node.js/pnpm | Admin app build | ✓ | 22 / 10.19.0 | — |
| shadcn CLI | Dialog/Textarea/Checkbox install | ✓ | npx shadcn@latest | — |

No blocking missing dependencies.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Vitest ^4.0.18 + Testing Library React |
| Config file | `apps/admin/vitest.config.ts` |
| Quick run command | `cd apps/admin && pnpm vitest run` |
| Full suite command | `cd apps/admin && pnpm vitest run --coverage` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| EDIT-01 | Vocabulary form submits changed fields only | unit | `cd apps/admin && pnpm vitest run src/__tests__/vocabulary-edit.test.tsx` | ❌ Wave 0 |
| EDIT-02 | Grammar form validation — pattern required | unit | `cd apps/admin && pnpm vitest run src/__tests__/grammar-edit.test.tsx` | ❌ Wave 0 |
| EDIT-03 | Quiz form handles JSON options field | unit | `cd apps/admin && pnpm vitest run src/__tests__/quiz-edit.test.tsx` | ❌ Wave 0 |
| EDIT-04 | Conversation form submits key_expressions array | unit | `cd apps/admin && pnpm vitest run src/__tests__/conversation-edit.test.tsx` | ❌ Wave 0 |
| REVW-01 | Approve button triggers review API call | unit | `cd apps/admin && pnpm vitest run src/__tests__/review-actions.test.tsx` | ❌ Wave 0 |
| REVW-02 | Checkbox selection enables bulk toolbar | unit | `cd apps/admin && pnpm vitest run src/__tests__/content-table-bulk.test.tsx` | ❌ Wave 0 |
| REVW-03 | RejectReasonDialog — confirm disabled when empty | unit | `cd apps/admin && pnpm vitest run src/__tests__/reject-dialog.test.tsx` | ❌ Wave 0 |
| REVW-04 | audit_logs migration upgrade/downgrade | manual | `cd apps/api && uv run alembic upgrade head && uv run alembic downgrade -1` | ❌ Wave 0 |

Python API tests for PATCH and review endpoints:
```bash
cd apps/api && uv run pytest tests/test_admin_content_edit.py -x
```

### Sampling Rate
- **Per task commit:** `cd apps/admin && pnpm vitest run`
- **Per wave merge:** `cd apps/admin && pnpm vitest run && cd ../api && uv run ruff check app/ tests/ && uv run pytest tests/ -x`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `apps/admin/src/__tests__/vocabulary-edit.test.tsx` — covers EDIT-01
- [ ] `apps/admin/src/__tests__/grammar-edit.test.tsx` — covers EDIT-02
- [ ] `apps/admin/src/__tests__/quiz-edit.test.tsx` — covers EDIT-03
- [ ] `apps/admin/src/__tests__/conversation-edit.test.tsx` — covers EDIT-04
- [ ] `apps/admin/src/__tests__/review-actions.test.tsx` — covers REVW-01
- [ ] `apps/admin/src/__tests__/content-table-bulk.test.tsx` — covers REVW-02
- [ ] `apps/admin/src/__tests__/reject-dialog.test.tsx` — covers REVW-03
- [ ] `apps/api/tests/test_admin_content_edit.py` — covers PATCH + review endpoints

---

## Project Constraints (from CLAUDE.md)

| Directive | Impact on Phase 3 |
|-----------|-------------------|
| DDL authority: Alembic ONLY (`api-plane.md`) | audit_logs table must be Alembic migration; no Prisma DDL |
| Domain logic in FastAPI, not Next.js API routes (`api-plane.md`) | All PATCH/review endpoints in FastAPI admin_content.py |
| TypeScript strict mode, no `any` | All new TS types must be explicit; no `any` in mutation payloads |
| `type` alias over `interface` for props | Edit form prop types use `type`, not `interface` |
| kebab-case filenames | `reject-reason-dialog.tsx`, `use-content-detail.ts` |
| React Hook Form + Zod (mandated in CLAUDE.md) | Edit forms use RHF+Zod, not plain useState |
| Submit-only validation (D-03, reaffirmed from Phase 1) | `mode: 'onSubmit'` in useForm calls |
| Codex cross-validation before commit | API contract changes (new PATCH/review schemas) require Codex review |
| ruff lint + format before API commits | `cd apps/api && uv run ruff check app/ tests/ && uv run ruff format --check app/ tests/` |
| pnpm lint before frontend commits | `pnpm lint` from monorepo root |
| No `any` type — add comment if unavoidable | JSON `changes` field typed as `Record<string, {before: unknown; after: unknown}>` |

---

## Sources

### Primary (HIGH confidence)
- Direct code inspection: `apps/api/app/routers/admin_content.py` — confirmed existing endpoints, require_reviewer pattern
- Direct code inspection: `apps/api/app/models/content.py` — confirmed all field names for Vocabulary, Grammar, ClozeQuestion, SentenceArrangeQuestion
- Direct code inspection: `apps/api/app/models/conversation.py` — confirmed ConversationScenario fields
- Direct code inspection: `apps/api/alembic/versions/a1b2c3d4e5f6_add_review_status.py` — confirmed review_status is the ONLY column added; review_note/reviewer_id do NOT exist on content tables
- Direct code inspection: `apps/api/app/schemas/common.py` — confirmed CamelModel alias behavior
- Direct code inspection: `apps/admin/src/components/ui/` — confirmed dialog.tsx, textarea.tsx, checkbox.tsx are MISSING
- Direct code inspection: `apps/admin/src/__tests__/` — confirmed test infrastructure exists with vitest + Testing Library
- Direct code inspection: `apps/admin/messages/ja.json` — confirmed no edit/review/audit log keys exist yet
- Direct code inspection: `apps/admin/package.json` — confirmed react-hook-form ^7.71.2, zod ^3.25.76, @hookform/resolvers ^5.2.2 installed

### Secondary (MEDIUM confidence)
- Pydantic v2 `model_dump(exclude_unset=True, by_alias=False)` behavior — verified from Pydantic v2 docs and CamelModel `populate_by_name=True` config
- shadcn Dialog/Textarea/Checkbox `npx shadcn@latest add` install pattern — consistent with how Phase 1/2 components were added

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all packages verified in package.json; shadcn install confirmed as standard pattern
- Architecture: HIGH — all existing patterns read directly from source code
- Pitfalls: HIGH — review_note/reviewer_id absence confirmed from Alembic migration source; Dialog absence confirmed from ui/ directory listing
- Missing components: HIGH — confirmed by direct `ls` of ui/ directory

**Research date:** 2026-03-26
**Valid until:** 2026-04-25 (stable stack; fast-moving items: Next.js 16.x patch releases)
