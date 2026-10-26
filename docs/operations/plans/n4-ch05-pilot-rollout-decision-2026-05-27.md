# N4 Chapter 5 Pilot Rollout Decision

> Date: 2026-05-27
> Scope: HN4-017 through HN4-021 controlled N4 pilot exposure
> Decision: LIMITED GO for controlled pilot exposure; delegated AI/STT audio QA
> cleared, configured N4 seed registry includes N4-CH05, and representative
> mobile target-runtime UAT plus first aggregate feedback baseline passed

## Decision

Move `N4-CH05` from official `DRAFT` source status to `PILOT` source status
for the next controlled N4 pilot wave.

This decision covers five lessons:

| Lesson | Topic | Grammar anchor |
| --- | --- | --- |
| `HN4-017` | `たり〜たりする` | `〜たり〜たりする` / order 6 |
| `HN4-018` | `そうだ` appearance | `そうだ` / order 14 |
| `HN4-019` | `そうだ` hearsay | `そうだ` / order 14 |
| `HN4-020` | `ものだ` norms | `ものだ` / order 49 |
| `HN4-021` | `はずだ` expectation | `はずだ` / order 13 |

It does not approve broad N4 rollout, marketing as complete N4 coverage, or
native-speaker curriculum validation.

ASSUMPTION: The user-authorized delegated AI/STT audio QA path is sufficient
for controlled beta exposure, but not equivalent to native-speaker human
approval.

## Gate Evidence

| Gate | Result | Evidence |
| --- | --- | --- |
| Source scope | PASS | 1 N4 seed file, 1 chapter, 5 lessons, 25 questions |
| Official review | PASS | `HN4-017` through `HN4-021` review rows are `APPROVED` |
| Runtime question shape | PASS | Uses existing `VOCAB_MCQ`, `CONTEXT_CLOZE`, and `SENTENCE_REORDER` question types |
| TTS target scope | PASS | `lesson-seeds:HN4-017:*` through `lesson-seeds:HN4-021:*` cover 20 script lines and 25 question prompts |
| TTS machine probe | PASS | `docs/operations/plans/n4-wave3-draft-tts-machine-report-2026-05-27.md` reports 45/45 targets probed |
| Delegated audio QA packet | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` reports 45 PASS, 0 PENDING, 0 FLAG, 0 FAIL |
| Residual STT clearance | PASS | `docs/operations/plans/n4-wave3-draft-final-residual-stt-copula-clearance-2026-05-27.md` records final copula-only clearance after source rewrite |
| Seed registry | PASS | `apps/api/app/seeds/lessons.py` includes `ch05-observation-reporting-and-expectation.json` in the configured N4 registry |

## Local Verification

| Gate | Result |
| --- | --- |
| Lesson validation | PASS: 14 chapters, 71 lessons, 0 failures |
| Curriculum validation | PASS: 0 warnings, 0 failures |
| N4 lesson quality gate | PASS: 5 chapters, 21 lessons, 7 PASS / 0 WARN / 0 FAIL |
| Candidate review gate | PASS: 5 APPROVED, 0 blockers |
| Lesson human review gate | PASS: 21 APPROVED, 0 blockers |
| API seed policy tests | PASS: 15 tests |
| API lint/format/typecheck | PASS for `ruff check app/ tests/`, `ruff format --check app/ tests/`, and `mypy app/` |
| Database package typecheck | PASS |
| Configured N4 DB seed apply | PASS after sync: 5 chapters, 21 lessons, `N4-CH05` seeded as `published=True` |
| Configured N4 DB seed check | PASS: 5 chapters, 21 lessons, 0 missing, 0 content mismatches, 0 item link mismatches |
| Published TTS coverage | PASS: 189/189 records present and 189/189 audio URLs checked OK without `--include-unpublished` |
| API lesson flow smoke | PASS for `HN4-017` through `HN4-021`; each correct flow scored 5/5, each wrong flow scored 0/5, and each cleanup left 0 smoke residue rows |
| Mobile target-runtime UAT | PASS for representative `HN4-017` detail, start, vocabulary TTS, dialogue TTS, submit/result, retry, and return-to-learning on iPhone 17 Pro Simulator iOS 26.5; see `docs/operations/plans/n4-ch05-mobile-uat-2026-05-27.md` |
| Pilot feedback baseline | PASS: `docs/operations/plans/n4-ch05-pilot-feedback-baseline-2026-05-27.md` reports no automatic rollback blockers; HN4-017 has one non-smoke completed learner row from the same-day simulator UAT window and HN4-018 through HN4-021 are waiting for pilot traffic with all expected TTS records present |
| Physical-device smoke | BLOCKED: `docs/operations/plans/n4-ch05-physical-device-smoke-2026-05-27.md` confirms the physical iPhone is visible, but install/launch preflight is blocked by device lock before release-device proof can be collected |

## Pilot Guardrails

- Keep HN4-017 through HN4-021 described as a controlled pilot wave, not broad
  N4 launch.
- Watch API/Sentry logs for lesson list/detail, lesson start, lesson submit,
  SRS, and TTS failures during the pilot window.
- Treat impossible quiz flow, answer-key mismatch, mobile crash, visible TTS
  error, or content that changes the taught grammar meaning as rollback
  triggers.
- Keep raw auth headers, DB URLs, and API tokens out of rollout notes.

## Rollback Path

If CH05 shows a P0/P1 runtime or content issue:

1. Change `packages/database/data/lessons/n4/ch05-observation-reporting-and-expectation.json`
   `meta.status` back to `DRAFT`.
2. Remove `ch05-observation-reporting-and-expectation.json` from the configured
   N4 seed registry in `apps/api/app/seeds/lessons.py`.
3. Re-run N4 lesson validation, curriculum validation, review gates, and API
   seed policy tests.
4. Re-apply the configured N4 seed so the DB unpublishes CH05.
5. Verify N4 published routes return only the first 16 pilot lessons.
6. Record the incident and re-open this decision before resuming exposure.

## Next Gates

1. Continue pilot-feedback monitoring refreshes for HN4-017 through HN4-021
   after learner traffic exists.
2. Re-run physical iPhone smoke after the device is unlocked and kept awake.
3. Keep native-speaker review as a quality upgrade gate before wider claims.
