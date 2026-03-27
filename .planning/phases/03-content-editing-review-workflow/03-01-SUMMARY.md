---
phase: 03-content-editing-review-workflow
plan: 01
subsystem: api-backend, admin-ui
tags: [alembic, sqlalchemy, pydantic, shadcn, test-stubs]
dependency_graph:
  requires: []
  provides:
    - audit_logs Alembic migration (i9j0k1l2m3n4)
    - AuditLog SQLAlchemy model
    - Extended Pydantic schemas (detail/update/review/batch)
    - shadcn Dialog, Textarea, Checkbox components
    - 11 Python test stubs for Phase 3 backend
  affects:
    - apps/api/app/models/__init__.py
    - apps/api/app/schemas/admin_content.py
    - apps/admin/src/components/ui/
tech_stack:
  added:
    - "@radix-ui/react-dialog (via shadcn)"
    - "@radix-ui/react-checkbox (via shadcn)"
  patterns:
    - "AuditLog model: SQLAlchemy mapped_column + Index table_args pattern"
    - "Optional PATCH schemas: all fields None=None for partial updates (D-11)"
    - "Manual Alembic revision (autogenerate blocked by duplicate revision ID cycle)"
key_files:
  created:
    - apps/api/app/models/admin.py
    - apps/api/alembic/versions/i9j0k1l2m3n4_add_audit_logs_table.py
    - apps/api/tests/test_admin_content_edit.py
    - apps/admin/src/components/ui/dialog.tsx
    - apps/admin/src/components/ui/textarea.tsx
    - apps/admin/src/components/ui/checkbox.tsx
  modified:
    - apps/api/app/models/__init__.py
    - apps/api/app/schemas/admin_content.py
decisions:
  - "Manual Alembic migration used (autogenerate blocked by duplicate a1b2c3d4e5f6 revision ID causing cycle detection)"
  - "OkResponse defined in admin_content.py with count field (extends common.OkResponse pattern)"
metrics:
  duration: 3m
  completed_date: "2026-03-27"
  tasks: 2
  files: 8
---

# Phase 03 Plan 01: DDL Foundation, Schemas, and Test Scaffolds Summary

AuditLog table DDL + SQLAlchemy model, extended Pydantic schemas for detail/update/review/batch, shadcn Dialog/Textarea/Checkbox install, and 11 Python test stubs for all Phase 3 endpoints.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Alembic migration + AuditLog model + extended Pydantic schemas | 9259983 | admin.py, __init__.py, admin_content.py, migration |
| 2 | Install shadcn components + create Python test stubs | 7f62589 | dialog.tsx, textarea.tsx, checkbox.tsx, test_admin_content_edit.py |

## What Was Built

### AuditLog SQLAlchemy Model (`apps/api/app/models/admin.py`)

New model with all D-10 columns:
- `id` (UUID PK), `content_type` (Text), `content_id` (UUID), `action` (Text)
- `changes` (JSON nullable) — `{field: {before, after}}` structure
- `reason` (Text nullable) — for rejection reason
- `reviewer_id` (UUID FK → users.id), `created_at` (DateTime with timezone)
- Composite index `ix_audit_logs_content(content_type, content_id)` + `ix_audit_logs_created_at`

### Alembic Migration (`i9j0k1l2m3n4_add_audit_logs_table.py`)

Manual migration (autogenerate blocked — see deviations). Down_revision: `h8i9j0k1l2m3`.
Creates audit_logs table with all columns, both indexes, and full downgrade support.

### Extended Pydantic Schemas (`apps/api/app/schemas/admin_content.py`)

Added alongside existing list schemas (not replaced):
- **5 detail response schemas**: VocabularyDetailResponse, GrammarDetailResponse, ClozeQuestionDetailResponse, SentenceArrangeDetailResponse, ConversationDetailResponse
- **5 update request schemas**: VocabularyUpdateRequest, GrammarUpdateRequest, ClozeQuestionUpdateRequest, SentenceArrangeUpdateRequest, ConversationUpdateRequest (all fields Optional for PATCH)
- **Review schemas**: ReviewRequest (action + optional reason), BatchReviewRequest (content_type + ids + action + optional reason)
- **Audit schema**: AuditLogItem (id, action, changes, reason, reviewer_id, created_at)
- **OkResponse**: ok + count fields

### shadcn Components (`apps/admin/src/components/ui/`)

Installed via `npx shadcn@latest add dialog textarea checkbox --yes`:
- `dialog.tsx` — Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, etc.
- `textarea.tsx` — Textarea with cn() styling
- `checkbox.tsx` — Checkbox with @radix-ui/react-checkbox

### Python Test Stubs (`apps/api/tests/test_admin_content_edit.py`)

11 stub functions collected by pytest:
- EDIT-01..04: test_patch_{vocabulary,grammar,quiz,conversation}_updates_changed_fields_only
- REVW-01: test_approve_sets_review_status_to_approved
- REVW-03: test_reject_without_reason_returns_422
- REVW-04: test_audit_logs_table_exists, test_review_action_writes_audit_log, test_patch_action_writes_audit_log_with_changes
- REVW-02: test_batch_review_approves_multiple_items, test_batch_reject_without_reason_returns_422

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Manual Alembic migration instead of autogenerate**
- **Found during:** Task 1
- **Issue:** `alembic revision --autogenerate` failed with "Cycle is detected in revisions" due to duplicate revision ID `a1b2c3d4e5f6` (two migration files share this ID: `add_auth_user_trigger` and `add_review_status`)
- **Fix:** Wrote migration manually following existing migration file patterns. Migration revision `i9j0k1l2m3n4` chains from `h8i9j0k1l2m3` (latest head) and includes all required DDL.
- **Files modified:** `apps/api/alembic/versions/i9j0k1l2m3n4_add_audit_logs_table.py`
- **Commit:** 9259983

## Known Stubs

The 11 Python test functions in `apps/api/tests/test_admin_content_edit.py` are intentional stubs (pass body). They will be implemented in Plan 02 when the actual PATCH/review/batch endpoints are built. These stubs exist as scaffolding only and do not block Plan 01's goal (DDL foundation + schema scaffolding).

## Self-Check: PASSED

- `apps/api/app/models/admin.py` — FOUND
- `apps/api/alembic/versions/i9j0k1l2m3n4_add_audit_logs_table.py` — FOUND
- `apps/api/tests/test_admin_content_edit.py` — FOUND
- `apps/admin/src/components/ui/dialog.tsx` — FOUND
- `apps/admin/src/components/ui/textarea.tsx` — FOUND
- `apps/admin/src/components/ui/checkbox.tsx` — FOUND
- Commit 9259983 — FOUND
- Commit 7f62589 — FOUND
- ruff check: PASSED
- pytest --co -q: 11 tests collected
