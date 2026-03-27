---
phase: 04
slug: tts-audio
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-27
---

# Phase 04 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest 8.x (backend), vitest 4.x (frontend) |
| **Config file** | `apps/api/pyproject.toml`, `apps/admin/vitest.config.ts` |
| **Quick run command** | `cd apps/api && uv run pytest tests/test_admin_content_edit.py -q` |
| **Full suite command** | `cd apps/api && uv run pytest tests/ -q --tb=short` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `cd apps/api && uv run pytest tests/test_admin_tts.py -q`
- **After every plan wave:** Run `cd apps/api && uv run pytest tests/ -q --tb=short`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | TTS-01 | unit | `uv run pytest tests/test_admin_tts.py -q` | ❌ W0 | ⬜ pending |
| 04-01-02 | 01 | 1 | TTS-02 | unit | `uv run pytest tests/test_admin_tts.py -q` | ❌ W0 | ⬜ pending |
| 04-02-01 | 02 | 2 | TTS-01 | manual | Browser audio playback | N/A | ⬜ pending |
| 04-02-02 | 02 | 2 | TTS-02 | manual | Browser regeneration flow | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `apps/api/tests/test_admin_tts.py` — stubs for TTS-01, TTS-02 backend endpoints
- [ ] GCS CORS verification — ensure audio URLs are accessible from browser

*Existing test infrastructure (pytest, conftest.py) covers base requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Audio playback in browser | TTS-01 | Requires browser Audio API | Open edit page, click play, verify audio plays |
| Regeneration dialog + auto-play | TTS-02 | Requires browser interaction | Click regenerate, confirm dialog, verify new audio plays |
| Cooldown countdown UI | TTS-02 | Requires visual timer verification | Regenerate, verify button disabled with countdown |
| TTS field dropdown selection | TTS-01 | Requires UI interaction | Open edit page, change TTS field in dropdown, verify audio changes |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
