---
phase: 03-content-editing-review-workflow
plan: 03
subsystem: admin-frontend
tags: [frontend, edit-pages, review-workflow, bulk-actions, audit-log, react-hook-form, zod]
dependency_graph:
  requires:
    - 03-01 (AuditLog model, migrations, shadcn components)
    - 03-02 (FastAPI endpoints: GET detail, PATCH, POST review, batch-review, audit-logs)
  provides:
    - vocabulary/[id] edit page
    - grammar/[id] edit page
    - quiz/[id] edit page
    - conversation/[id] edit page
    - ContentTable with checkboxes and bulk toolbar
    - RejectReasonDialog
    - ReviewHeader
    - AuditTimeline
  affects:
    - All 4 content list pages (vocabulary, grammar, quiz, conversation) - selectable=true
tech_stack:
  added: []
  patterns:
    - React Hook Form + Zod (validate on submit, dirty fields only on PATCH)
    - TanStack Query useMutation with onSuccess/onError callbacks
    - Next.js useParams + useSearchParams for dynamic routes
    - Vertical timeline UI with relative time formatting
    - Checkbox indeterminate state for select-all
key_files:
  created:
    - apps/admin/src/lib/api/admin-content.ts (extended)
    - apps/admin/src/hooks/use-content-detail.ts
    - apps/admin/src/hooks/use-bulk-review.ts
    - apps/admin/src/components/content/reject-reason-dialog.tsx
    - apps/admin/src/components/content/review-header.tsx
    - apps/admin/src/components/content/audit-timeline.tsx
    - apps/admin/src/app/(admin)/vocabulary/[id]/page.tsx
    - apps/admin/src/app/(admin)/grammar/[id]/page.tsx
    - apps/admin/src/app/(admin)/quiz/[id]/page.tsx
    - apps/admin/src/app/(admin)/conversation/[id]/page.tsx
  modified:
    - apps/admin/src/components/content/content-table.tsx
    - apps/admin/src/app/(admin)/vocabulary/page.tsx
    - apps/admin/src/app/(admin)/grammar/page.tsx
    - apps/admin/src/app/(admin)/quiz/page.tsx
    - apps/admin/src/app/(admin)/conversation/page.tsx
    - apps/admin/messages/ja.json
    - apps/admin/messages/ko.json
    - apps/admin/messages/en.json
decisions:
  - Quiz edit page uses searchParams type param (cloze vs sentence_arrange) to branch form and API content type path (quiz/cloze or quiz/sentence-arrange)
  - JSON array fields (exampleSentences, options, tokens, keyExpressions) edited as raw text and parsed/serialized at save boundary
  - ContentTable checkbox state is local (useState) — resets on page navigation; no global selection state needed at 1-3 user scale
  - Dirty fields only sent to PATCH — avoids overwriting unchanged fields
metrics:
  duration: 6m
  completed_date: "2026-03-27"
  tasks: 2
  files_changed: 18
---

# Phase 3 Plan 3: Frontend Edit Pages + Review Workflow Summary

**One-liner:** 4 content edit pages with React Hook Form + Zod, approve/reject review header with rejection dialog, audit log timeline, and bulk checkbox toolbar in content table.

## What Was Built

### Task 1: API client extensions + hooks + shared components

Extended `admin-content.ts` with 5 new API functions:
- `fetchAdminContentDetail` — GET single content item
- `patchAdminContent` — PATCH content fields (dirty fields only)
- `reviewContent` — POST approve/reject action
- `batchReviewContent` — POST batch review for multiple IDs
- `fetchAuditLogs` — GET audit log entries

Created `useContentDetail` hook exposing `detailQuery`, `patchMutation`, `reviewMutation`, `auditQuery` with automatic cache invalidation on success.

Created `useBulkReview` hook wrapping `batchReviewContent` with query invalidation.

Created 3 shared UI components:
- `RejectReasonDialog` — shadcn Dialog with required textarea, clears on close
- `ReviewHeader` — StatusBadge + approve (green) + reject (destructive) buttons, disabled during loading
- `AuditTimeline` — vertical timeline with relative time, action color badges (blue=modified, green=approved, red=rejected), changes summary, skeleton loading state

Added `edit`, `review`, `audit` i18n key blocks to ja/ko/en message files.

### Task 2: 4 edit pages + content-table checkbox/bulk toolbar

Created 4 edit pages at `/vocabulary/[id]`, `/grammar/[id]`, `/quiz/[id]`, `/conversation/[id]`:
- Each uses `useContentDetail` for data and mutations
- React Hook Form with `zodResolver` — validation on submit only (per D-03)
- Only dirty fields sent to PATCH
- Save stays on current page with `toast.success`
- Approve button calls `reviewMutation` directly
- Reject button opens `RejectReasonDialog`, on confirm calls `reviewMutation`
- `AuditTimeline` rendered at bottom of each page

Quiz page branches between cloze and sentence_arrange forms based on `?type=` search param.

Extended `ContentTable` with:
- `selectable` boolean prop (default false)
- `contentType` string prop for bulk review routing
- Checkbox column in header (select-all with indeterminate state) and each row
- Sticky bulk action toolbar when selection > 0: shows count, approve and reject buttons
- Bulk reject opens `RejectReasonDialog` inline

Updated all 4 list pages (vocabulary, grammar, quiz, conversation) to pass `selectable` and `contentType`.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. All data flows are wired to live API endpoints.

## Self-Check: PASSED

- `/vocabulary/[id]/page.tsx` exists: FOUND
- `/grammar/[id]/page.tsx` exists: FOUND
- `/quiz/[id]/page.tsx` exists: FOUND
- `/conversation/[id]/page.tsx` exists: FOUND
- `reject-reason-dialog.tsx` exists: FOUND
- `audit-timeline.tsx` exists: FOUND
- `review-header.tsx` exists: FOUND
- `use-content-detail.ts` exists: FOUND
- `use-bulk-review.ts` exists: FOUND
- Commit de044d3: FOUND
- Commit 0849b94: FOUND
- `pnpm build` succeeds with all 4 edit routes: PASSED
