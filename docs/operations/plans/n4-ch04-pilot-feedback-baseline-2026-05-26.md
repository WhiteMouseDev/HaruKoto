# N4 Chapter 4 Pilot Feedback Baseline

> Date: 2026-05-26
> Scope: HN4-012 through HN4-016 controlled-pilot aggregate runtime/content
> feedback monitor
> Status: baseline captured; no automatic rollback trigger observed

## Boundary

This is a read-only configured-DB baseline for the N4 CH04 controlled pilot. It
uses aggregate learner/runtime signals only:

- `user_lesson_progress`
- `review_events`
- `tts_audio`

It does not include user emails, auth material, raw DB URLs, API tokens, or
per-user identifiers. It does not replace Cloud Run/Sentry error-log review,
physical-device smoke, native-speaker curriculum review, or native-speaker audio
review.

ASSUMPTION: For the first CH04 automated pilot monitor, aggregate progress,
review events, and TTS records are sufficient to detect obvious rollback signals
such as missing TTS assets, impossible submit flow, or unexpected non-perfect
pilot outcomes. Qualitative learner feedback, Cloud Run/Sentry error review,
physical-device smoke, and native-speaker review remain separate inputs.

## Command

```bash
cd apps/api
for lesson in 12 13 14 15 16; do
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
| `HN4-012` | `이유를 나란히 말해요` | `true` | 4 | 5 | 1 | 5 | 4/4 script, 5/5 prompts | none |
| `HN4-013` | `한번 확인해 봐요` | `true` | 4 | 5 | 0 | 0 | 4/4 script, 5/5 prompts | none |
| `HN4-014` | `미리 준비해 둬요` | `true` | 4 | 5 | 0 | 0 | 4/4 script, 5/5 prompts | none |
| `HN4-015` | `깜빡 잊어버렸어요` | `true` | 4 | 5 | 0 | 0 | 4/4 script, 5/5 prompts | none |
| `HN4-016` | `연습을 계속해요` | `true` | 4 | 5 | 0 | 0 | 4/4 script, 5/5 prompts | none |

## Generated Windows

| Lesson | Generated at | Window start |
|---|---|---|
| `HN4-012` | `2026-05-26T05:27:34.725488+00:00` | `2026-05-12T05:27:34.725488+00:00` |
| `HN4-013` | `2026-05-26T05:27:36.194996+00:00` | `2026-05-12T05:27:36.194996+00:00` |
| `HN4-014` | `2026-05-26T05:27:37.332508+00:00` | `2026-05-12T05:27:37.332508+00:00` |
| `HN4-015` | `2026-05-26T05:27:38.433664+00:00` | `2026-05-12T05:27:38.433664+00:00` |
| `HN4-016` | `2026-05-26T05:27:39.497768+00:00` | `2026-05-12T05:27:39.497768+00:00` |

## Learner Progress Signal

| Lesson | Completed | In progress | Perfect | Non-perfect | Total attempts | Average score | First started | Last completed |
|---|---:|---:|---:|---:|---:|---:|---|---|
| `HN4-012` | 1 | 0 | 1 | 0 | 1 | 100.0% | `2026-05-26T05:01:20.809479+00:00` | `2026-05-26T05:05:03.633875+00:00` |
| `HN4-013` | 0 | 0 | 0 | 0 | 0 | n/a | none | none |
| `HN4-014` | 0 | 0 | 0 | 0 | 0 | n/a | none | none |
| `HN4-015` | 0 | 0 | 0 | 0 | 0 | n/a | none | none |
| `HN4-016` | 0 | 0 | 0 | 0 | 0 | n/a | none | none |

## Review Event Signal

| Lesson | Review events | Correct | Incorrect | Average response | Item type counts |
|---|---:|---:|---:|---:|---|
| `HN4-012` | 5 | 5 | 0 | 0 ms | `WORD: 5` |
| `HN4-013` | 0 | 0 | 0 | n/a | none |
| `HN4-014` | 0 | 0 | 0 | n/a | none |
| `HN4-015` | 0 | 0 | 0 | n/a | none |
| `HN4-016` | 0 | 0 | 0 | n/a | none |

## TTS Signal

| Lesson | Script-line TTS | Question-prompt TTS | Provider/model |
|---|---|---|---|
| `HN4-012` | PASS: 4/4 records exist | PASS: 5/5 records exist | `elevenlabs/eleven_multilingual_v2`: 9 |
| `HN4-013` | PASS: 4/4 records exist | PASS: 5/5 records exist | `elevenlabs/eleven_multilingual_v2`: 9 |
| `HN4-014` | PASS: 4/4 records exist | PASS: 5/5 records exist | `elevenlabs/eleven_multilingual_v2`: 9 |
| `HN4-015` | PASS: 4/4 records exist | PASS: 5/5 records exist | `elevenlabs/eleven_multilingual_v2`: 9 |
| `HN4-016` | PASS: 4/4 records exist | PASS: 5/5 records exist | `elevenlabs/eleven_multilingual_v2`: 9 |

## Signals

- `HN4-012`: `PILOT_PROGRESS_OBSERVED`, `REVIEW_EVENTS_OBSERVED`,
  `SCRIPT_LINE_TTS_READY`, and `QUESTION_PROMPT_TTS_READY`.
- `HN4-013` through `HN4-016`: `WAITING_FOR_PILOT_TRAFFIC`,
  `NO_REVIEW_EVENTS`, `SCRIPT_LINE_TTS_READY`, and
  `QUESTION_PROMPT_TTS_READY`.

The waiting state for HN4-013 through HN4-016 is not an automatic rollback
trigger. It means no non-smoke learner progress or review-event rows were
visible for those lessons in the selected 14-day window.

## Blockers

None for this automated baseline.

## Decision

No automatic rollback trigger is observed from the first CH04 aggregate
baseline. HN4-012 through HN4-016 can remain in controlled pilot exposure.

Continue monitoring over time. Broad/full N4 claims remain blocked by
native-speaker review or an explicit later waiver, and release-device claims
remain blocked by physical iPhone smoke.
