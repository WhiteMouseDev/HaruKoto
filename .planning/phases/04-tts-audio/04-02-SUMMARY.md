---
phase: 04-tts-audio
plan: "02"
subsystem: apps/admin
tags: [tts, audio, frontend, i18n, react]
dependency_graph:
  requires: [04-01]
  provides: [TTS_PLAYER_UI, TTS_I18N]
  affects: [apps/admin/src/app/(admin)/vocabulary, apps/admin/src/app/(admin)/grammar, apps/admin/src/app/(admin)/quiz, apps/admin/src/app/(admin)/conversation]
tech_stack:
  added: [shadcn-select]
  patterns: [tanstack-query-mutation, localStorage-cooldown, html5-audio-api, next-intl-namespace]
key_files:
  created:
    - apps/admin/src/components/ui/select.tsx
    - apps/admin/src/lib/tts-fields.ts
    - apps/admin/src/hooks/use-tts-player.ts
    - apps/admin/src/components/content/regenerate-confirm-dialog.tsx
    - apps/admin/src/components/content/tts-player.tsx
  modified:
    - apps/admin/src/lib/api/admin-content.ts
    - apps/admin/messages/ja.json
    - apps/admin/messages/ko.json
    - apps/admin/messages/en.json
    - apps/admin/src/app/(admin)/vocabulary/[id]/page.tsx
    - apps/admin/src/app/(admin)/grammar/[id]/page.tsx
    - apps/admin/src/app/(admin)/quiz/[id]/page.tsx
    - apps/admin/src/app/(admin)/conversation/[id]/page.tsx
decisions:
  - "Lazy state initialization (useState(() => readCooldownSeconds())) used instead of useEffect+setState to avoid react-hooks/set-state-in-effect lint error"
  - "Snake_case TtsAudioResponse type (audio_url, field, provider) matches FastAPI Pydantic serialization; hook remaps to camelCase (audioUrl) for component consumption"
  - "TtsPlayer wraps both audio-present and audio-absent states with RegenerateConfirmDialog to unify regeneration flow"
metrics:
  duration: "4m"
  completed_date: "2026-03-27"
  tasks_completed: 3
  tasks_total: 4
  files_modified: 13
---

# Phase 4 Plan 2: Frontend TTS Player — Summary

## One-liner

Mini TTS player strip with field selector, play/pause, waveform, and 10-minute localStorage cooldown integrated into all 4 edit pages.

## What Was Built

- **shadcn Select** installed (apps/admin/src/components/ui/select.tsx)
- **TTS_FIELDS config** (`apps/admin/src/lib/tts-fields.ts`): Static mapping of TTS-capable fields per content type (vocabulary=reading/word/example_sentence, grammar=pattern, cloze=sentence, sentence_arrange=japanese_sentence, conversation=situation)
- **API functions** in `admin-content.ts`: `fetchTtsAudio()` and `regenerateTts()` with snake_case `TtsAudioResponse` type matching FastAPI's Pydantic serialization
- **useTtsPlayer hook** (`apps/admin/src/hooks/use-tts-player.ts`): TanStack Query for TTS URL fetch, useMutation for regeneration, HTML5 Audio play/pause, localStorage cooldown countdown
- **RegenerateConfirmDialog** (`regenerate-confirm-dialog.tsx`): Minimal confirm dialog following RejectReasonDialog pattern; cancel button has autoFocus for safety
- **TtsPlayer** (`tts-player.tsx`): Mini player strip with three states — loading skeleton, audio-absent (bg-muted + "Generate" CTA), audio-present (field selector + play/pause + waveform + regenerate/cooldown)
- **i18n strings** added to ja.json, ko.json, en.json under `tts` namespace (17 keys + 7 field labels each)
- **Page integration**: TtsPlayer placed between ReviewHeader and form on all 4 pages (vocabulary, grammar, quiz, conversation)

## Commits

| Task | Commit | Files |
|------|--------|-------|
| Task 1: shadcn Select + config + API + hook | a751202 | select.tsx, tts-fields.ts, admin-content.ts, use-tts-player.ts |
| Task 2: RegenerateConfirmDialog + TtsPlayer | a1ae333 | regenerate-confirm-dialog.tsx, tts-player.tsx |
| Task 3: i18n + page integration | d939a4c | ja.json, ko.json, en.json, all 4 edit pages |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed setState-in-effect lint error in useTtsPlayer**
- **Found during:** Task 1 lint verification
- **Issue:** Using `useEffect` to call `setRemainingSeconds(readCooldownSeconds(...))` triggered `react-hooks/set-state-in-effect` lint error
- **Fix:** Replaced with lazy state initializer `useState(() => readCooldownSeconds(contentType, itemId))`
- **Files modified:** `apps/admin/src/hooks/use-tts-player.ts`
- **Commit:** a751202

**2. [Rule 1 - Bug] Removed spurious eslint-disable comment in RegenerateConfirmDialog**
- **Found during:** Task 2 lint verification
- **Issue:** Added `// eslint-disable-next-line jsx-a11y/no-autofocus` which was flagged as an "unused directive" warning since no such rule was active
- **Fix:** Removed the comment, kept `autoFocus` attribute which is valid per accessibility spec for cancel button default focus
- **Files modified:** `apps/admin/src/components/content/regenerate-confirm-dialog.tsx`
- **Commit:** a1ae333

## Pending

**Task 4 (checkpoint:human-verify):** Human visual verification of TTS player on all edit pages. Blocked at checkpoint — requires human browser interaction.

## Known Stubs

None — all data flows are wired. The TtsPlayer fetches real TTS data from FastAPI via `fetchTtsAudio()`, and `regenerateTts()` calls the actual backend endpoint.

## Self-Check: PASSED

Created files verified:
- apps/admin/src/components/ui/select.tsx — exists (shadcn generated)
- apps/admin/src/lib/tts-fields.ts — exists
- apps/admin/src/hooks/use-tts-player.ts — exists
- apps/admin/src/components/content/regenerate-confirm-dialog.tsx — exists
- apps/admin/src/components/content/tts-player.tsx — exists

Commits verified:
- a751202 — feat(04-02): install shadcn Select, add TTS field config...
- a1ae333 — feat(04-02): create RegenerateConfirmDialog and TtsPlayer components
- d939a4c — feat(04-02): add i18n tts namespace and integrate TtsPlayer...
