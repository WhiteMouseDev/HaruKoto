# N4 Wave 3 Draft Lesson Promotion - 2026-05-27

> Scope: promote AI-reviewed N4 wave 3 seed candidates into official DRAFT
> lesson source rows `HN4-017` through `HN4-021`.

## Decision

Promote the five approved N4 wave 3 seed candidates into a new official
DRAFT chapter, `N4-CH05`:

| Lesson | Topic | Grammar order | Status |
| --- | --- | --- | --- |
| `HN4-017` | `たり〜たりする` | 6 | official DRAFT source |
| `HN4-018` | `そうだ` appearance | 14 | official DRAFT source |
| `HN4-019` | `そうだ` hearsay | 14 | official DRAFT source |
| `HN4-020` | `ものだ` norms | 49 | official DRAFT source |
| `HN4-021` | `はずだ` expectation | 13 | official DRAFT source |

The source PDF materials are used only as coverage anchors. Dialogue lines,
questions, answer choices, and explanations remain HaruKoto-authored content.

## Boundary

This is not a publish/pilot decision. `N4-CH05` stays `meta.status=DRAFT`, so
it is visible to package-level curriculum validators and review packets, but
it is not added to the default API lesson seed registry for learner exposure.

The approval evidence is delegated AI curriculum review only:

- candidate review packet: approved for candidate-to-official-seed planning.
- lesson-human-review packet: approved for source-level DRAFT promotion.
- TTS manifest: complete official `lesson-seeds:HN4-017..021` target coverage.
- not native-speaker human approval.
- not generated audio approval.
- not target-runtime mobile or API playback approval.

## Contract Changes

- `packages/database/data/lessons/n4/ch05-observation-reporting-and-expectation.json`
  stores the official DRAFT chapter.
- `packages/database/data/curriculum/tts-target-manifest.json` and
  `apps/api/app/data/curriculum/tts-target-manifest.json` replace the former
  `lesson-seed-candidates:lsc-n4-*` script/question target sources with
  official `lesson-seeds:HN4-*` sources.
- `packages/database/data/curriculum/tts-review-batches.json` and
  `apps/api/app/data/curriculum/tts-review-batches.json` keep the same review
  batch counts while pointing the gap batches at the official target IDs.
- `packages/database/data/curriculum/lesson-seed-candidate-review/n4-candidate-review.json`
  preserves the candidate approval evidence and records each promoted
  `HN4-*` lesson ID.
- `packages/database/data/curriculum/lesson-human-review/n4-pilot-review.json`
  now covers 21 N4 official lesson source rows, including AI-only approval
  notes for `HN4-017` through `HN4-021`.

## AI Review Refinements

Parallel AI review found no blocker, but three source-level refinements were
applied before final validation:

- `HN4-017` question 4 now includes a Korean hint so the answer is not based
  only on dialogue recall.
- `HN4-018` uses `大変そうです` instead of `疲れていそうです` to keep the
  appearance lesson on simpler adjective-stem `そう` formation.
- `HN4-021` meaning text now marks `はずだ` as evidence-based expectation, not
  a plain future marker.

## Validation Plan

Run the package gates after the promotion:

| Gate | Expected result |
| --- | --- |
| `pnpm --filter @harukoto/database candidates:review:gate -- --level N4` | PASS |
| `pnpm --filter @harukoto/database lessons:review:gate -- --level N4` | PASS with AI-only notes |
| `pnpm --filter @harukoto/database lessons:validate` | PASS with expected DRAFT warning for `N4-CH05` |
| `pnpm --filter @harukoto/database curriculum:validate` | PASS |
| `pnpm --filter @harukoto/database typecheck` | PASS |
| API TTS focused tests | PASS |

## Next Gates

1. Generate and persist TTS audio for `HN4-017` through `HN4-021`.
2. Run delegated AI/STT audio QA, then record PASS/FLAG/FAIL evidence.
3. Promote `N4-CH05` from `DRAFT` to `PILOT` only after audio QA and seed
   registry decision are complete.
4. Keep native-speaker review as a later, explicit quality upgrade when a human
   reviewer becomes available.
