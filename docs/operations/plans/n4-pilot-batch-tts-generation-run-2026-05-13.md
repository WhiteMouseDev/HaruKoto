# N4 Pilot Batch TTS Generation Run

> Date: 2026-05-13
> Scope: published N4 controlled-pilot lessons, HN4-001 through HN4-011
> Status: generation complete; URL audit passed

## Purpose

Close the generated lesson TTS coverage gap for the published N4 pilot batch
without changing lesson content, lesson publish status, or rollout approval.

ASSUMPTION: Generated `tts_audio` coverage plus URL availability is necessary
but not sufficient for broad/full N4 rollout. Human audio-quality review and the
existing N4 rollout decision gates still apply.

## Generation Path

Generation used the approved lesson TTS service path:

- `generate_lesson_script_line_tts`
- `generate_lesson_question_prompt_tts`
- configured TTS provider call
- configured GCS upload
- `tts_audio` row persistence

The batch helper is idempotent and plans from the current coverage audit before
writing. Existing records are skipped by the underlying lesson TTS service
cache check.

## Commands

```bash
cd apps/api
uv run python scripts/generate_n4_pilot_tts_batch.py --level N4 --limit 5
uv run python scripts/generate_n4_pilot_tts_batch.py \
  --level N4 \
  --limit 1 \
  --execute \
  --sleep-seconds 0
uv run python scripts/generate_n4_pilot_tts_batch.py \
  --level N4 \
  --execute \
  --continue-on-error \
  --sleep-seconds 0.2
uv run python scripts/report_n4_pilot_tts_coverage.py \
  --level N4 \
  --check-audio-urls \
  --fail-on-missing
```

## Result

The first write execution generated one target to verify provider, GCS upload,
and DB persistence:

- `HN4-001 script:1`

The remaining batch execution then planned 88 records and completed with:

- generated: 88
- failed: 0

Final audit result:

| Metric | Result |
|---|---:|
| Generated at | `2026-05-13T04:15:20.775376+00:00` |
| Published N4 lessons audited | 11 |
| Script-line TTS records | 44 / 44 |
| Question-prompt TTS records | 55 / 55 |
| Total TTS records | 99 / 99 |
| Audio URLs checked | 99 |
| Audio URL failures | 0 |
| Provider/model | `elevenlabs/eleven_multilingual_v2`: 99 |

## Remaining Gates

- Human audio-quality review for representative full-chapter playback.
- Continued pilot feedback monitoring.
- Native-speaker curriculum review when available.
- A fresh rollout decision before broad/full N4 launch claims.
