---
phase: 06-tts-per-field-audio
plan: 01
subsystem: api
tags: [alembic, sqlalchemy, fastapi, tts, pydantic, postgresql]

requires:
  - phase: 04-tts-audio
    provides: TtsAudio model, admin TTS endpoints, GCS upload pipeline
provides:
  - Alembic migration adding field column to tts_audio with 4-col UniqueConstraint
  - AdminTtsMapResponse schema returning per-field audio map
  - Field-scoped TTS regeneration (only deletes targeted field row)
  - TTS_FIELDS dict defining valid fields per content type
  - Backward-compatible tts.py with field="reading" filter
affects: [06-02-PLAN, admin-frontend-tts]

tech-stack:
  added: []
  patterns: [per-field audio storage with field column, field-keyed map response pattern]

key-files:
  created:
    - apps/api/alembic/versions/j0k1l2m3n4o5_add_tts_audio_field_column.py
  modified:
    - apps/api/app/models/tts.py
    - apps/api/app/schemas/admin_content.py
    - apps/api/app/routers/admin_content.py
    - apps/api/app/routers/tts.py
    - apps/api/tests/test_admin_tts.py

key-decisions:
  - "3-step migration (nullable add -> backfill -> NOT NULL) for zero-downtime schema change"
  - "Field-scoped delete on regenerate preserves other fields' audio"
  - "GCS path pattern changed to /{content_type}/{item_id}/{field}.mp3 for multi-field storage"

patterns-established:
  - "TTS_FIELDS dict as single source of truth for valid fields per content type"
  - "AdminTtsMapResponse with dict[str, AudioFieldInfo | None] for per-field audio status"

requirements-completed: [TTS-03, TTS-04, TTS-05]

duration: 4min
completed: 2026-03-31
---

# Phase 06 Plan 01: Backend Per-Field TTS Summary

**Alembic migration adds field column to tts_audio with 4-col UniqueConstraint; API returns per-field audio map and does field-scoped regeneration**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-31T01:40:33Z
- **Completed:** 2026-03-31T01:44:44Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- 3-step Alembic migration: add nullable field, backfill per target_type, set NOT NULL + 4-col UniqueConstraint
- GET /{content_type}/{item_id}/tts returns AdminTtsMapResponse with per-field audio map (null for missing fields)
- POST /tts/regenerate validates field against TTS_FIELDS, deletes only targeted field row, uses new GCS path
- Main app tts.py backward compatible with field="reading" filter on queries and inserts
- 10 pytest tests all passing

## Task Commits

Each task was committed atomically:

1. **Task 1: Alembic migration + TtsAudio model + Pydantic schemas + TTS_FIELDS dict** - `d7cb273` (feat)
2. **Task 2: Update GET/POST endpoints + tts.py compatibility + pytest tests** - `5cd7c92` (feat)

## Files Created/Modified
- `apps/api/alembic/versions/j0k1l2m3n4o5_add_tts_audio_field_column.py` - 3-step migration adding field column
- `apps/api/app/models/tts.py` - Added field column + updated UniqueConstraint to 4 columns
- `apps/api/app/schemas/admin_content.py` - Added AudioFieldInfo and AdminTtsMapResponse Pydantic schemas
- `apps/api/app/routers/admin_content.py` - TTS_FIELDS dict, updated GET to map response, POST to field-scoped delete
- `apps/api/app/routers/tts.py` - Added field="reading" filter on queries and inserts
- `apps/api/tests/test_admin_tts.py` - 10 tests covering map response, field-scoped delete, invalid field validation

## Decisions Made
- 3-step migration approach (add nullable -> backfill -> NOT NULL) ensures zero-downtime deployment
- Field-scoped delete on regenerate preserves other fields' audio (previously deleted all rows for an item)
- GCS path changed from `/{item_id}.mp3` to `/{item_id}/{field}.mp3` to support multiple audio files per item
- Backfill mapping: vocabulary->reading, grammar->pattern, cloze->sentence, sentence_arrange->japanese_sentence, conversation->situation

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed test assertions for CamelModel dict key format**
- **Found during:** Task 2 (pytest tests)
- **Issue:** Tests expected camelCase dict keys (`exampleSentence`) but TTS_FIELDS dict keys are snake_case and passed through as-is in the audios map
- **Fix:** Changed test assertions to use snake_case keys (`example_sentence`)
- **Files modified:** apps/api/tests/test_admin_tts.py
- **Verification:** All 10 tests pass

**2. [Rule 1 - Bug] Fixed test assertion for custom error handler format**
- **Found during:** Task 2 (pytest tests)
- **Issue:** Tests expected `resp.json()["detail"]` but app has custom error handler wrapping HTTPException into `{"error": {"message": ...}}`
- **Fix:** Updated assertion to handle both `detail` and `error.message` formats
- **Files modified:** apps/api/tests/test_admin_tts.py
- **Verification:** All 10 tests pass

---

**Total deviations:** 2 auto-fixed (2 bugs in test assertions)
**Impact on plan:** Minor test assertion fixes. No scope creep.

## Issues Encountered
None - implementation followed plan specification.

## User Setup Required
None - no external service configuration required.

## Known Stubs
None - all endpoints are fully wired with real data sources.

## Next Phase Readiness
- Backend API fully supports per-field TTS audio storage and retrieval
- Plan 06-02 (frontend) can now build on AdminTtsMapResponse for per-field audio UI
- TTS_FIELDS dict serves as single source of truth for valid fields per content type

## Self-Check: PASSED

All 6 files verified present. Both commit hashes (d7cb273, 5cd7c92) confirmed in git log.

---
*Phase: 06-tts-per-field-audio*
*Completed: 2026-03-31*
