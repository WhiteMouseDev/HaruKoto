# N4 Chapter 5 Pilot Feedback Baseline

> Date: 2026-05-27
> Scope: HN4-017 through HN4-021 controlled-pilot aggregate runtime/content
> feedback monitor
> Status: baseline captured; no automatic rollback trigger observed

## Boundary

This is a read-only configured-DB baseline for the N4 CH05 controlled pilot. It
uses aggregate learner/runtime signals only:

- `user_lesson_progress`
- `review_events`
- `tts_audio`

It does not include user emails, auth material, raw DB URLs, API tokens, or
per-user identifiers. It does not replace Cloud Run/Sentry error-log review,
physical-device smoke, native-speaker curriculum review, or native-speaker audio
review.

ASSUMPTION: For the first CH05 automated pilot monitor, aggregate progress,
review events, and TTS records are sufficient to detect obvious rollback signals
such as missing TTS assets, impossible submit flow, or unexpected non-perfect
pilot outcomes. Qualitative learner feedback, Cloud Run/Sentry error review,
physical-device smoke, and native-speaker review remain separate inputs.

The single HN4-017 completion in this baseline aligns with the same-day
simulator target-runtime UAT window. Treat it as non-smoke runtime evidence, not
as proof of organic learner adoption.

## Command

```bash
cd apps/api
for lesson in 17 18 19 20 21; do
  label=$(printf 'HN4-%03d' "$lesson")
  uv run python scripts/report_lesson_pilot_feedback.py \
    --level N4 \
    --lesson-no "$lesson" \
    --label "$label" \
    --since-days 14 \
    --json
done
```

## Baseline Output

| Lesson | Title | Published | Script lines | Questions | Progress rows | Review events | TTS records | Blockers |
|---|---|---:|---:|---:|---:|---:|---|---|
| `HN4-017` | `주말에 이것저것 해요` | `true` | 4 | 5 | 1 | 5 | 4/4 script, 5/5 prompts | none |
| `HN4-018` | `곧 고장 날 것 같아요` | `true` | 4 | 5 | 0 | 0 | 4/4 script, 5/5 prompts | none |
| `HN4-019` | `회의가 세 시라던데요` | `true` | 4 | 5 | 0 | 0 | 4/4 script, 5/5 prompts | none |
| `HN4-020` | `약속은 지키는 법이에요` | `true` | 4 | 5 | 0 | 0 | 4/4 script, 5/5 prompts | none |
| `HN4-021` | `예약했으니 자리 있을 거예요` | `true` | 4 | 5 | 0 | 0 | 4/4 script, 5/5 prompts | none |

## Generated Windows

| Lesson | Generated at | Window start |
|---|---|---|
| `HN4-017` | `2026-05-27T08:31:53.134619+00:00` | `2026-05-13T08:31:53.134619+00:00` |
| `HN4-018` | `2026-05-27T08:31:54.634273+00:00` | `2026-05-13T08:31:54.634273+00:00` |
| `HN4-019` | `2026-05-27T08:31:55.818663+00:00` | `2026-05-13T08:31:55.818663+00:00` |
| `HN4-020` | `2026-05-27T08:31:56.976517+00:00` | `2026-05-13T08:31:56.976517+00:00` |
| `HN4-021` | `2026-05-27T08:31:58.225745+00:00` | `2026-05-13T08:31:58.225745+00:00` |

## Learner Progress Signal

| Lesson | Completed | In progress | Perfect | Non-perfect | Total attempts | Average score | First started | Last completed |
|---|---:|---:|---:|---:|---:|---:|---|---|
| `HN4-017` | 1 | 0 | 1 | 0 | 1 | 100.0% | `2026-05-27T07:33:43.689119+00:00` | `2026-05-27T07:38:11.190434+00:00` |
| `HN4-018` | 0 | 0 | 0 | 0 | 0 | n/a | none | none |
| `HN4-019` | 0 | 0 | 0 | 0 | 0 | n/a | none | none |
| `HN4-020` | 0 | 0 | 0 | 0 | 0 | n/a | none | none |
| `HN4-021` | 0 | 0 | 0 | 0 | 0 | n/a | none | none |

## Review Event Signal

| Lesson | Review events | Correct | Incorrect | Average response | Item type counts |
|---|---:|---:|---:|---:|---|
| `HN4-017` | 5 | 5 | 0 | 0 ms | `WORD: 5` |
| `HN4-018` | 0 | 0 | 0 | n/a | none |
| `HN4-019` | 0 | 0 | 0 | n/a | none |
| `HN4-020` | 0 | 0 | 0 | n/a | none |
| `HN4-021` | 0 | 0 | 0 | n/a | none |

## TTS Signal

| Lesson | Script-line TTS | Question-prompt TTS | Provider/model |
|---|---|---|---|
| `HN4-017` | PASS: 4/4 records exist | PASS: 5/5 records exist | `elevenlabs/eleven_multilingual_v2`: 9 |
| `HN4-018` | PASS: 4/4 records exist | PASS: 5/5 records exist | `elevenlabs/eleven_multilingual_v2`: 8, `gemini/gemini-2.5-flash-preview-tts`: 1 |
| `HN4-019` | PASS: 4/4 records exist | PASS: 5/5 records exist | `elevenlabs/eleven_multilingual_v2`: 8, `gemini/gemini-2.5-flash-preview-tts`: 1 |
| `HN4-020` | PASS: 4/4 records exist | PASS: 5/5 records exist | `elevenlabs/eleven_multilingual_v2`: 7, `gemini/gemini-2.5-flash-preview-tts`: 2 |
| `HN4-021` | PASS: 4/4 records exist | PASS: 5/5 records exist | `elevenlabs/eleven_multilingual_v2`: 7, `gemini/gemini-2.5-flash-preview-tts`: 2 |

## Signals

- `HN4-017`: `PILOT_PROGRESS_OBSERVED`, `REVIEW_EVENTS_OBSERVED`,
  `SCRIPT_LINE_TTS_READY`, and `QUESTION_PROMPT_TTS_READY`.
- `HN4-018` through `HN4-021`: `WAITING_FOR_PILOT_TRAFFIC`,
  `NO_REVIEW_EVENTS`, `SCRIPT_LINE_TTS_READY`, and
  `QUESTION_PROMPT_TTS_READY`.

The waiting state for HN4-018 through HN4-021 is not an automatic rollback
trigger. It means no non-smoke learner progress or review-event rows were
visible for those lessons in the selected 14-day window.

## Blockers

None for this automated baseline.

## Decision

No automatic rollback trigger is observed from the first CH05 aggregate
baseline. HN4-017 through HN4-021 can remain in controlled pilot exposure.

Continue monitoring over time. Broad/full N4 claims remain blocked by
native-speaker review or an explicit later waiver, and release-device claims
remain blocked by physical iPhone smoke.
