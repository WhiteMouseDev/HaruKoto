---
phase: 05-reviewer-productivity
plan: "03"
subsystem: admin-frontend
tags: [review-queue, navigation, auto-advance, ux]
dependency_graph:
  requires: ["05-01", "05-02"]
  provides: ["review-queue-ui", "auto-advance"]
  affects: ["admin-frontend"]
tech_stack:
  added: []
  patterns:
    - "useReviewQueue hook reads queue/qi URL params for stateless queue traversal"
    - "ReviewStartButton fetches queue and navigates via URL params"
    - "QueueNavigationBar provides Prev/Next navigation with position counter"
    - "Auto-advance via setTimeout(goNext, 800) after approve/reject mutation"
key_files:
  created:
    - apps/admin/src/hooks/use-review-queue.ts
    - apps/admin/src/components/content/queue-navigation-bar.tsx
    - apps/admin/src/components/content/review-start-button.tsx
    - apps/admin/src/__tests__/use-review-queue.test.ts
    - apps/admin/src/__tests__/review-header.test.tsx
  modified:
    - apps/admin/src/app/(admin)/vocabulary/page.tsx
    - apps/admin/src/app/(admin)/grammar/page.tsx
    - apps/admin/src/app/(admin)/quiz/page.tsx
    - apps/admin/src/app/(admin)/conversation/page.tsx
    - apps/admin/src/app/(admin)/vocabulary/[id]/page.tsx
    - apps/admin/src/app/(admin)/grammar/[id]/page.tsx
    - apps/admin/src/app/(admin)/quiz/[id]/page.tsx
    - apps/admin/src/app/(admin)/conversation/[id]/page.tsx
decisions:
  - "Queue state stored in URL params (queue=id1,id2,id3&qi=0) — no global state needed, survives page reload"
  - "Quiz items encoded as quizType:id in queue param — preserves type discriminator through navigation"
  - "Auto-advance uses setTimeout 800ms — gives reviewer time to read success toast before navigation"
  - "Last item in queue calls exitQueue not goNext — returns to list page with queueComplete toast"
metrics:
  duration: "4m"
  completed: "2026-03-27"
  tasks: 2
  files: 13
---

# Phase 05 Plan 03: Review Queue Frontend Summary

## One-liner

Complete review queue flow: "レビュー開始" button fetches needs_review IDs and navigates sequentially across all 4 content types with auto-advance on approve/reject.

## What Was Built

### useReviewQueue hook (`apps/admin/src/hooks/use-review-queue.ts`)
- Reads `queue` and `qi` URL search params to determine current position in queue
- Provides `goNext`, `goPrev`, `exitQueue`, `isInQueue`, `position`, `total`, `hasPrev`, `hasNext`, `isLastItem`
- Quiz URL encoding: `cloze:uuid` and `sentence_arrange:uuid` format preserves type discriminator
- Stateless design: queue survives page reload via URL params

### QueueNavigationBar (`apps/admin/src/components/content/queue-navigation-bar.tsx`)
- Full-width flex row with Prev/Next ghost buttons and position counter (e.g., "2 / 5")
- Far-right exit link returns to list page
- Uses i18n keys from Plan 02: `review.prevItem`, `review.nextItem`, `review.queuePosition`, `review.exitQueue`

### ReviewStartButton (`apps/admin/src/components/content/review-start-button.tsx`)
- Calls `fetchReviewQueue(contentType, filters)` on click, reads current filter params from URL
- Shows toast if queue is empty (`review.startQueueEmpty`) or capped (`review.queueCapped`)
- Navigates to first item: `/{contentType}/{firstId}?queue=...&qi=0`
- Quiz: sets `type=cloze` or `type=sentence_arrange` for first item

### 4 list pages updated
- All 4 pages (vocabulary, grammar, quiz, conversation) have `<ReviewStartButton>` in header
- Wrapped in `<Suspense>` because `ReviewStartButton` uses `useSearchParams()`

### 4 edit pages updated
- All 4 edit pages (vocabulary, grammar, quiz, conversation) use `useReviewQueue`
- `QueueNavigationBar` renders conditionally when `isInQueue` is true
- `handleApprove` and `handleRejectConfirm` auto-advance 800ms after toast
- Last item: `queueComplete` toast + `exitQueue` instead of `autoAdvance` + `goNext`

## Tests

10 tests pass across 2 test files:
- `use-review-queue.test.ts`: 5 tests — isInQueue, hasPrev, hasNext, isLastItem, function shapes
- `review-header.test.tsx`: 5 tests — renders buttons, onApprove callback, onReject callback, disabled state, StatusBadge render

## Deviations from Plan

None — plan executed exactly as written.

## Checkpoint: Task 3 — Human Verification Required

Task 3 is `type="checkpoint:human-verify"` requiring manual end-to-end verification of the complete Phase 5 flow.

## Self-Check: PASSED

Files created:
- [x] apps/admin/src/hooks/use-review-queue.ts — FOUND
- [x] apps/admin/src/components/content/queue-navigation-bar.tsx — FOUND
- [x] apps/admin/src/components/content/review-start-button.tsx — FOUND
- [x] apps/admin/src/__tests__/use-review-queue.test.ts — FOUND
- [x] apps/admin/src/__tests__/review-header.test.tsx — FOUND

Commits:
- [x] d7df2e2 — Task 1 (hook + components + tests)
- [x] 280eeac — Task 2 (wire into 8 pages)

TypeScript: exits 0
Lint: exits 0
Tests: 10/10 passed
