---
phase: 02
slug: content-list-views
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-26
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework (Python)** | pytest + pytest-asyncio |
| **Framework (TS)** | Vitest ^4.0.18 |
| **Config file (Python)** | `apps/api/pyproject.toml` |
| **Config file (TS)** | `apps/admin/vitest.config.ts` |
| **Quick run command** | `cd apps/api && uv run ruff check app/ tests/` + `cd apps/admin && pnpm lint` |
| **Full suite command** | `cd apps/api && uv run pytest tests/test_admin_content.py -x` + `cd apps/admin && pnpm test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `cd apps/api && uv run ruff check app/ tests/` + `cd apps/admin && pnpm lint`
- **After every plan wave:** Run `cd apps/api && uv run pytest tests/test_admin_content.py -x` + `cd apps/admin && pnpm test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | LIST-01 | unit (Python) | `cd apps/api && uv run pytest tests/test_admin_content.py::test_vocabulary_list -x` | ❌ W0 | ⬜ pending |
| 02-01-02 | 01 | 1 | LIST-02 | unit (Python) | `cd apps/api && uv run pytest tests/test_admin_content.py::test_grammar_list -x` | ❌ W0 | ⬜ pending |
| 02-01-03 | 01 | 1 | LIST-03 | unit (Python) | `cd apps/api && uv run pytest tests/test_admin_content.py::test_quiz_list -x` | ❌ W0 | ⬜ pending |
| 02-01-04 | 01 | 1 | LIST-04 | unit (Python) | `cd apps/api && uv run pytest tests/test_admin_content.py::test_conversation_list -x` | ❌ W0 | ⬜ pending |
| 02-02-01 | 02 | 2 | LIST-05 | unit (Python) | `cd apps/api && uv run pytest tests/test_admin_content.py::test_filter_params -x` | ❌ W0 | ⬜ pending |
| 02-02-02 | 02 | 2 | LIST-06 | unit (Python) | `cd apps/api && uv run pytest tests/test_admin_content.py::test_search -x` | ❌ W0 | ⬜ pending |
| 02-03-01 | 03 | 2 | LIST-07 | unit (TS) | `cd apps/admin && pnpm test -- --reporter=verbose` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `apps/api/tests/test_admin_content.py` — stubs for LIST-01 through LIST-06; needs pytest fixtures for admin reviewer JWT token
- [ ] `apps/admin/src/__tests__/status-badge.test.tsx` — covers LIST-07 status badge rendering
- [ ] `apps/admin/src/components/ui/table.tsx` — install via `shadcn add table` (prerequisite for component tests)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Dashboard stats display | UX-02 | Visual layout + real DB counts | Open /dashboard, verify 4 cards show correct counts |
| Debounce search UX | LIST-06 | 300ms debounce timing is UX | Type in search, verify results update after typing stops |
| Status badge colors | LIST-07 | Color rendering verification | Check badges render yellow/green/red per status |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
