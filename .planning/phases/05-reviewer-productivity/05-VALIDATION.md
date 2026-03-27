---
phase: 5
slug: reviewer-productivity
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-27
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | vitest + Testing Library (web) / pytest (API) |
| **Config file** | `apps/admin/vitest.config.ts` (if exists) / `apps/api/pyproject.toml` |
| **Quick run command** | `cd apps/admin && pnpm vitest run --reporter=verbose` |
| **Full suite command** | `cd apps/api && uv run pytest tests/ -x && cd ../../apps/admin && pnpm vitest run` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `cd apps/admin && pnpm vitest run --reporter=verbose`
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | UX-01 | integration | TBD | TBD | ⬜ pending |
| TBD | TBD | TBD | UX-02 | integration | TBD | TBD | ⬜ pending |
| TBD | TBD | TBD | UX-03 | integration | TBD | TBD | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| 리뷰 큐 다음/이전 네비게이션 UX | UX-01 | Visual flow between pages | Navigate review queue, verify prev/next buttons work |
| 대시보드 프로그레스 바 시각적 표시 | UX-02 | Visual rendering | Check progress bars show correct percentages |
| 사이드바 뱃지 알림 표시 | UX-03 | Visual indicator | Verify badge counts match needs_review items |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
