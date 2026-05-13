# N4 Pilot TTS Coverage Audit

> Date: 2026-05-13
> Scope: published N4 controlled-pilot lessons, HN4-001 through HN4-011
> Status: generated TTS coverage complete; human audio-quality QA still required for broad/full N4 rollout

## Boundary

This is a configured-DB audit for generated lesson TTS records after the
approved batch generation path was run. It checks existing `tts_audio` rows for:

- `lesson_script_line` / `script_line`
- `lesson_question_prompt` / `question_prompt`

The audit command itself does not call the TTS provider, write `tts_audio`,
upload audio, or mark any content as human audio-quality approved.

ASSUMPTION: For broad/full N4 rollout planning, a generated `tts_audio` row plus
read-only URL availability is necessary but not sufficient. Human
audio-quality review remains a separate gate.

## Command

```bash
cd apps/api
uv run python scripts/report_n4_pilot_tts_coverage.py \
  --level N4 \
  --check-audio-urls \
  --fail-on-missing
```

Generation run record:
`docs/operations/plans/n4-pilot-batch-tts-generation-run-2026-05-13.md`.

## Summary

| Metric | Result |
|---|---:|
| Generated at | `2026-05-13T04:15:20.775376+00:00` |
| Published N4 lessons audited | 11 |
| Expected script-line TTS records | 44 |
| Generated script-line TTS records | 44 |
| Expected question-prompt TTS records | 55 |
| Generated question-prompt TTS records | 55 |
| Expected total TTS records | 99 |
| Generated total TTS records | 99 |
| Audio URLs checked | 99 |
| Audio URL failures | 0 |
| Provider/model | `elevenlabs/eleven_multilingual_v2`: 99 |

## Lesson Coverage

| Lesson | Script lines | Question prompts | Status |
|---|---:|---:|---|
| HN4-001 | 4 / 4 | 5 / 5 | Generated records present |
| HN4-002 | 4 / 4 | 5 / 5 | Generated records present |
| HN4-003 | 4 / 4 | 5 / 5 | Generated records present |
| HN4-004 | 4 / 4 | 5 / 5 | Generated records present |
| HN4-005 | 4 / 4 | 5 / 5 | Generated records present |
| HN4-006 | 4 / 4 | 5 / 5 | Generated records present |
| HN4-007 | 4 / 4 | 5 / 5 | Generated records present |
| HN4-008 | 4 / 4 | 5 / 5 | Generated records present |
| HN4-009 | 4 / 4 | 5 / 5 | Generated records present |
| HN4-010 | 4 / 4 | 5 / 5 | Generated records present |
| HN4-011 | 4 / 4 | 5 / 5 | Generated records present |

## Signals

- `SCRIPT_LINE_TTS_RECORDS_READY`: 44 / 44 records exist.
- `QUESTION_PROMPT_TTS_RECORDS_READY`: 55 / 55 records exist.
- `PILOT_BATCH_TTS_RECORDS_READY`: all expected script-line and question-prompt
  records exist.
- `AUDIO_URLS_READY`: 99 / 99 checked generated URLs passed read-only HTTP
  validation.

## Blockers

None from generated-record or URL-availability coverage.

## Decision

The current N4 pilot batch now has complete generated lesson TTS coverage from a
records-and-URL standpoint. All 44 script-line targets and 55 question-prompt
targets exist in `tts_audio`, and all 99 generated URLs pass read-only HTTP
validation.

This closes the machine-generation blocker that previously held 89 missing
records. It does not close human audio-quality review, native-speaker curriculum
review, or broader N4 rollout approval. Human audio-quality review or an
explicit waiver is still required before broad/full rollout.

The follow-up machine audio preflight is recorded separately in
`docs/operations/plans/n4-pilot-tts-audio-quality-preflight-2026-05-13.md`.
