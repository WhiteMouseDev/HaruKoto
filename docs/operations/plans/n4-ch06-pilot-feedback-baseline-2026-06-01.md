# N4 Chapter 6 Pilot Feedback Baseline

> Date: 2026-06-01
> Scope: HN4-022 through HN4-026 controlled-pilot aggregate runtime/content
> feedback monitor
> Status: baseline captured; no automatic rollback trigger observed

## Boundary

This is a read-only configured-DB baseline for the N4 CH06 controlled pilot. It
uses aggregate learner/runtime signals only:

- `user_lesson_progress`
- `review_events`
- `tts_audio`

It does not include user emails, auth material, raw DB URLs, API tokens, or
per-user identifiers. It does not replace Cloud Run/Sentry error-log review,
physical-device smoke, native-speaker curriculum review, or native-speaker audio
review.

ASSUMPTION: For the first CH06 automated pilot monitor, aggregate progress,
review events, and TTS records are sufficient to detect obvious rollback signals
such as missing TTS assets, impossible submit flow, or unexpected non-perfect
pilot outcomes. Qualitative learner feedback, Cloud Run/Sentry error review,
physical-device smoke, and native-speaker review remain separate inputs.

The single HN4-022 completion in this baseline aligns with the same-day
simulator target-runtime UAT window. Treat it as non-smoke runtime evidence, not
as proof of organic learner adoption.

## Command

```bash
cd apps/api
for lesson in 22 23 24 25 26; do
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
| `HN4-022` | `후배에게 지도를 그려 줘요` | `true` | 4 | 5 | 1 | 5 | 4/4 script, 5/5 prompts | none |
| `HN4-023` | `선배가 안내해 줬어요` | `true` | 4 | 5 | 0 | 0 | 4/4 script, 5/5 prompts | none |
| `HN4-024` | `주소를 확인해 달라고 했어요` | `true` | 4 | 5 | 0 | 0 | 4/4 script, 5/5 prompts | none |
| `HN4-025` | `예약했는데 자리가 없어요` | `true` | 4 | 5 | 0 | 0 | 4/4 script, 5/5 prompts | none |
| `HN4-026` | `자전거를 도난당했어요` | `true` | 4 | 5 | 0 | 0 | 4/4 script, 5/5 prompts | none |

## Generated Windows

| Lesson | Generated at | Window start |
|---|---|---|
| `HN4-022` | `2026-06-01T05:20:11.851510+00:00` | `2026-05-18T05:20:11.851510+00:00` |
| `HN4-023` | `2026-06-01T05:20:13.062767+00:00` | `2026-05-18T05:20:13.062767+00:00` |
| `HN4-024` | `2026-06-01T05:20:14.086359+00:00` | `2026-05-18T05:20:14.086359+00:00` |
| `HN4-025` | `2026-06-01T05:20:15.130762+00:00` | `2026-05-18T05:20:15.130762+00:00` |
| `HN4-026` | `2026-06-01T05:20:16.123853+00:00` | `2026-05-18T05:20:16.123853+00:00` |

## Learner Progress Signal

| Lesson | Completed | In progress | Perfect | Non-perfect | Total attempts | Average score | First started | Last completed |
|---|---:|---:|---:|---:|---:|---:|---|---|
| `HN4-022` | 1 | 0 | 1 | 0 | 1 | 100.0% | `2026-06-01T04:39:35.605857+00:00` | `2026-06-01T04:41:38.700186+00:00` |
| `HN4-023` | 0 | 0 | 0 | 0 | 0 | n/a | none | none |
| `HN4-024` | 0 | 0 | 0 | 0 | 0 | n/a | none | none |
| `HN4-025` | 0 | 0 | 0 | 0 | 0 | n/a | none | none |
| `HN4-026` | 0 | 0 | 0 | 0 | 0 | n/a | none | none |

## Review Event Signal

| Lesson | Review events | Correct | Incorrect | Average response | Item type counts |
|---|---:|---:|---:|---:|---|
| `HN4-022` | 5 | 5 | 0 | 0 ms | `WORD: 5` |
| `HN4-023` | 0 | 0 | 0 | n/a | none |
| `HN4-024` | 0 | 0 | 0 | n/a | none |
| `HN4-025` | 0 | 0 | 0 | n/a | none |
| `HN4-026` | 0 | 0 | 0 | n/a | none |

## TTS Signal

| Lesson | Script-line TTS | Question-prompt TTS | Provider/model |
|---|---|---|---|
| `HN4-022` | PASS: 4/4 records exist | PASS: 5/5 records exist | `elevenlabs/eleven_multilingual_v2`: 9 |
| `HN4-023` | PASS: 4/4 records exist | PASS: 5/5 records exist | `elevenlabs/eleven_multilingual_v2`: 9 |
| `HN4-024` | PASS: 4/4 records exist | PASS: 5/5 records exist | `elevenlabs/eleven_multilingual_v2`: 9 |
| `HN4-025` | PASS: 4/4 records exist | PASS: 5/5 records exist | `elevenlabs/eleven_multilingual_v2`: 9 |
| `HN4-026` | PASS: 4/4 records exist | PASS: 5/5 records exist | `elevenlabs/eleven_multilingual_v2`: 9 |

## Signals

- `HN4-022`: `PILOT_PROGRESS_OBSERVED`, `REVIEW_EVENTS_OBSERVED`,
  `SCRIPT_LINE_TTS_READY`, and `QUESTION_PROMPT_TTS_READY`.
- `HN4-023` through `HN4-026`: `WAITING_FOR_PILOT_TRAFFIC`,
  `NO_REVIEW_EVENTS`, `SCRIPT_LINE_TTS_READY`, and
  `QUESTION_PROMPT_TTS_READY`.

The waiting state for HN4-023 through HN4-026 is not an automatic rollback
trigger. It means no non-smoke learner progress or review-event rows were
visible for those lessons in the selected 14-day window.

## Blockers

None for this automated baseline.

## Decision

No automatic rollback trigger is observed from the first CH06 aggregate
baseline. HN4-022 through HN4-026 can remain in controlled pilot exposure.

Continue monitoring over time. Broad/full N4 claims remain blocked by
native-speaker review or an explicit later waiver, and release-device claims
remain blocked by physical iPhone smoke.
