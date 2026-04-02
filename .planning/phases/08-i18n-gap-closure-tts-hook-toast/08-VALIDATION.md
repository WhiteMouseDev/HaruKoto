---
phase: 8
slug: i18n-gap-closure-tts-hook-toast
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-02
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Vitest ^4.0.18 |
| **Config file** | `apps/admin/vitest.config.ts` |
| **Quick run command** | `cd apps/admin && pnpm vitest run src/__tests__/hardcoded-strings.test.ts` |
| **Full suite command** | `cd apps/admin && pnpm vitest run` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `cd apps/admin && pnpm vitest run src/__tests__/hardcoded-strings.test.ts`
- **After every plan wave:** Run `cd apps/admin && pnpm vitest run`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 08-01-01 | 01 | 1 | I18N-05 | unit (code review) | `grep -c 'useTranslations' apps/admin/src/hooks/use-tts-player.ts` | Yes (modify) | ⬜ pending |
| 08-01-02 | 01 | 1 | I18N-04 | unit (file scan) | `cd apps/admin && pnpm vitest run src/__tests__/hardcoded-strings.test.ts` | Yes (modify) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. `hardcoded-strings.test.ts` exists and will be modified in-place.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Toast displays in correct locale | I18N-05 | Visual locale rendering | Switch locale in admin UI, trigger TTS regenerate, verify toast text matches locale |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
