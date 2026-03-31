---
phase: 06-tts-per-field-audio
plan: 02
subsystem: ui
tags: [tts, react, tanstack-query, i18n, vitest]

requires:
  - phase: 06-tts-per-field-audio/01
    provides: Backend AdminTtsMapResponse with audios map and field-scoped DELETE on regenerate
provides:
  - Per-field audio state in TtsPlayer component (CheckCircle2/XCircle per field independently)
  - AudioFieldInfo and TtsAudioMapResponse frontend types
  - Grammar example_sentences TTS field option
  - i18n key tts.fields.exampleSentences in ja/ko/en
affects: []

tech-stack:
  added: []
  patterns:
    - "Per-field audio map destructuring in hook: audios[field]?.audioUrl"
    - "Per-field UI state in component via audios[field.value] lookup inside map()"

key-files:
  created: []
  modified:
    - apps/admin/src/lib/tts-fields.ts
    - apps/admin/src/lib/api/admin-content.ts
    - apps/admin/src/hooks/use-tts-player.ts
    - apps/admin/src/components/content/tts-player.tsx
    - apps/admin/src/__tests__/tts-player.test.tsx
    - apps/admin/messages/ja.json
    - apps/admin/messages/ko.json
    - apps/admin/messages/en.json

key-decisions:
  - "Keep TtsAudioResponse type for regenerateTts (POST response unchanged), add TtsAudioMapResponse for fetchTtsAudio (GET)"

patterns-established:
  - "Per-field audio map: hook returns Record<string, AudioFieldInfo | null>, component checks each field independently"

requirements-completed: [TTS-03, TTS-04]

duration: 3min
completed: 2026-03-31
---

# Phase 06 Plan 02: Frontend Per-Field Audio Map Summary

**Per-field audio state in TtsPlayer using audios map from backend, grammar example_sentences field, and mixed-state Vitest coverage**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-31T01:47:10Z
- **Completed:** 2026-03-31T01:50:17Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- Each TTS field row independently shows has-audio (CheckCircle2) or no-audio (XCircle) based on its own audios[field] value
- Grammar content type now shows both pattern and example_sentences fields
- Vitest tests cover mixed-state scenario (one field has audio, another does not)
- TypeScript compiles clean, all 11 TTS player tests pass

## Task Commits

Each task was committed atomically:

1. **Task 1: Update types, tts-fields, i18n, and API client** - `1aee322` (feat)
2. **Task 2: Refactor useTtsPlayer hook and TtsPlayer component for per-field audio map** - `7eeaa1d` (feat)

## Files Created/Modified
- `apps/admin/src/lib/tts-fields.ts` - Added example_sentences to grammar options
- `apps/admin/src/lib/api/admin-content.ts` - Added AudioFieldInfo, TtsAudioMapResponse types; updated fetchTtsAudio return type
- `apps/admin/src/hooks/use-tts-player.ts` - Returns audios map, handlePlayPause reads per-field URL
- `apps/admin/src/components/content/tts-player.tsx` - Per-field hasFieldAudio check via audios[field.value]
- `apps/admin/src/__tests__/tts-player.test.tsx` - Updated mocks to map format, added mixed-state and generate-click tests
- `apps/admin/messages/ja.json` - Added tts.fields.exampleSentences
- `apps/admin/messages/ko.json` - Added tts.fields.exampleSentences
- `apps/admin/messages/en.json` - Added tts.fields.exampleSentences

## Decisions Made
- Kept existing TtsAudioResponse type for regenerateTts (POST response unchanged per backend), added new TtsAudioMapResponse for fetchTtsAudio (GET)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Frontend now fully consumes per-field audio map from backend
- Phase 06 (tts-per-field-audio) is complete: backend (plan 01) + frontend (plan 02)

## Self-Check: PASSED

All 8 files verified present. Both task commits (1aee322, 7eeaa1d) confirmed in git log.

---
*Phase: 06-tts-per-field-audio*
*Completed: 2026-03-31*
