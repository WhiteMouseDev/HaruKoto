# N4 Lesson 11 Pilot Rollout Decision

> Date: 2026-05-13
> Scope: HN4-011 second limited pilot wave
> Decision: LIMITED GO for controlled pilot exposure; DB seed, API smoke, lesson TTS audio QA, and simulator mobile UAT passed

## Decision

Move HN4-011 from official `DRAFT` source status to `PILOT` source status for a
second controlled N4 pilot wave.

This decision only covers the single HN4-011 lesson:

- `HN4-011` / `N4-CH03` / `い形容詞 stem + さ`
- learner-facing list/detail exposure after configured DB seed apply
- simulator mobile UAT for submit/result handling, visible retry, and a retry
  correct path

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
| TTS audio QA | PASS for HN4-011 lesson TTS | HN4-011 generated 4/4 dialogue script-line MP3s and 5/5 question-prompt MP3s through the lesson TTS API/service path; each URL returned `200 audio/mpeg` and decoded as MP3 |
| Local validation | PASS | Database validation, curriculum validation, review gates, database typecheck, full API pytest, and full mobile widget/unit tests passed locally |
| Configured DB seed apply | PASS | 3 N4 chapters / 11 lessons / 66 item links applied; HN4-011 seeded as published |
| Configured DB seed check | PASS | 3 N4 chapters / 11 lessons / 0 missing / 0 content mismatches / 0 item-link mismatches |
| Published list/detail API smoke | PASS | N4 list returns 3 chapters / 11 lessons including HN4-011; detail returns 4 script lines / 5 questions / 5 vocab / 1 grammar with answer keys redacted |
| API start/submit write smoke | PASS | `apps/api/scripts/smoke_lesson_flow.py --level N4 --lesson-no 11 --label HN4-011` completed correct submit 5/5 and wrong submit 0/5; each path registered 6 SRS items, wrote review events, and cleanup left 0 smoke residue rows |
| Mobile lesson-flow regression | PASS | `flutter test` passed 526 tests, including lesson session, TTS lesson-target bubble, and practice-step widget coverage |
| Mobile target-runtime UAT | PASS on simulator target | `docs/operations/plans/n4-lesson-11-mobile-uat-2026-05-13.md`: iPhone 17 Pro Simulator opened HN4-011, started the lesson, triggered line-0 TTS `200`, reached a `4/5` result screen with review/retry UI, retried from the lesson detail screen, submitted a corrected `5/5` path, and returned to the learning surface |
| Pilot feedback baseline | PASS for first aggregate monitor | `docs/operations/plans/n4-lesson-11-pilot-feedback-baseline-2026-05-13.md`: 1 non-smoke learner progress row, 30 review events, script-line TTS 4/4, question-prompt TTS 5/5, and no automatic rollback trigger observed |
| Pilot feedback refresh | PASS for aggregate refresh | `docs/operations/plans/n4-lesson-11-pilot-feedback-refresh-2026-05-13.md`: counters match the first baseline, no new aggregate traffic is visible, and no automatic rollback trigger observed |

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

1. Continue monitoring the controlled learner pilot for HN4-011 runtime/content
   feedback as more traffic arrives. The first refresh is recorded in
   `docs/operations/plans/n4-lesson-11-pilot-feedback-refresh-2026-05-13.md`.
2. Keep full N4 lesson-seed batch TTS generation and human audio-quality review
   as broad-rollout blockers.
3. Re-run physical-device smoke before release-artifact claims if this simulator
   evidence needs to become device-release evidence.
