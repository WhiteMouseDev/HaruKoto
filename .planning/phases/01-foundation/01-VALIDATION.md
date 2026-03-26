---
phase: 1
slug: foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-26
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Vitest 4.0.18 + @testing-library/react 16.3.2 |
| **Config file** | `apps/admin/vitest.config.ts` (Wave 0 — replicate from apps/web) |
| **Quick run command** | `cd apps/admin && pnpm test` |
| **Full suite command** | `cd apps/admin && pnpm test:coverage` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run `cd apps/admin && pnpm test`
- **After every plan wave:** Run `cd apps/admin && pnpm test:coverage`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 0 | — | infra | `cd apps/admin && pnpm test` | ❌ W0 | ⬜ pending |
| 01-02-01 | 02 | 1 | AUTH-01 | unit | `pnpm test -- login-form` | ❌ W0 | ⬜ pending |
| 01-02-02 | 02 | 1 | AUTH-02 | unit | `pnpm test -- auth` | ❌ W0 | ⬜ pending |
| 01-02-03 | 02 | 1 | AUTH-03 | unit | `pnpm test -- require-reviewer` | ❌ W0 | ⬜ pending |
| 01-03-01 | 03 | 1 | I18N-01 | unit | `pnpm test -- layout` | ❌ W0 | ⬜ pending |
| 01-03-02 | 03 | 1 | I18N-02 | unit | `pnpm test -- locale-route` | ❌ W0 | ⬜ pending |
| 01-03-03 | 03 | 1 | I18N-03 | unit | `pnpm test -- locale-route` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `apps/admin/vitest.config.ts` — copy from apps/web, update paths
- [ ] `apps/admin/src/__tests__/setup.ts` — `import '@testing-library/jest-dom/vitest'`
- [ ] `apps/admin/src/__tests__/auth.test.ts` — covers AUTH-01, AUTH-02, AUTH-03
- [ ] `apps/admin/src/__tests__/locale-route.test.ts` — covers I18N-02, I18N-03
- [ ] `apps/admin/src/__tests__/layout.test.tsx` — covers I18N-01

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Vercel 배포 URL에서 앱이 정상적으로 로드 | SC-5 | Requires live deployment | 1. Push to main 2. Check Vercel URL loads 3. Verify no console errors |
| 언어 전환 컨트롤 UI 동작 확인 | I18N-02 | Visual interaction test | 1. Open app 2. Click language switcher 3. Verify UI updates to selected language |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
