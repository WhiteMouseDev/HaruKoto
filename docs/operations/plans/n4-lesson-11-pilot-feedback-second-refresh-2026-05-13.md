# N4 Lesson 11 Pilot Feedback Second Refresh

> Date: 2026-05-13
> Scope: HN4-011 controlled-pilot runtime/content feedback monitor second refresh
> Status: refresh captured; no automatic rollback trigger observed

## Boundary

This is a read-only configured-DB refresh for the HN4-011 controlled pilot. It
uses aggregate learner/runtime signals only:

- `user_lesson_progress`
- `review_events`
- `tts_audio`

It does not include user emails, auth material, raw DB URLs, or per-user
identifiers. It does not replace native-speaker curriculum review, qualitative
learner feedback, or human audio-quality review.

ASSUMPTION: A repeated same-day aggregate monitor is useful for detecting newly
visible runtime/content rollback signals, but it is not a final broad-rollout
approval signal.

## Command

```bash
cd apps/api
uv run python scripts/report_lesson_pilot_feedback.py \
  --level N4 \
  --lesson-no 11 \
  --label HN4-011 \
  --since-days 14 \
  --json
```

## Refresh Output

| Area | Result |
|---|---|
| Generated at | `2026-05-13T06:43:16.414286+00:00` |
| Window start | `2026-04-29T06:43:16.414286+00:00` |
| Lesson | `HN4-011` / `03cfdb15-c916-450c-8168-9052f3e754aa` |
| Title | `종이의 두께를 비교해요` |
| Topic | `い형용사의 명사화` |
| Published | `true` |
| Script lines | 4 |
| Questions | 5 |

## Learner Progress Signal

| Metric | Value |
|---|---:|
| Non-smoke learner progress rows | 1 |
| Completed rows | 1 |
| In-progress rows | 0 |
| Perfect-score rows | 1 |
| Non-perfect-score rows | 0 |
| Total attempts | 6 |
| Max attempts | 6 |
| Average score | 100.0% |
| First started | `2026-05-13T01:29:03.444468+00:00` |
| Last completed | `2026-05-13T03:15:11.696713+00:00` |
| Last updated | `2026-05-13T03:15:11.207857+00:00` |

## Review Event Signal

| Metric | Value |
|---|---:|
| Review events | 30 |
| Correct events | 23 |
| Incorrect events | 7 |
| Average response | 167 ms |
| First event | `2026-05-13T01:29:03.606686+00:00` |
| Last event | `2026-05-13T03:15:11.207857+00:00` |
| Item type counts | `WORD: 30` |

## TTS Signal

| Target | Result |
|---|---|
| Learner-facing script-line TTS | PASS: 4/4 records exist |
| Provider/model | `elevenlabs/eleven_multilingual_v2`: 9 |
| Missing script-line indices | none |
| Question-prompt TTS | PASS: 5/5 records exist |
| Missing question-prompt orders | none |

## Comparison To Earlier Refresh

The aggregate counters still match
`docs/operations/plans/n4-lesson-11-pilot-feedback-refresh-2026-05-13.md`:

- 1 non-smoke learner progress row
- 30 review events
- 4/4 script-line TTS records
- 5/5 question-prompt TTS records
- 0 automatic rollback blockers

This means no new aggregate learner traffic is visible in the selected window
since the earlier refresh, and no new automated rollback signal appeared.

## Signals

- `PILOT_PROGRESS_OBSERVED`: 1 learner row, 1 completed, average score 100.0%.
- `REVIEW_EVENTS_OBSERVED`: 30 events, 23 correct, 7 incorrect.
- `SCRIPT_LINE_TTS_READY`: all expected learner-facing script-line TTS records
  exist.
- `QUESTION_PROMPT_TTS_READY`: all expected lesson question prompt TTS records
  exist.

## Blockers

None for this automated refresh.

## Decision

No automatic rollback trigger is observed from the second refreshed aggregate
data. HN4-011 can remain in controlled limited-pilot exposure.

Broad/full N4 rollout remains on HOLD until:

1. More pilot feedback is reviewed over time.
2. Native-speaker review is available or explicitly waived for a later decision.
3. Human audio-quality verdicts for the prepared N4 TTS review packets are
   completed and any `FLAG` or `FAIL` items are resolved or waived.
