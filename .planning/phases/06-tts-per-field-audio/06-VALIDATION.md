---
phase: 6
slug: tts-per-field-audio
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-30
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest >=8.3 + pytest-asyncio (backend), Vitest ^4.0.18 + Testing Library (frontend) |
| **Config file** | `apps/api/pyproject.toml` (pytest), `apps/admin/vitest.config.ts` (Vitest) |
| **Quick run command** | `cd apps/api && uv run pytest tests/test_admin_tts.py -x -q` / `cd apps/admin && pnpm vitest run src/__tests__/tts-player.test.tsx` |
| **Full suite command** | `cd apps/api && uv run pytest tests/ -q` / `cd apps/admin && pnpm vitest run` |
| **Estimated runtime** | ~15 seconds (backend) / ~10 seconds (frontend) |

---

## Sampling Rate

- **After every task commit:** Run quick run command for modified area (backend or frontend)
- **After every plan wave:** Run full suite command for both backend and frontend
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 25 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 06-01-01 | 01 | 1 | TTS-05 | integration | `cd apps/api && uv run pytest tests/test_admin_tts.py -k migration -q` | ❌ W0 | ⬜ pending |
| 06-01-02 | 01 | 1 | TTS-03 | unit | `cd apps/api && uv run pytest tests/test_admin_tts.py -k get_tts -q` | ✅ | ⬜ pending |
| 06-01-03 | 01 | 1 | TTS-04 | unit | `cd apps/api && uv run pytest tests/test_admin_tts.py -k regenerate -q` | ✅ | ⬜ pending |
| 06-02-01 | 02 | 2 | TTS-03 | unit | `cd apps/admin && pnpm vitest run src/__tests__/tts-player.test.tsx` | ✅ | ⬜ pending |
| 06-02-02 | 02 | 2 | TTS-04 | unit | `cd apps/admin && pnpm vitest run src/__tests__/tts-player.test.tsx` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/test_admin_tts.py` — migration backfill test stubs for TTS-05
- [ ] Existing `tts-player.test.tsx` mock structure update from `audioUrl` to `audios` map

*Existing test infrastructure (pytest, Vitest) covers framework needs. No new installs required.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| TTS 오디오 실제 재생 | TTS-03 | 브라우저 Audio API 필요 | 편집 화면에서 각 필드 재생 버튼 클릭 → 음성 재생 확인 |
| 기존 오디오 마이그레이션 후 재생 | TTS-05 | 실제 DB + GCS 데이터 필요 | 마이그레이션 후 기존 아이템 편집 화면 → 기본 필드 오디오 재생 확인 |
| 4개 콘텐츠 타입별 UI 동작 | TTS-03 | 브라우저 렌더링 확인 필요 | 단어/문법/퀴즈/회화 편집 화면 순회하며 필드별 TTS UI 표시 확인 |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 25s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
