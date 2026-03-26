---
phase: 03
slug: content-editing-review-workflow
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-26
---

# Phase 03 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework (TS)** | Vitest ^4.0.18 + Testing Library React ^16.3.2 |
| **Framework (Python)** | pytest >=8.3 + pytest-asyncio >=0.25 |
| **Config file (TS)** | `apps/admin/vitest.config.ts` |
| **Config file (Python)** | `apps/api/pytest.ini` (or `pyproject.toml`) |
| **Quick run command** | `cd apps/admin && pnpm vitest run` |
| **Full suite command** | `cd apps/admin && pnpm vitest run && cd ../api && uv run ruff check app/ tests/ && uv run pytest tests/ -x` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `cd apps/admin && pnpm vitest run`
- **After every plan wave:** Run `cd apps/admin && pnpm vitest run && cd ../api && uv run ruff check app/ tests/ && uv run pytest tests/ -x`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | REVW-04 | integration | `cd apps/api && uv run pytest tests/test_admin_content_edit.py::test_audit_logs_table_exists -x` | ❌ W0 | ⬜ pending |
| 03-01-02 | 01 | 1 | REVW-04 | manual | `cd apps/api && uv run alembic upgrade head && uv run alembic downgrade -1` | — | ⬜ pending |
| 03-02-01 | 02 | 1 | EDIT-01 | integration | `cd apps/api && uv run pytest tests/test_admin_content_edit.py::test_patch_vocabulary_updates_changed_fields_only -x` | ❌ W0 | ⬜ pending |
| 03-02-02 | 02 | 1 | EDIT-02 | integration | `cd apps/api && uv run pytest tests/test_admin_content_edit.py::test_patch_grammar_updates_changed_fields_only -x` | ❌ W0 | ⬜ pending |
| 03-02-03 | 02 | 1 | EDIT-03 | integration | `cd apps/api && uv run pytest tests/test_admin_content_edit.py::test_patch_quiz_updates_changed_fields_only -x` | ❌ W0 | ⬜ pending |
| 03-02-04 | 02 | 1 | EDIT-04 | integration | `cd apps/api && uv run pytest tests/test_admin_content_edit.py::test_patch_conversation_updates_changed_fields_only -x` | ❌ W0 | ⬜ pending |
| 03-03-01 | 03 | 1 | REVW-01 | integration | `cd apps/api && uv run pytest tests/test_admin_content_edit.py::test_approve_sets_review_status_to_approved -x` | ❌ W0 | ⬜ pending |
| 03-03-02 | 03 | 1 | REVW-03 | integration | `cd apps/api && uv run pytest tests/test_admin_content_edit.py::test_reject_without_reason_returns_422 -x` | ❌ W0 | ⬜ pending |
| 03-03-03 | 03 | 1 | REVW-04 | integration | `cd apps/api && uv run pytest tests/test_admin_content_edit.py::test_review_action_writes_audit_log -x` | ❌ W0 | ⬜ pending |
| 03-03-04 | 03 | 1 | REVW-04 | integration | `cd apps/api && uv run pytest tests/test_admin_content_edit.py::test_patch_action_writes_audit_log_with_changes -x` | ❌ W0 | ⬜ pending |
| 03-04-01 | 04 | 1 | REVW-02 | integration | `cd apps/api && uv run pytest tests/test_admin_content_edit.py::test_batch_review_approves_multiple_items -x` | ❌ W0 | ⬜ pending |
| 03-04-02 | 04 | 1 | REVW-02 | integration | `cd apps/api && uv run pytest tests/test_admin_content_edit.py::test_batch_reject_without_reason_returns_422 -x` | ❌ W0 | ⬜ pending |
| 03-05-01 | 05 | 2 | EDIT-01 | unit | `cd apps/admin && pnpm vitest run src/__tests__/vocabulary-edit.test.tsx` | ❌ W0 | ⬜ pending |
| 03-05-02 | 05 | 2 | EDIT-02 | unit | `cd apps/admin && pnpm vitest run src/__tests__/grammar-edit.test.tsx` | ❌ W0 | ⬜ pending |
| 03-05-03 | 05 | 2 | EDIT-03 | unit | `cd apps/admin && pnpm vitest run src/__tests__/quiz-edit.test.tsx` | ❌ W0 | ⬜ pending |
| 03-05-04 | 05 | 2 | EDIT-04 | unit | `cd apps/admin && pnpm vitest run src/__tests__/conversation-edit.test.tsx` | ❌ W0 | ⬜ pending |
| 03-06-01 | 06 | 2 | REVW-01 | unit | `cd apps/admin && pnpm vitest run src/__tests__/review-actions.test.tsx` | ❌ W0 | ⬜ pending |
| 03-06-02 | 06 | 2 | REVW-03 | unit | `cd apps/admin && pnpm vitest run src/__tests__/reject-dialog.test.tsx` | ❌ W0 | ⬜ pending |
| 03-07-01 | 07 | 2 | REVW-02 | unit | `cd apps/admin && pnpm vitest run src/__tests__/content-table-bulk.test.tsx` | ❌ W0 | ⬜ pending |
| 03-07-02 | 07 | 2 | REVW-04 | unit | `cd apps/admin && pnpm vitest run src/__tests__/audit-log-timeline.test.tsx` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

### Python test stubs (Wave 1 backend)

- [ ] `apps/api/tests/test_admin_content_edit.py` — stubs for EDIT-01~04, REVW-01~04 (PATCH + review + audit log + batch endpoints)
- [ ] `apps/api/tests/conftest.py` — shared fixtures: async DB session, test reviewer user, sample vocabulary/grammar/quiz/conversation rows

### TypeScript test stubs (Wave 2 frontend)

- [ ] `apps/admin/src/__tests__/vocabulary-edit.test.tsx` — covers EDIT-01
- [ ] `apps/admin/src/__tests__/grammar-edit.test.tsx` — covers EDIT-02
- [ ] `apps/admin/src/__tests__/quiz-edit.test.tsx` — covers EDIT-03
- [ ] `apps/admin/src/__tests__/conversation-edit.test.tsx` — covers EDIT-04
- [ ] `apps/admin/src/__tests__/review-actions.test.tsx` — covers REVW-01
- [ ] `apps/admin/src/__tests__/reject-dialog.test.tsx` — covers REVW-03
- [ ] `apps/admin/src/__tests__/content-table-bulk.test.tsx` — covers REVW-02
- [ ] `apps/admin/src/__tests__/audit-log-timeline.test.tsx` — covers REVW-04 (frontend timeline display)

### shadcn component install (prerequisite for frontend tests)

- [ ] `cd apps/admin && npx shadcn@latest add dialog textarea checkbox` — required for Dialog, Textarea, Checkbox imports in test files

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Alembic migration upgrade/downgrade roundtrip | REVW-04 | Requires live DB; no in-process migration runner available in pytest | `cd apps/api && uv run alembic upgrade head` → verify `audit_logs` table exists in DB → `uv run alembic downgrade -1` → verify table dropped |
| Audit log timeline renders in chronological order in the UI | REVW-04 | Visual timeline layout cannot be asserted reliably in unit tests | Open `/vocabulary/[id]` detail page, perform edit + approve, verify timeline section shows both events in time order |
| Bulk toolbar appears on checkbox selection, disappears on deselect | REVW-02 | Toolbar visibility driven by React state; interaction test requires browser-level render | On any list page, check two rows → verify "선택 2개: 승인 \| 반려" toolbar appears → uncheck all → verify toolbar hidden |
| Bulk select state resets on list page navigation | REVW-02 | Cross-page navigation requires router integration not available in vitest unit tests | Select items on vocabulary list → navigate to grammar list → verify no items selected |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
