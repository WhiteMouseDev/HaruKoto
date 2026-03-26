---
phase: 02-content-list-views
plan: 01
subsystem: api
tags: [fastapi, alembic, admin, content, review-status]
dependency_graph:
  requires: []
  provides:
    - ReviewStatus enum (app/enums.py)
    - Alembic migration a1b2c3d4e5f6 (review_status on 5 tables)
    - Admin content endpoints (GET /api/v1/admin/content/{vocabulary,grammar,quiz,conversation,stats})
    - require_reviewer JWT dependency
  affects:
    - apps/api/app/models/content.py
    - apps/api/app/models/conversation.py
    - apps/api/app/main.py
tech_stack:
  added:
    - ReviewStatus enum (needs_review/approved/rejected)
    - postgresql.ENUM reviewstatus PostgreSQL type
  patterns:
    - require_reviewer dependency: JWT app_metadata.reviewer claim check
    - PaginatedResponse[T] for all list endpoints
    - CamelModel for all Pydantic response schemas
key_files:
  created:
    - apps/api/app/schemas/admin_content.py
    - apps/api/app/routers/admin_content.py
    - apps/api/alembic/versions/a1b2c3d4e5f6_add_review_status.py
    - apps/api/tests/test_admin_content.py
  modified:
    - apps/api/app/enums.py
    - apps/api/app/models/enums.py
    - apps/api/app/models/content.py
    - apps/api/app/models/conversation.py
    - apps/api/app/main.py
decisions:
  - require_reviewer reads app_metadata.reviewer from JWT without DB role table — lightweight, matches pre-phase decision
  - ConversationScenario has no jlpt_level column; ConversationAdminItem.jlpt_level always returns None
  - Quiz endpoint merges ClozeQuestion + SentenceArrangeQuestion in-memory after two DB queries; acceptable at 1-3 user scale
  - quiz_type query param added beyond spec to enable filtering by cloze vs sentence_arrange
metrics:
  duration: ~10 minutes
  completed_date: 2026-03-26
  tasks_completed: 2
  files_created: 4
  files_modified: 5
---

# Phase 02 Plan 01: Admin Content Endpoints Summary

**One-liner:** FastAPI reviewer-gated admin content endpoints with ReviewStatus enum, Alembic migration for 5 tables, and Pydantic CamelModel schemas.

## What Was Built

### Task 1: ReviewStatus enum + model patches + Alembic migration

- Added `ReviewStatus(str, enum.Enum)` to `app/enums.py` with values `needs_review`, `approved`, `rejected`
- Re-exported `ReviewStatus` from `app/models/enums.py`
- Added `review_status: Mapped[ReviewStatus]` field to 4 models in `app/models/content.py` (Vocabulary, Grammar, ClozeQuestion, SentenceArrangeQuestion) and `ConversationScenario` in `app/models/conversation.py`
- Created Alembic migration `a1b2c3d4e5f6_add_review_status.py` with:
  - PostgreSQL ENUM type `reviewstatus` (create_type=True, checkfirst=True)
  - `review_status` column added to all 5 tables with `server_default="needs_review"` and NOT NULL
  - Index `idx_{table}_review_status` on each table
  - Full downgrade support

### Task 2: FastAPI admin content router + Pydantic schemas + test stubs

- Created `app/schemas/admin_content.py` with 6 Pydantic schemas (VocabularyAdminItem, GrammarAdminItem, QuizAdminItem, ConversationAdminItem, ContentStatsItem, ContentStatsResponse), all using `CamelModel`
- Created `app/routers/admin_content.py` at prefix `/api/v1/admin/content`:
  - `require_reviewer` dependency: decodes JWT via `_decode_token`, checks `app_metadata.reviewer == True`, fetches User from DB, raises 403 if not reviewer
  - 5 GET endpoints: `/vocabulary`, `/grammar`, `/quiz`, `/conversation`, `/stats`
  - All list endpoints accept `page`, `page_size`, `jlpt_level`, `review_status`, `search` query params
  - `/conversation` additionally accepts `category` param
  - `/quiz` accepts `quiz_type` param to filter cloze vs sentence_arrange
  - Search uses `ilike(f"%{search}%")` on key text columns
  - `/stats` counts review_status per content type using `func.count` + `group_by`
- Registered `admin_content_router` in `app/main.py`
- Created `tests/test_admin_content.py` with 8 stub test functions (marked skip, Wave 1 pending)

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| require_reviewer in router (not middleware) | Consistent with existing get_current_user pattern; no global middleware needed for selective routes |
| jlpt_level=None for ConversationAdminItem | ConversationScenario model has no jlpt_level column; correctly documented in schema comment |
| In-memory merge for quiz endpoint | Two DB queries (cloze + arrange) merged in Python; fine for 1-3 admin users |
| quiz_type filter param (not in spec) | Added as Rule 2 enhancement — makes quiz endpoint more useful without extra complexity |

## Deviations from Plan

### Auto-fixed Issues

None — plan executed as written.

### Auto-added functionality

**1. [Rule 2 - Enhancement] quiz_type filter param for /quiz endpoint**

- **Found during:** Task 2 implementation
- **Issue:** The plan specified the quiz endpoint merges both types but a filter would be useful
- **Fix:** Added `quiz_type: str | None = Query(default=None)` param accepting "cloze" or "sentence_arrange"
- **Files modified:** apps/api/app/routers/admin_content.py
- **Commit:** a5591e6

## Known Stubs

- `tests/test_admin_content.py`: All 8 test functions are stubs marked with `@pytest.mark.skip`. Tests stub out the API layer but do not exercise the DB. These are intentional — per VALIDATION.md Wave 0 requirement. Full tests are planned for Wave 1.

## Self-Check: PASSED

Verified files exist:

- [x] apps/api/app/enums.py — contains `class ReviewStatus`
- [x] apps/api/app/models/enums.py — re-exports `ReviewStatus`
- [x] apps/api/app/models/content.py — has 4 `review_status` fields
- [x] apps/api/app/models/conversation.py — has 1 `review_status` field
- [x] apps/api/alembic/versions/a1b2c3d4e5f6_add_review_status.py — migration with down_revision = "0e6f6c2a3136"
- [x] apps/api/app/schemas/admin_content.py — has VocabularyAdminItem and ContentStatsResponse
- [x] apps/api/app/routers/admin_content.py — has 5 @router.get endpoints
- [x] apps/api/app/main.py — includes admin_content_router
- [x] apps/api/tests/test_admin_content.py — has 8 def test_ functions

Verified commits exist:

- [x] a5c1c38: feat(02-01): add ReviewStatus enum, model patches, and Alembic migration
- [x] a5591e6: feat(02-01): add admin content router, Pydantic schemas, and test stubs
