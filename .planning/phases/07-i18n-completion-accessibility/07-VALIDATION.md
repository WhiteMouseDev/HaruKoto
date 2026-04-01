---
phase: 7
slug: i18n-completion-accessibility
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-01
---

# Phase 7 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Vitest 4.x |
| **Config file** | `apps/admin/vitest.config.ts` |
| **Quick run command** | `cd apps/admin && pnpm vitest run src/__tests__` |
| **Full suite command** | `cd apps/admin && pnpm vitest run` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `cd apps/admin && pnpm vitest run src/__tests__`
- **After every plan wave:** Run `cd apps/admin && pnpm vitest run`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 07-01-01 | 01 | 1 | I18N-04 | script | `cd apps/admin && pnpm vitest run src/__tests__/hardcoded-strings.test.ts` | ❌ W0 | ⬜ pending |
| 07-01-02 | 01 | 1 | I18N-05 | unit | `cd apps/admin && pnpm vitest run src/__tests__/locale-key-parity.test.ts` | ❌ W0 | ⬜ pending |
| 07-01-03 | 01 | 1 | A11Y-04 | unit | `cd apps/admin && pnpm vitest run src/__tests__/filter-bar.test.tsx` | ❌ W0 | ⬜ pending |
| 07-02-01 | 02 | 1 | A11Y-01 | unit | `cd apps/admin && pnpm vitest run src/__tests__/sidebar-nav-item.test.tsx` | ✅ extend | ⬜ pending |
| 07-02-02 | 02 | 1 | A11Y-02 | unit | `cd apps/admin && pnpm vitest run src/__tests__/layout.test.tsx` | ✅ extend | ⬜ pending |
| 07-02-03 | 02 | 1 | A11Y-03 | unit | `cd apps/admin && pnpm vitest run src/__tests__/layout.test.tsx` | ✅ extend | ⬜ pending |
| 07-03-01 | 03 | 2 | I18N-04 | unit | `cd apps/admin && pnpm vitest run src/__tests__/hardcoded-strings.test.ts` | ❌ W0 | ⬜ pending |
| 07-03-02 | 03 | 2 | I18N-05 | unit | `cd apps/admin && pnpm vitest run src/__tests__/locale-key-parity.test.ts` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `src/__tests__/hardcoded-strings.test.ts` — stubs for I18N-04 (reads .tsx files, asserts no CJK regex match outside allowlist)
- [ ] `src/__tests__/locale-key-parity.test.ts` — stubs for I18N-05 (imports all three locale JSONs, deep-compares key structure)
- [ ] `src/__tests__/filter-bar.test.tsx` — stubs for A11Y-04 (renders FilterBar, asserts label[for] linked to search input)

Existing test files that need extension:
- `src/__tests__/sidebar-nav-item.test.tsx` — add test for `aria-current="page"` on active item (A11Y-01)
- `src/__tests__/layout.test.tsx` — add tests for skip link presence and aria-label on aside/main (A11Y-02, A11Y-03)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Skip link visible on Tab focus | A11Y-02 | Visual focus state requires browser rendering | 1. Open admin in browser 2. Press Tab 3. Verify skip link appears at top-left 4. Press Enter 5. Verify focus moves to main content |
| Locale switch updates all visible text | I18N-04 | Full visual regression requires browser | 1. Navigate to each admin page 2. Switch locale via LocaleSwitcher 3. Verify no hardcoded CJK strings remain |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
