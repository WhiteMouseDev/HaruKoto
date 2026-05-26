# N5 TTS Manifest Backfill

> Date: 2026-05-26
> Scope: HN5-001 through HN5-030 official lesson-seed TTS target coverage
> Status: PASS for manifest coverage
> Boundary: not audio generation, not persisted `tts_audio`, not audio QA

## Boundary

This closes the N5 source-manifest gap where HN5-001 through HN5-030 official
lessons had no `lesson-seeds:*` script-line or question-prompt TTS targets.

It does not generate audio, write `tts_audio` rows, upload files, or claim that
learners can play approved audio for these rows yet.

ASSUMPTION: For official lesson seeds that were not promoted from
`lesson-seed-candidates.json`, the lesson grammar topic mapping is the
authoritative topic source for manifest grouping.

## Change Summary

| Area | Result |
|---|---|
| New HN5-001 through HN5-030 script targets | 120 |
| New HN5-001 through HN5-030 question prompt targets | 150 |
| Total new targets | 270 |
| N5 lesson-human-review script coverage | 198 / 198 |
| N5 lesson-human-review question prompt coverage | 250 / 250 |
| TTS target manifest total | 928 targets |
| Seed script review batch total | 262 targets |
| Seed question review batch total | 330 targets |
| API mirror bundles | Updated with the same manifest and review batches |

## Implementation Notes

- `derive-curriculum-topics.mjs` now derives official lesson-seed TTS targets
  for both seed-candidate-promoted lessons and existing official lesson JSON.
- Existing official lessons without a promoted seed candidate use the grammar
  topic mapping as their `topicId` source.
- N5 grammar orders 51, 52, 53, and 54 were mapped into existing curriculum
  topics so HN5-025, HN5-027, HN5-028, and HN5-029 have deterministic topic
  grouping.
- `validate-curriculum-contracts.mjs` now validates official lesson-seed TTS
  targets against either the promoted seed candidate topic or the grammar topic
  mapping.

## Validation

| Gate | Result |
|---|---|
| Curriculum derivation | PASS: 928 TTS targets |
| N5 review packet regeneration | PASS: 198/198 script, 250/250 question targets |
| N5 review approval gate | PASS: 50 approved, 0 blockers |
| Curriculum contract validation | PASS: 0 warnings, 0 failures |
| Lesson schema/reference validation | PASS: 13 chapters, 66 lessons, 330 questions |
| N5 strict quality gate | PASS: 7 PASS / 0 WARN / 0 FAIL |
| Database package typecheck | PASS |
| API lesson seed policy tests | PASS: 15 tests |
| API admin TTS review batch tests | PASS: 42 tests |
| API full test suite | PASS: 539 passed, 13 skipped |

## Commands

```bash
pnpm --filter @harukoto/database curriculum:derive
pnpm --filter @harukoto/database lessons:review:prepare -- --level N5
pnpm --filter @harukoto/database lessons:review:gate -- --level N5
pnpm --filter @harukoto/database curriculum:validate
pnpm --filter @harukoto/database lessons:validate
pnpm --filter @harukoto/database lessons:quality -- --level N5 --strict-warnings
pnpm --filter @harukoto/database typecheck
cd apps/api && uv run pytest tests/test_lesson_seed_policy.py -q
cd apps/api && uv run pytest tests/test_admin_tts_review_batches_service.py tests/test_admin_tts.py -q
cd apps/api && uv run pytest
```

## Remaining Gates

1. Generate or backfill actual TTS audio for the missing N5 lesson script and
   question prompt targets through the existing API service path.
2. Run audio QA/STT/direct-listen review before marking audio readiness.
3. Run mobile target-runtime UAT for N5 lesson playback paths.
