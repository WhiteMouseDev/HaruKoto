---
phase: 04-tts-audio
plan: 01
subsystem: api
tags: [tts, admin, fastapi, rate-limit, gcs]
dependency_graph:
  requires: []
  provides: [admin-tts-get-endpoint, admin-tts-regenerate-endpoint]
  affects: [04-02-frontend-tts]
tech_stack:
  added: []
  patterns: [rate-limit-cooldown, _upload_to_gcs-reuse, require_reviewer-auth]
key_files:
  created:
    - apps/api/tests/test_admin_tts.py
  modified:
    - apps/api/app/routers/admin_content.py
    - apps/api/app/schemas/admin_content.py
decisions:
  - POST /tts/regenerate registered before /{content_type}/{item_id}/tts to avoid FastAPI treating "tts" as content_type parameter
  - _CONTENT_MODEL_MAP added separately from existing MODEL_MAP — colocated near TTS endpoints for clarity
  - CamelModel used for AdminTtsResponse and AdminTtsRegenerateRequest — consistent with existing admin schemas
metrics:
  duration: 5m
  completed: "2026-03-27T01:59:20Z"
  tasks: 2
  files_modified: 3
---

# Phase 4 Plan 1: Admin TTS Backend Endpoints Summary

**One-liner:** FastAPI GET+POST admin TTS endpoints with Redis 10-min cooldown, ElevenLabs/Gemini pipeline reuse, and 6 pytest tests covering happy path and error cases.

## What Was Built

Two new admin TTS endpoints added to `apps/api/app/routers/admin_content.py` under the `/api/v1/admin/content` router:

- **GET `/{content_type}/{item_id}/tts`** — Returns existing `TtsAudio` record (audio_url, field, provider) or null values when no record exists. Uses `require_reviewer` auth.
- **POST `/tts/regenerate`** — Accepts `AdminTtsRegenerateRequest` (content_type, item_id, field), enforces 10-minute Redis cooldown per item, fetches content model, resolves TTS text, deletes old `TtsAudio` row, generates new TTS via `generate_tts()`, uploads to GCS via `_upload_to_gcs()`, saves new `TtsAudio` row, returns audio URL.

New Pydantic schemas added to `apps/api/app/schemas/admin_content.py`:
- `AdminTtsResponse` — audio_url, field, provider (all optional)
- `AdminTtsRegenerateRequest` — content_type (Literal union), item_id, field

Helper function `resolve_tts_text()` extracts the correct text from a content model instance by field name, with special handling for grammar `example_sentences` JSON field.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add Pydantic schemas + GET/POST TTS endpoints | c4b84c3 | admin_content.py, schemas/admin_content.py |
| 2 | Create pytest tests for admin TTS endpoints | e1437af | tests/test_admin_tts.py |

## Test Results

```
6 passed, 0 failed
127 passed (full suite), 8 skipped, no regressions
```

Tests cover:
- GET returns audio_url when TtsAudio record exists
- GET returns null when no record exists
- POST regenerate returns 200 with audio_url on success
- POST returns 429 when Redis cooldown is active
- POST returns 404 when content item not found
- POST returns 422 when requested field is empty

## Deviations from Plan

None — plan executed exactly as written.

The `_CONTENT_MODEL_MAP` dict was added separately from the existing `MODEL_MAP` (which already exists at line 107) to keep TTS-related code colocated near the TTS endpoints rather than modifying the existing map used for batch review operations.

## Known Stubs

None — all endpoints are fully wired to real dependencies (TtsAudio model, generate_tts(), _upload_to_gcs(), rate_limit()).

## Self-Check: PASSED

- apps/api/app/routers/admin_content.py: found `async def get_admin_tts`, `async def regenerate_admin_tts`, `def resolve_tts_text`
- apps/api/app/schemas/admin_content.py: found `class AdminTtsResponse`, `class AdminTtsRegenerateRequest`
- apps/api/tests/test_admin_tts.py: found `test_get_tts_returns_audio_url`, `test_regenerate_tts_cooldown_429`
- Commits c4b84c3, e1437af: verified in git log
