---
phase: 05-reviewer-productivity
plan: 01
subsystem: admin-api
tags: [review-queue, fastapi, typescript, admin-content]
dependency_graph:
  requires: []
  provides: [review-queue-endpoint, fetchReviewQueue-frontend-function]
  affects: [apps/api/app/routers/admin_content.py, apps/api/app/schemas/admin_content.py, apps/admin/src/lib/api/admin-content.ts]
tech_stack:
  added: []
  patterns: [CamelModel-schema, FastAPI-router-endpoint, TypeScript-fetch-wrapper]
key_files:
  created:
    - apps/api/tests/test_admin_review_queue.py
  modified:
    - apps/api/app/schemas/admin_content.py
    - apps/api/app/routers/admin_content.py
    - apps/admin/src/lib/api/admin-content.ts
decisions:
  - "GET /{content_type}/review-queue placed before /stats in router — prevents wildcard path conflict with FastAPI top-down matching"
  - "Quiz review-queue merges cloze + sentence_arrange in memory and sorts by created_at ASC — avoids complex UNION SQL"
  - "REVIEW_QUEUE_LIMIT=200 with limit+1 query trick detects cap without fetching all rows"
  - "Test stubs use skip pattern matching existing test_admin_content.py — DB fixture setup deferred to later wave"
metrics:
  duration: 2m
  completed_date: "2026-03-27"
  tasks_completed: 2
  files_changed: 4
---

# Phase 05 Plan 01: Review Queue API + Frontend Function Summary

## One-liner

FastAPI GET `/{content_type}/review-queue` endpoint returning `needs_review` item IDs sorted by `created_at ASC`, capped at 200 items, with `quiz_type` discriminator for merged quiz content; TypeScript `fetchReviewQueue()` wrapper matching CamelModel JSON output.

## What Was Built

### Task 1: FastAPI endpoint + schemas + pytest

Added to `apps/api/app/schemas/admin_content.py`:
- `ReviewQueueItem(CamelModel)` — `id: str`, `quiz_type: str | None`
- `ReviewQueueResponse(CamelModel)` — `ids: list[ReviewQueueItem]`, `total: int`, `capped: bool`

Added to `apps/api/app/routers/admin_content.py`:
- `REVIEW_QUEUE_LIMIT = 200` constant
- `GET /{content_type}/review-queue` endpoint: filters `needs_review` items, orders by `created_at ASC`, caps at 200
- `_get_quiz_review_queue()` helper: fetches cloze + sentence_arrange separately, merges in-memory, sorts by `created_at ASC`
- Category filter for `conversation` content type

Created `apps/api/tests/test_admin_review_queue.py` with 5 skipped test stubs matching project pattern.

### Task 2: Frontend API function + types

Added to `apps/admin/src/lib/api/admin-content.ts`:
- `ReviewQueueItem` type — `id: string`, `quizType?: string`
- `ReviewQueueResponse` type — `ids: ReviewQueueItem[]`, `total: number`, `capped: boolean`
- `fetchReviewQueue(contentType, params)` — follows same pattern as `fetchAdminContent` (getAuthHeaders, URL + searchParams, error handling)

## Decisions Made

1. **Route ordering**: `/{content_type}/review-queue` inserted before `/stats` to prevent FastAPI treating `stats` as a `content_type` param value (same pattern as Phase 4 TTS route ordering decision).
2. **Quiz merge strategy**: In-memory merge + sort preferred over SQL UNION for simplicity at 1-3 user scale.
3. **Cap detection**: Fetch `LIMIT + 1` rows, check length > LIMIT — avoids full table count query.
4. **Test stubs**: Follow existing `@pytest.mark.skip(reason="Wave 1 — DB fixture setup pending")` pattern from `test_admin_content.py`.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — `fetchReviewQueue` is a real API wrapper, `ReviewQueueItem`/`ReviewQueueResponse` are real types. Backend endpoint is real logic. Test stubs are intentional (matching existing project pattern, not blocking plan goal).

## Self-Check: PASSED
