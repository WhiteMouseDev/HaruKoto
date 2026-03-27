---
phase: 03-content-editing-review-workflow
plan: 02
subsystem: api
tags: [fastapi, crud, audit-log, review-workflow, patch, batch-review]
dependency_graph:
  requires: [03-01]
  provides: [03-03]
  affects: [apps/api/app/routers/admin_content.py, apps/api/tests/test_admin_content_edit.py]
tech_stack:
  added: []
  patterns: [partial-update-exclude-unset, audit-log-on-mutation, dependency-override-testing]
key_files:
  created: []
  modified:
    - apps/api/app/routers/admin_content.py
    - apps/api/tests/test_admin_content_edit.py
decisions:
  - "by_alias=False in model_dump() ensures snake_case field names for setattr() on ORM models"
  - "AuditLog instances used in test mocks instead of MagicMock to ensure Pydantic model_validate works with from_attributes=True"
  - "Generic /{content_type}/{item_id}/audit-logs endpoint accepts content_type as path param for flexibility"
metrics:
  duration: 15m
  completed: 2026-03-27
  tasks_completed: 2
  files_modified: 2
---

# Phase 03 Plan 02: FastAPI Endpoints for Content Editing and Review Workflow Summary

**One-liner:** Complete PATCH/POST review/batch-review/GET detail/audit-log endpoints for all 5 content types with AuditLog on every mutation.

## What Was Built

All FastAPI backend endpoints required for the admin content editing and review workflow:

**GET detail endpoints (5):**
- `GET /vocabulary/{id}` -> VocabularyDetailResponse
- `GET /grammar/{id}` -> GrammarDetailResponse
- `GET /quiz/cloze/{id}` -> ClozeQuestionDetailResponse
- `GET /quiz/sentence-arrange/{id}` -> SentenceArrangeDetailResponse
- `GET /conversation/{id}` -> ConversationDetailResponse

**PATCH update endpoints (5):**
- `PATCH /vocabulary/{id}`, `PATCH /grammar/{id}`, `PATCH /quiz/cloze/{id}`, `PATCH /quiz/sentence-arrange/{id}`, `PATCH /conversation/{id}`
- All use `model_dump(exclude_unset=True, by_alias=False)` for partial updates
- Compare old vs new values, write `AuditLog(action="edit", changes={field: {before, after}})` if changed

**POST review endpoints (5):**
- `POST /vocabulary/{id}/review`, grammar, quiz/cloze, quiz/sentence-arrange, conversation
- action=approve -> ReviewStatus.APPROVED; action=reject requires reason or 422
- Write `AuditLog(action="approve"|"reject")` on every call

**POST batch review (1):**
- `POST /batch-review` with BatchReviewRequest(content_type, ids, action, reason)
- Processes all ids in a single transaction
- Returns OkResponse(ok=True, count=len(ids))

**GET audit logs (1):**
- `GET /{content_type}/{item_id}/audit-logs`
- Returns entries ordered by created_at DESC

**Tests (11):**
- EDIT-01~04: PATCH partial update for vocabulary, grammar, cloze, conversation
- REVW-01: approve sets review_status to approved
- REVW-03: reject without reason returns 422
- REVW-04: audit_logs table existence, review writes audit log, patch writes audit log with changes
- REVW-02: batch review approves multiple items, batch reject without reason 422

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Updated Vocabulary detail response to manually build response instead of model_validate**
- **Found during:** Task 1
- **Issue:** Vocabulary, Grammar, ConversationScenario models do not have `updated_at` column but VocabularyDetailResponse expects it as `datetime | None`. Using `model_validate` directly would fail since the column doesn't exist.
- **Fix:** Manually construct detail responses with `updated_at=None` for all content types
- **Files modified:** apps/api/app/routers/admin_content.py

**2. [Rule 1 - Bug] Used real AuditLog instances in test mocks instead of MagicMock**
- **Found during:** Task 2
- **Issue:** `AuditLogItem.model_validate(mock_log)` failed with `MagicMock` because Pydantic's `from_attributes=True` combined with CamelModel's alias_generator tried to access `reviewerId` attribute on the mock, which returned another MagicMock instead of a UUID.
- **Fix:** Replace `MagicMock()` mock logs with real `AuditLog(...)` instances in audit log test assertions
- **Files modified:** apps/api/tests/test_admin_content_edit.py
- **Commit:** 66e2f6b

## Decisions Made

- `by_alias=False` in `model_dump()` ensures snake_case field names match SQLAlchemy ORM attribute names for `setattr()`. Using `by_alias=True` would produce camelCase keys that don't match the ORM columns.
- Generic `/{content_type}/{item_id}/audit-logs` endpoint used as a single route rather than 5 separate endpoints — avoids URL routing conflicts with other `/{id}` patterns and provides flexibility for future content types.
- Test strategy: override both `require_reviewer` and `get_db` dependencies per test for full isolation, rather than using the shared `admin_client` fixture which doesn't allow per-test DB mock customization.

## Self-Check: PASSED

- apps/api/app/routers/admin_content.py — FOUND
- apps/api/tests/test_admin_content_edit.py — FOUND
- Commit 6ee478d (feat: endpoints) — FOUND
- Commit 66e2f6b (test: stubs) — FOUND
