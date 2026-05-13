# N4 Pilot TTS Coverage Audit

> Date: 2026-05-13
> Scope: published N4 controlled-pilot lessons, HN4-001 through HN4-011
> Status: generated TTS coverage incomplete; broad/full N4 rollout remains HOLD

## Boundary

This is a read-only configured-DB audit for generated lesson TTS records. It
checks existing `tts_audio` rows for:

- `lesson_script_line` / `script_line`
- `lesson_question_prompt` / `question_prompt`

It does not call the TTS provider, write `tts_audio`, upload audio, or mark any
content as human audio-quality approved.

ASSUMPTION: For broad/full N4 rollout planning, a generated `tts_audio` row plus
read-only URL availability is necessary but not sufficient. Human
audio-quality review remains a separate gate.

## Command

```bash
cd apps/api
uv run python scripts/report_n4_pilot_tts_coverage.py \
  --level N4 \
  --check-audio-urls
```

## Summary

| Metric | Result |
|---|---:|
| Generated at | `2026-05-13T03:55:43.093776+00:00` |
| Published N4 lessons audited | 11 |
| Expected script-line TTS records | 44 |
| Generated script-line TTS records | 5 |
| Expected question-prompt TTS records | 55 |
| Generated question-prompt TTS records | 5 |
| Expected total TTS records | 99 |
| Generated total TTS records | 10 |
| Audio URLs checked | 10 |
| Audio URL failures | 0 |
| Provider/model | `elevenlabs/eleven_multilingual_v2`: 10 |

## Lesson Coverage

| Lesson | Script lines | Question prompts | Status |
|---|---:|---:|---|
| HN4-001 | 1 / 4 | 0 / 5 | Missing script indices `[1, 2, 3]`; questions `[1, 2, 3, 4, 5]` |
| HN4-002 | 0 / 4 | 0 / 5 | Missing all script lines and prompts |
| HN4-003 | 0 / 4 | 0 / 5 | Missing all script lines and prompts |
| HN4-004 | 0 / 4 | 0 / 5 | Missing all script lines and prompts |
| HN4-005 | 0 / 4 | 0 / 5 | Missing all script lines and prompts |
| HN4-006 | 0 / 4 | 0 / 5 | Missing all script lines and prompts |
| HN4-007 | 0 / 4 | 0 / 5 | Missing all script lines and prompts |
| HN4-008 | 0 / 4 | 0 / 5 | Missing all script lines and prompts |
| HN4-009 | 0 / 4 | 0 / 5 | Missing all script lines and prompts |
| HN4-010 | 0 / 4 | 0 / 5 | Missing all script lines and prompts |
| HN4-011 | 4 / 4 | 5 / 5 | Generated records present |

## Signals

- `AUDIO_URLS_READY`: 10 / 10 checked generated URLs passed read-only HTTP
  validation.

## Blockers

- `SCRIPT_LINE_TTS_RECORDS_MISSING`: 5 / 44 records exist.
- `QUESTION_PROMPT_TTS_RECORDS_MISSING`: 5 / 55 records exist.
- `LESSONS_WITH_TTS_GAPS`: HN4-001 through HN4-010.

## Decision

The current N4 pilot batch is not ready for broad/full rollout from a TTS
generation standpoint. HN4-011 has complete lesson TTS generation evidence and
HN4-001 has one script-line record from prior mobile runtime probing, but
HN4-001 through HN4-010 still need batch generation before audio QA can be
closed.

Next safe work is to implement or run an explicit batch generation path through
approved API/admin TTS surfaces, then re-run this audit with URL validation.
Human audio-quality review or an explicit waiver is still required after
machine generation evidence exists.
