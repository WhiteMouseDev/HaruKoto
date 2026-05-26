# N4 Chapter 4 Pilot Rollout Decision

> Date: 2026-05-20
> Scope: HN4-012 through HN4-016 controlled N4 pilot exposure
> Decision: LIMITED GO for controlled pilot exposure; delegated AI/STT audio QA cleared and configured N4 seed registry now includes N4-CH04

## Decision

Move `N4-CH04` from official `DRAFT` source status to `PILOT` source status
for the next controlled N4 pilot wave.

This decision covers five lessons:

| Lesson | Topic | Grammar anchor |
|---|---|---|
| `HN4-012` | `し` | `〜し` / order 24 |
| `HN4-013` | `てみる` | `Vて + みる` / order 4 |
| `HN4-014` | `ておく` | `Vて + おく` / order 3 |
| `HN4-015` | `てしまう` | `Vて + しまう` / order 1 |
| `HN4-016` | `つづける` | `Vます stem + 続ける` / order 35 |

It does not approve broad N4 rollout, marketing as complete N4 coverage, or
native-speaker curriculum validation.

ASSUMPTION: The user-authorized delegated AI/STT audio QA path is sufficient
for controlled beta exposure, but not equivalent to native-speaker human
approval.

## Gate Evidence

| Gate | Result | Evidence |
|---|---|---|
| Source scope | PASS | 1 N4 seed file, 1 chapter, 5 lessons, 25 questions |
| Official review | PASS | `HN4-012` through `HN4-016` review rows are `APPROVED` |
| Runtime question shape | PASS | Uses existing `VOCAB_MCQ`, `CONTEXT_CLOZE`, and `SENTENCE_REORDER` question types |
| TTS target scope | PASS | `lesson-seeds:HN4-012:*` through `lesson-seeds:HN4-016:*` cover 20 script lines and 25 question prompts |
| TTS machine probe | PASS | `docs/operations/plans/n4-wave2-draft-tts-machine-report-2026-05-20.md` reports 45/45 targets probed |
| Delegated audio QA packet | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` reports 45 PASS, 0 PENDING, 0 FLAG, 0 FAIL |
| Source rewrite closure | PASS | `docs/operations/plans/n4-wave2-draft-flag-source-rewrite-closure-2026-05-20.md` closes the remaining 3 FLAG rows after regeneration |
| Seed registry | PASS | `apps/api/app/seeds/lessons.py` includes `ch04-everyday-action-extensions.json` in the configured N4 registry |

## Local Verification

| Gate | Result |
|---|---|
| Lesson validation | PASS: 13 chapters, 66 lessons, 0 failures |
| Curriculum validation | PASS: 0 warnings, 0 failures |
| N4 lesson quality gate | PASS: 4 chapters, 16 lessons, 7 PASS / 0 WARN / 0 FAIL |
| API seed policy tests | PASS: 15 tests |
| Database package typecheck | PASS |
| Configured N4 DB seed check | PASS after sync: 4 chapters, 16 lessons, 0 missing, 0 content mismatches, 0 item link mismatches |
| API lesson flow smoke | PASS for `HN4-012` through `HN4-016`; each correct flow scored 5/5, each wrong flow scored 0/5, and each cleanup left 0 smoke residue rows |

The first API flow smoke attempt returned 404 for the new lessons before the
local DB seed sync. That confirmed the source change alone was not enough for
the already-seeded local database. Running `python -m app.seeds.lessons --level
N4` updated `N4-CH04` to `published=True`; the configured check and smoke tests
then passed.

## Target Environment Evidence

| Gate | Result | Evidence |
|---|---|---|
| Published list/detail API smoke | PASS | `docs/operations/plans/n4-ch04-target-api-smoke-2026-05-20.md` reports 4 N4 chapters, 16 N4 lessons, and PASS detail checks for `HN4-012` through `HN4-016` |
| Mobile target-runtime UAT | PASS | `docs/operations/plans/n4-ch04-mobile-uat-2026-05-26.md` reports HN4-012 detail, start, TTS entry, submit/result, retry, and return-to-learning PASS on iPhone 17 Pro Simulator, iOS 26.5 |

## Pilot Guardrails

- Keep HN4-012 through HN4-016 described as a controlled pilot wave, not broad
  N4 launch.
- Watch API/Sentry logs for lesson list/detail, lesson start, lesson submit,
  SRS, and TTS failures during the pilot window.
- Treat impossible quiz flow, answer-key mismatch, mobile crash, visible TTS
  error, or content that changes the taught grammar meaning as rollback
  triggers.
- Keep raw auth headers, DB URLs, and API tokens out of rollout notes.

## Rollback Path

If CH04 shows a P0/P1 runtime or content issue:

1. Change `packages/database/data/lessons/n4/ch04-everyday-action-extensions.json`
   `meta.status` back to `DRAFT`.
2. Remove `ch04-everyday-action-extensions.json` from the configured N4 seed
   registry in `apps/api/app/seeds/lessons.py`.
3. Re-run N4 lesson validation, curriculum validation, review gates, and API
   seed policy tests.
4. Re-apply the configured N4 seed so the DB unpublishes CH04.
5. Verify N4 published routes return only the first 11 pilot lessons.
6. Record the incident and re-open this decision before resuming exposure.

## Next Gates

1. Monitor pilot logs for lesson list/detail, start, submit/result, SRS, and TTS
   failures during the controlled CH04 exposure window.
2. Run physical iPhone smoke before making release-device claims.
3. Keep native-speaker review as a quality upgrade gate before wider claims.
