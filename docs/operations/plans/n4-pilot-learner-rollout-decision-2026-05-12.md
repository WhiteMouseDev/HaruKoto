# N4 Pilot Learner Rollout Decision

> Date: 2026-05-12
> Scope: first N4 pilot batch, 2 chapters / 10 lessons
> Decision: LIMITED GO for pilot learner exposure; broad/full N4 rollout HOLD

## Decision

The first N4 pilot batch is approved for limited learner exposure in the current
development/beta path.

This is not approval for broad production marketing, a complete N4 curriculum,
or native-speaker validated curriculum quality. The accepted rollout level is:

- N4 level selection may remain available for internal, development, and limited
  beta learners.
- The 10 `PILOT` lessons may remain publishable in the configured API DB target.
- Runtime telemetry, SRS behavior, wrong-answer retry behavior, and learner
  feedback may be collected against these lessons.

The following are still not approved:

- Presenting HaruKoto as having a complete N4 course.
- Promoting N4 lesson 11+ without a separate coverage/review/UAT wave.
- Treating delegated AI curriculum approval as native-speaker human validation.
- Treating TTS target coverage as full audio quality approval.
- Broad learner rollout without a fresh decision after pilot feedback.

ASSUMPTION: The current rollout target is controlled pilot exposure during the
development phase, not an externally marketed full N4 launch.

## Gate Evidence

| Gate | Result | Evidence |
|---|---|---|
| Source scope | PASS | 2 N4 seed files, 2 chapters, 10 lessons, 50 questions |
| PDF boundary | PASS | Paid PDFs used only for topic/order reference; examples, dialogue, and questions are HaruKoto-authored |
| Seed sync | PASS | Configured DB seed check passed with 2 chapters / 10 lessons / 0 missing / 0 mismatches |
| API smoke | PASS | Authenticated N4 list/detail smoke passed; lesson detail answer keys are redacted |
| TTS target scope | PASS for target coverage | `lesson-seeds:HN4-*` targets cover 40 script lines and 50 question prompts |
| TTS audio QA | PARTIAL | HN4-001 dialogue-line TTS control had no visible mobile error. The 2026-05-13 full published N4 pilot-batch audit found 10/99 generated lesson TTS records overall, with HN4-001 through HN4-010 still incomplete; full batch generation/audio review is still a broad-rollout blocker |
| Curriculum review | PASS for delegated AI path | 10 review packet rows are `APPROVED`; this is not native-speaker validation |
| Mobile happy path | PASS | HN4-001 completed on iPhone 17 Pro Simulator with `100%`, `5/5 정답`, SRS registration, and progress update |
| Mobile wrong-answer path | PASS | HN4-002 completed with one intentional miss, `80%`, `4/5 정답`, wrong-answer explanation, SRS registration, and retry entry |

## Pilot Guardrails

- Keep the batch described as an N4 pilot, not a complete N4 offering.
- Use the current 10 lessons as the only approved N4 learner-facing lesson set.
- Monitor `lesson_list_viewed`, `lesson_started`, `lesson_submitted`,
  `lesson_completed`, and `lesson_retry_clicked` telemetry for N4.
- Watch API/Sentry logs for lesson detail, lesson start, lesson submit, SRS, and
  TTS failures during the pilot window.
- Treat any incorrect answer key, impossible quiz, repeated mobile crash, visible
  TTS error, or content issue that changes the taught grammar meaning as a
  rollback trigger.
- Keep raw auth headers, DB URLs, and API tokens out of rollout notes.

## Rollback Path

If the N4 pilot shows a P0/P1 runtime or content issue:

1. Stop expanding N4 exposure and pause lesson 11+ work.
2. Unpublish or reseed the affected N4 `PILOT` lessons in the configured DB
   target, or hide N4 from the mobile level selector if the issue is client-side.
3. Re-run the N4 seed check, runtime API smoke, and the affected mobile UAT path.
4. Record the incident and re-open this decision before resuming learner exposure.

## Next Gates

- Pilot feedback review after controlled learner exposure.
- Full N4 coverage report before lesson 11+ promotion.
- Native-speaker review when a reviewer becomes available.
- Full lesson-seed TTS generation and audio QA before broad rollout. Current
  audit:
  `docs/operations/plans/n4-pilot-tts-coverage-audit-2026-05-13.md`.
