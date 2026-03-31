---
phase: 06-tts-per-field-audio
verified: 2026-03-30T12:00:00Z
status: passed
score: 10/10 must-haves verified
re_verification: false
---

# Phase 06: TTS Per-Field Audio Verification Report

**Phase Goal:** Reviewer가 단어 편집 화면에서 읽기/단어/예문 각 필드별로 독립적인 TTS 오디오를 생성/재생할 수 있으며, 기존 데이터가 마이그레이션 후에도 정상 동작한다
**Verified:** 2026-03-30
**Status:** passed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Alembic migration adds field column to tts_audio with NOT NULL constraint and backfills existing rows | VERIFIED | `j0k1l2m3n4o5_add_tts_audio_field_column.py` has 3-step upgrade: add_column nullable, UPDATE backfill per target_type, alter_column NOT NULL |
| 2 | GET /{content_type}/{item_id}/tts returns a map of field->audio info instead of single audio | VERIFIED | `admin_content.py:1207` has `response_model=AdminTtsMapResponse`, builds `audios` dict from `TTS_FIELDS[content_type]`, returns `AdminTtsMapResponse(audios=audios)` |
| 3 | POST /tts/regenerate deletes and inserts only the specified field's row, not all rows for the item | VERIFIED | `admin_content.py:1092` has `TtsAudio.field == body.field` in DELETE WHERE; `admin_content.py:1114` has `field=body.field` in INSERT |
| 4 | Main app tts.py queries filter by field='reading' and INSERT includes field='reading' | VERIFIED | `tts.py:56` has `TtsAudio.field == "reading"` in WHERE; `tts.py:96` has `field="reading"` in constructor |
| 5 | UniqueConstraint is (target_type, target_id, speed, field) -- 4 columns | VERIFIED | `models/tts.py:27` has `UniqueConstraint("target_type", "target_id", "speed", "field")`, migration creates `uq_tts_audio_target_field` with same 4 columns |
| 6 | Each field row independently shows has-audio or no-audio state based on audios[field] from the map response | VERIFIED | `tts-player.tsx:54-55` computes `const fieldAudio = audios[field.value]; const hasFieldAudio = !!fieldAudio;` per field in map() |
| 7 | Playing one field does not affect other fields' visual state or audio | VERIFIED | `use-tts-player.ts:39-58` handlePlayPause uses per-field URL via `audios[field]?.audioUrl` and tracks `playingField` state; only one field is active |
| 8 | Regenerating one field only invalidates and updates that field's row | VERIFIED | `use-tts-player.ts:62` mutation sends single field; backend DELETE is field-scoped; query invalidation refetches full map |
| 9 | Grammar content type shows both pattern and example_sentences fields | VERIFIED | `tts-fields.ts:12-14` grammar options has 2 entries: `pattern` and `example_sentences` |
| 10 | i18n key tts.fields.exampleSentences exists in ja/ko/en | VERIFIED | ja.json has `"exampleSentences": "例文"`, ko.json has `"exampleSentences": "예문"`, en.json has `"exampleSentences": "Example Sentences"` (all under `tts.fields`) |

**Score:** 10/10 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `apps/api/alembic/versions/j0k1l2m3n4o5_add_tts_audio_field_column.py` | 3-step migration | VERIFIED | 59 lines, add_column + backfill + NOT NULL + UniqueConstraint, proper downgrade |
| `apps/api/app/models/tts.py` | TtsAudio model with field column | VERIFIED | `field: Mapped[str] = mapped_column(Text, nullable=False)` + 4-col UniqueConstraint |
| `apps/api/app/schemas/admin_content.py` | AudioFieldInfo and AdminTtsMapResponse Pydantic schemas | VERIFIED | Both classes present with correct fields; `audios: dict[str, AudioFieldInfo \| None]` |
| `apps/api/app/routers/admin_content.py` | Updated GET returning map, POST field-scoped, TTS_FIELDS dict | VERIFIED | TTS_FIELDS at line 1032 with all 5 content types; GET returns map; POST validates field and does field-scoped delete |
| `apps/api/app/routers/tts.py` | Backward-compatible with field="reading" | VERIFIED | WHERE clause and INSERT both include field="reading" |
| `apps/api/tests/test_admin_tts.py` | 10 pytest tests covering per-field behavior | VERIFIED | 10 tests covering map response, field-scoped delete, invalid field 422, field in constructor |
| `apps/admin/src/lib/tts-fields.ts` | Grammar has example_sentences | VERIFIED | grammar options has 2 entries |
| `apps/admin/src/lib/api/admin-content.ts` | AudioFieldInfo + TtsAudioMapResponse types | VERIFIED | Both types exported; fetchTtsAudio returns `Promise<TtsAudioMapResponse>` |
| `apps/admin/src/hooks/use-tts-player.ts` | Returns audios map, per-field play | VERIFIED | `useQuery<TtsAudioMapResponse>`, returns `audios`, handlePlayPause uses `audios[field]?.audioUrl` |
| `apps/admin/src/components/content/tts-player.tsx` | Per-field hasFieldAudio check | VERIFIED | `audios[field.value]` lookup per field, independent CheckCircle2/XCircle rendering |
| `apps/admin/src/__tests__/tts-player.test.tsx` | 11 Vitest tests including mixed-state | VERIFIED | 11 test cases including mixed audio state and generate-click tests |
| `apps/admin/messages/ja.json` | exampleSentences i18n key | VERIFIED | Present under tts.fields |
| `apps/admin/messages/ko.json` | exampleSentences i18n key | VERIFIED | Present under tts.fields |
| `apps/admin/messages/en.json` | exampleSentences i18n key | VERIFIED | Present under tts.fields |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `admin_content.py` | `models/tts.py` | `TtsAudio.field` in WHERE clauses | WIRED | `TtsAudio.field == body.field` at line 1092, `record.field` at line 1231 |
| `tts.py` | `models/tts.py` | `field='reading'` filter on queries and inserts | WIRED | `TtsAudio.field == "reading"` at line 56, `field="reading"` at line 96 |
| `use-tts-player.ts` | `admin-content.ts` | fetchTtsAudio returns TtsAudioMapResponse | WIRED | Import at line 8-11, `useQuery<TtsAudioMapResponse>` at line 31 |
| `tts-player.tsx` | `use-tts-player.ts` | destructures audios from useTtsPlayer | WIRED | `audios` destructured at line 20, used at line 54 |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| `tts-player.tsx` | `audios` | `useTtsPlayer` -> `fetchTtsAudio` -> FastAPI GET | FastAPI queries TtsAudio table via SQLAlchemy `select(TtsAudio)` with `scalars().all()` | FLOWING |
| `admin_content.py` GET endpoint | `records` | `db.execute(select(TtsAudio)...)` | Real DB query with 3 WHERE conditions | FLOWING |

### Behavioral Spot-Checks

Step 7b: SKIPPED (no runnable server available for endpoint testing)

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| TTS-03 | 06-01, 06-02 | 단어 편집 화면에서 읽기/단어/예문 필드별로 개별 TTS 오디오를 생성할 수 있다 | SATISFIED | TTS_FIELDS defines reading/word/example_sentence for vocabulary; backend stores per-field; frontend renders per-field with generate button |
| TTS-04 | 06-01, 06-02 | 필드별 오디오가 독립적으로 재생/재생성된다 (다른 필드에 영향 없음) | SATISFIED | DELETE is field-scoped; hook plays per-field URL; component shows independent status icons |
| TTS-05 | 06-01 | 기존 아이템당 1개 오디오 데이터가 마이그레이션 후에도 정상 동작한다 | SATISFIED | Migration backfills existing rows with default field per target_type; main app tts.py uses field="reading" filter for backward compatibility |

No orphaned requirements found.

### Anti-Patterns Found

No anti-patterns detected. All files clean of TODO/FIXME/PLACEHOLDER/stub patterns.

### Human Verification Required

### 1. Visual Per-Field Audio State

**Test:** Open vocabulary edit page in admin. Verify reading field shows green CheckCircle2 when audio exists and XCircle when not.
**Expected:** Each field row independently shows correct icon. Fields without audio show "No audio" text and Generate button.
**Why human:** Visual rendering cannot be verified programmatically.

### 2. Independent Play/Pause Behavior

**Test:** Generate audio for reading and word fields on the same vocabulary item. Play reading audio, then click play on word field.
**Expected:** Reading audio stops, word audio starts. Only one field shows Pause icon at a time.
**Why human:** Audio playback behavior requires browser runtime.

### 3. Field-Scoped Regeneration

**Test:** With both reading and word audio present, regenerate only the word field. Verify reading audio is unchanged.
**Expected:** Reading audio URL and status remain intact. Word audio gets new URL and auto-plays.
**Why human:** End-to-end behavior with real TTS service and GCS upload.

### 4. Migration Backward Compatibility

**Test:** After running migration on production data, verify existing vocabulary items still have their audio playable via main app.
**Expected:** Main app queries with field="reading" successfully find backfilled records.
**Why human:** Requires running migration against real database.

### Gaps Summary

No gaps found. All 10 must-haves verified against the codebase. Backend implements per-field storage with 3-step migration, field-scoped API operations, and backward compatibility. Frontend consumes the map response correctly with independent per-field state rendering. All requirement IDs (TTS-03, TTS-04, TTS-05) are satisfied.

---

_Verified: 2026-03-30_
_Verifier: Claude (gsd-verifier)_
