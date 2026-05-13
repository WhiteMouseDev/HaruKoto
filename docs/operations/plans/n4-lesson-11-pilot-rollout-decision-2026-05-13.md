# N4 Lesson 11 Pilot Rollout Decision

> Date: 2026-05-13
> Scope: HN4-011 second limited pilot wave
> Decision: LIMITED GO for controlled pilot exposure; DB seed and published list/detail API smoke passed

## Decision

Move HN4-011 from official `DRAFT` source status to `PILOT` source status for a
second controlled N4 pilot wave.

This decision only covers the single HN4-011 lesson:

- `HN4-011` / `N4-CH03` / `い形容詞 stem + さ`
- learner-facing list/detail exposure after configured DB seed apply
- target mobile UAT for one correct path and one wrong-answer retry path

It does not approve broad N4 rollout, marketing as complete N4 coverage, or
native-speaker curriculum validation.

ASSUMPTION: The user-authorized delegated AI curriculum review path is
sufficient for controlled beta exposure, but not equivalent to native-speaker
human approval.

## Gate Evidence

| Gate | Result | Evidence |
|---|---|---|
| Source scope | PASS | 1 N4 seed file, 1 chapter, 1 lesson, 5 questions |
| PDF boundary | PASS | Paid PDFs used only for topic/order reference; examples, dialogue, and questions are HaruKoto-authored |
| Candidate review | PASS | `lsc-n4-i-adjective-nominalization-001` is `APPROVED` with 0 blockers |
| Official review | PASS | `HN4-011` review row is `APPROVED` with 0 blockers |
| Runtime question shape | PASS | Uses existing `VOCAB_MCQ`, `CONTEXT_CLOZE`, and `SENTENCE_REORDER` question types |
| TTS target scope | PASS for target coverage | `lesson-seeds:HN4-011:*` covers 4 script lines and 5 question prompts |
| TTS audio QA | PENDING | Target coverage exists, but generated audio/playback QA is still required before broader rollout |
| Local validation | PASS | Database validation, curriculum validation, review gates, and API policy/TTS tests passed locally |
| Configured DB seed apply | PASS | 3 N4 chapters / 11 lessons / 66 item links applied; HN4-011 seeded as published |
| Configured DB seed check | PASS | 3 N4 chapters / 11 lessons / 0 missing / 0 content mismatches / 0 item-link mismatches |
| Published list/detail API smoke | PASS | N4 list returns 3 chapters / 11 lessons including HN4-011; detail returns 4 script lines / 5 questions / 5 vocab / 1 grammar with answer keys redacted |
| API start/submit write smoke | PENDING | Temporary configured-DB smoke user creation failed on `users.updated_at` NOT NULL/default drift; do not claim start/submit runtime proof yet |
| Mobile lesson-flow regression | PASS | `flutter test` passed lesson session, TTS lesson-target bubble, and practice-step widget tests |
| Simulator availability precheck | PASS | `flutter devices` found the iPhone 17 Pro simulator; wireless physical iPhone was not available |
| Mobile UAT | PENDING | Verify one HN4-011 correct path and one wrong-answer retry path on target runtime |

## Pilot Guardrails

- Keep HN4-011 described as a second limited pilot lesson, not broad N4 launch.
- Watch API/Sentry logs for lesson detail, lesson start, lesson submit, SRS, and
  TTS failures during the pilot window.
- Treat incorrect answer keys, impossible quiz flow, mobile crash, visible TTS
  error, or content that changes the taught grammar meaning as rollback
  triggers.
- Keep raw auth headers, DB URLs, and API tokens out of rollout notes.

## Rollback Path

If HN4-011 shows a P0/P1 runtime or content issue:

1. Change `packages/database/data/lessons/n4/ch03-quality-and-degree.json`
   `meta.status` back to `DRAFT`.
2. Re-run N4 lesson validation, curriculum validation, review gates, and API
   seed policy tests.
3. Re-apply the configured N4 seed so the DB unpublishes HN4-011.
4. Verify N4 published routes return only the first 10 pilot lessons.
5. Record the incident and re-open this decision before resuming exposure.

## Next Gates

1. Resolve or work around configured-DB smoke-user creation for API start/submit write smoke.
2. Run target mobile UAT for the correct path and wrong-answer retry path.
3. Generate or verify HN4-011 TTS audio before any broader N4 rollout.
