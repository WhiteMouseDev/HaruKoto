---
phase: 04-tts-audio
verified: 2026-03-27T05:41:09Z
status: human_needed
score: 4/5 must-haves verified (criterion 3 descoped)
human_verification:
  - test: "Open any vocabulary edit page (e.g. /vocabulary/{id}) in the browser"
    expected: "TTS player strip appears between ReviewHeader and the edit form with field selector, Play button, and waveform bars"
    why_human: "Visual rendering and HTML5 Audio API playback cannot be verified programmatically"
  - test: "Click Play on an item that has existing TTS audio"
    expected: "Audio plays through the browser speaker; waveform bars animate; button changes to Pause icon"
    why_human: "Requires audio hardware and browser interaction"
  - test: "Click the RotateCcw (regenerate) button"
    expected: "Confirm dialog appears with item label; clicking confirm triggers regeneration spinner, then success toast, then new audio auto-plays"
    why_human: "Requires live FastAPI + GCS + TTS provider connection"
  - test: "Navigate to an item with no TTS audio"
    expected: "Player shows bg-muted strip with 'オーディオなし' label and accent 'Generate' button"
    why_human: "Depends on database state"
  - test: "Switch language to Korean or English via locale toggle"
    expected: "All tts.* i18n keys render in the selected language (e.g. '오디오 없음', 'No audio')"
    why_human: "Requires browser UI interaction with locale switcher"
---

# Phase 4: TTS Audio — Verification Report

**Phase Goal:** Reviewer가 편집 화면에서 TTS 오디오를 재생하고, 필요 시 재생성을 요청할 수 있다
**Verified:** 2026-03-27T05:41:09Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Note on Cooldown Descope

Success criterion 3 ("재생성 후 10분 이내에 같은 항목의 재생성을 다시 시도하면 쿨다운 안내 메시지가 표시된다") was intentionally removed per user feedback. The admin tool serves 1-3 reviewers and does not require cooldown protection. The ROADMAP still shows criterion 3, but it has been descoped and is excluded from this verification.

Affected items removed from implementation:
- Backend: `rate_limit()` call and `import time` removed from `admin_content.py`
- Backend: `test_regenerate_tts_cooldown_429` test absent (5 tests instead of 6)
- Frontend: No `remainingSeconds`, `setInterval`, `harukoto_admin_tts_cooldown` localStorage, or cooldown UI in `use-tts-player.ts` or `tts-player.tsx`

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | GET `/api/v1/admin/content/{content_type}/{item_id}/tts` returns `audio_url` when TtsAudio record exists | VERIFIED | `async def get_admin_tts` at line 1051 of `admin_content.py` — queries `TtsAudio` with `scalar_one_or_none()`, returns `AdminTtsResponse` |
| 2 | GET returns `audio_url=null` when no TtsAudio record exists | VERIFIED | Same function returns `AdminTtsResponse(audio_url=None, field=None, provider=None)` when `record` is None |
| 3 | POST `/api/v1/admin/tts/regenerate` deletes old TtsAudio, generates new, returns `audio_url` | VERIFIED | `async def regenerate_admin_tts` at line 997 — `sa_delete(TtsAudio)`, `generate_tts()`, `_upload_to_gcs()`, `db.add(TtsAudio(...))`, `db.commit()` all present |
| 4 | POST returns 429 when called within 10-minute cooldown window | DESCOPED | Cooldown intentionally removed per user feedback — no `rate_limit()` call in endpoint |
| 5 | Reviewer sees TTS player strip on all 4 edit pages | VERIFIED | All 4 pages import `TtsPlayer` and render `<TtsPlayer contentType=... itemId={id} itemLabel={...} />` |
| 6 | Reviewer can select TTS field and trigger play/pause | VERIFIED | `TtsPlayer` renders shadcn `Select` with `TTS_FIELDS[contentType].options`, Play/Pause button calls `handlePlayPause()` from `useTtsPlayer` hook |
| 7 | Reviewer can click regenerate, confirm in dialog, hear new audio | VERIFIED (code) | `RegenerateConfirmDialog` wired to `regenerateMutation.mutate()`, `onSuccess` creates `new Audio(newData.audioUrl)` and calls `.play()` — requires human to confirm audio plays in browser |

**Score:** 4/5 truths verified (criterion 4 descoped, criterion 7 needs human audio verification)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `apps/api/app/routers/admin_content.py` | GET tts + POST regenerate endpoints | VERIFIED | `async def get_admin_tts` line 1051, `async def regenerate_admin_tts` line 997, `def resolve_tts_text` line 984 |
| `apps/api/app/schemas/admin_content.py` | AdminTtsRegenerateRequest, AdminTtsResponse schemas | VERIFIED | `class AdminTtsResponse(CamelModel)` line 220, `class AdminTtsRegenerateRequest(CamelModel)` line 226 |
| `apps/api/tests/test_admin_tts.py` | Backend TTS endpoint tests | VERIFIED | 5 tests present and passing: `test_get_tts_returns_audio_url`, `test_get_tts_returns_null_when_no_record`, `test_regenerate_tts_success`, `test_regenerate_tts_not_found_404`, `test_regenerate_tts_empty_field_422` |
| `apps/admin/src/components/content/tts-player.tsx` | Mini player strip component | VERIFIED | `export function TtsPlayer` at line 24, three states implemented (loading/absent/present) |
| `apps/admin/src/components/content/regenerate-confirm-dialog.tsx` | Regeneration confirmation dialog | VERIFIED | `export function RegenerateConfirmDialog` at line 23 |
| `apps/admin/src/hooks/use-tts-player.ts` | Audio state, mutation hook | VERIFIED | `export function useTtsPlayer` at line 14 — TanStack Query, useMutation, HTML5 Audio |
| `apps/admin/src/lib/tts-fields.ts` | TTS field config per content type | VERIFIED | `export const TTS_FIELDS` at line 1 with all 5 content types |
| `apps/admin/src/lib/api/admin-content.ts` | fetchTtsAudio and regenerateTts API functions | VERIFIED | `export async function fetchTtsAudio` at line 198, `export async function regenerateTts` present |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `admin_content.py` | `app/models/tts.py` | TtsAudio model queries | WIRED | `from app.models.tts import TtsAudio` (line 19), `select(TtsAudio)`, `sa_delete(TtsAudio)` |
| `admin_content.py` | `app/services/ai.py` | `generate_tts()` call | WIRED | `from app.services.ai import generate_tts` (line 47), called in `regenerate_admin_tts` |
| `admin_content.py` | `app/middleware/rate_limit.py` | rate_limit for cooldown | NOT_WIRED (descoped) | Cooldown intentionally removed; no `rate_limit` import in file |
| `use-tts-player.ts` | `admin-content.ts` | `fetchTtsAudio()` in useQuery, `regenerateTts()` in useMutation | WIRED | Lines 8-9 import both; `queryFn: () => fetchTtsAudio(...)` line 36; `mutationFn: () => regenerateTts(...)` line 63 |
| `tts-player.tsx` | `use-tts-player.ts` | `useTtsPlayer()` hook call | WIRED | `import { useTtsPlayer }` line 14; `useTtsPlayer(contentType, itemId)` called at line 36 |
| `vocabulary/[id]/page.tsx` | `tts-player.tsx` | `<TtsPlayer>` component import | WIRED | `import { TtsPlayer }` line 16; `<TtsPlayer contentType="vocabulary" itemId={id} ...>` line 160 |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `tts-player.tsx` | `audioUrl` | `useTtsPlayer` hook → `fetchTtsAudio()` → FastAPI GET endpoint → `TtsAudio` DB query | Yes — `select(TtsAudio).where(...)` in `get_admin_tts` returns real DB record | FLOWING |
| `tts-player.tsx` | `regenerateMutation.data.audioUrl` | `regenerateTts()` → POST endpoint → `generate_tts()` + `_upload_to_gcs()` → real GCS URL | Yes — endpoint fetches content, generates TTS, uploads to GCS, saves to DB | FLOWING (GCS/TTS requires live infra) |

**Note on CamelModel serialization:** The backend uses `CamelModel` (with `alias_generator=to_camel`) which serializes `audio_url` as `audioUrl` in JSON responses. The TypeScript `TtsAudioResponse` type correctly uses `audioUrl: string | null` (camelCase) to match. This is consistent and correct — the plan's acceptance criterion requiring `audio_url` (snake_case) in TypeScript was overridden by the CamelModel pattern already established in the admin app.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| All pytest tests pass | `cd apps/api && uv run pytest tests/test_admin_tts.py -x -q` | 5 passed, 1 warning (coroutine mock — non-blocking) | PASS |
| Backend ruff check | `cd apps/api && uv run ruff check app/routers/admin_content.py app/schemas/admin_content.py tests/test_admin_tts.py` | All checks passed | PASS |
| Admin frontend lint | `pnpm --filter admin lint` | No errors | PASS |
| TtsPlayer export present | grep for `export function TtsPlayer` | Found at line 24 of `tts-player.tsx` | PASS |
| All 4 pages render TtsPlayer | grep `<TtsPlayer` in all 4 page files | Found in vocabulary, grammar, quiz, conversation | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|---------|
| TTS-01 | 04-01, 04-02 | Reviewer가 편집 화면에서 기존 TTS 오디오를 재생할 수 있다 | SATISFIED (needs human for audio playback) | GET endpoint returns audio_url; TtsPlayer renders Play/Pause with HTML5 Audio; wired into all 4 pages |
| TTS-02 | 04-01, 04-02 | Reviewer가 개별 항목의 TTS를 재생성 요청할 수 있다 (확인 다이얼로그 포함) | SATISFIED (needs human for audio confirm) | POST endpoint generates TTS via generate_tts(); RegenerateConfirmDialog wired; auto-play on success |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `apps/api/tests/test_admin_tts.py` | `test_regenerate_tts_success` | `RuntimeWarning: coroutine 'AsyncMockMixin._execute_mock_call' was never awaited` | Info | Test mock for `db.add()` is not awaited — non-blocking warning, test still passes. Does not affect goal. |

No blockers found. No stubs. No placeholder components.

### Human Verification Required

#### 1. Audio Playback

**Test:** Open a vocabulary edit page with existing TTS audio. Click the Play button.
**Expected:** Audio plays through the browser; waveform bars animate with `animate-pulse`; button changes to Pause icon. Click Pause — audio stops.
**Why human:** HTML5 Audio API playback and waveform animation cannot be verified programmatically.

#### 2. No-Audio State

**Test:** Open an edit page for a content item with no TTS audio in the database.
**Expected:** Player strip has `bg-muted` background, shows "オーディオなし" label, and an accent "生成する" button. No play button or waveform.
**Why human:** Depends on actual database state; cannot verify which items lack TTS records.

#### 3. Regeneration Flow

**Test:** Click the RotateCcw button on any edit page.
**Expected:** RegenerateConfirmDialog opens with the item label. Click "再生成する". Loading spinner shows. After completion: success toast appears, new audio auto-plays, player updates with new audio URL.
**Why human:** Requires live FastAPI + ElevenLabs/Gemini TTS service + GCS upload pipeline.

#### 4. Field Selector

**Test:** On vocabulary page, change field selector from "読み方" to "単語".
**Expected:** TanStack Query re-fetches TTS for the new field; player updates audio URL for the selected field.
**Why human:** Requires live API and content data with field-specific TTS records.

#### 5. i18n Locale Switching

**Test:** Switch locale to Korean or English via the admin locale toggle.
**Expected:** All TTS player labels update correctly (e.g. "오디오 없음", "No audio"; "재생성하기", "Regenerate").
**Why human:** Requires UI locale switching interaction.

### Gaps Summary

No gaps blocking goal achievement. All automated checks pass. The phase implements:

- Backend: Two FastAPI endpoints (GET + POST) with `require_reviewer` auth, `TtsAudio` DB queries, real TTS generation pipeline, and 5 passing tests
- Frontend: `TtsPlayer` component with three states (loading/absent/present), `useTtsPlayer` hook with TanStack Query and HTML5 Audio, `RegenerateConfirmDialog`, `TTS_FIELDS` config, complete i18n in 3 languages, integrated into all 4 edit pages

The descoped cooldown (criterion 3) is consistent throughout: no backend `rate_limit()`, no frontend countdown, no cooldown test. The ROADMAP still lists criterion 3 — recommend updating ROADMAP.md to remove it or mark it as descoped.

The remaining `human_needed` status is for browser-side audio playback and the live TTS regeneration flow, both of which require actual hardware/services that cannot be verified programmatically.

---

_Verified: 2026-03-27T05:41:09Z_
_Verifier: Claude (gsd-verifier)_
