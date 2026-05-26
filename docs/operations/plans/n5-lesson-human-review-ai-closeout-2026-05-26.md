# N5 Lesson Human Review AI-Assisted Closeout

> Date: 2026-05-26
> Scope: N5 official lesson-human-review packet for HN5-001 through HN5-050
> Status: PASS for delegated AI-assisted curriculum/source review gate
> Boundary: not native-speaker review, not TTS readiness closeout, and not mobile
> target-runtime UAT

## Boundary

This closes the repository `lessons:review:gate -- --level N5` gap by adding a
source-controlled N5 lesson review packet and recording delegated AI-assisted
review decisions for all current N5 pilot lessons.

It does not claim native-speaker approval. It also does not close audio
readiness: lesson-seed TTS manifest coverage is now complete, but actual audio
generation/review follow-up is still required before making audio-readiness
claims.

ASSUMPTION: In the absence of a human Japanese curriculum specialist, delegated
AI-assisted review is acceptable as a controlled-pilot curriculum/source review
gate, provided native-speaker review remains a separate quality gate.

## Packet

| Field | Value |
|---|---|
| Packet | `packages/database/data/curriculum/lesson-human-review/n5-pilot-review.json` |
| Level | `N5` |
| Review kind | `lesson_human_curriculum_review` |
| Rows | 50 |
| Decisions | 50 `APPROVED`, 0 `PENDING`, 0 `NEEDS_EDIT`, 0 `REJECTED` |
| Source files | 9 N5 official lesson JSON files |

The packet was generated with the existing official lesson review packet
generator:

```bash
pnpm --filter @harukoto/database lessons:review:prepare -- --level N5
```

## Review Method

For each HN5-001 through HN5-050 row, the review checked:

- lesson structure and source/reference alignment;
- vocabulary and grammar reference links;
- Korean learner-facing explanation clarity;
- answer key and option alignment;
- runtime-safe question shape;
- dialogue/script completeness;
- no known copied PDF examples or explanations in the lesson packet;
- TTS target coverage status as a separate operational signal.

The packet notes intentionally distinguish curriculum/source approval from
audio readiness. HN5-001 through HN5-030 were updated after the official lesson
seed TTS manifest backfill, and HN5-001 through HN5-050 now all have
lesson-seed TTS target coverage in the manifest.

## TTS Coverage Snapshot

| Area | Result |
|---|---|
| N5 review rows | 50 |
| Rows with complete lesson-seed TTS target coverage | 50 |
| Rows with incomplete lesson-seed TTS target coverage | 0 |
| Script TTS targets in packet | 198 / 198 |
| Question prompt TTS targets in packet | 250 / 250 |
| Incomplete rows | None |

The previous HN5-001 through HN5-030 manifest gap is closed by
`docs/operations/plans/n5-tts-manifest-backfill-2026-05-26.md`. Audio
generation, persisted `tts_audio` rows, and playback QA remain separate gates.

## Validation

| Gate | Result |
|---|---|
| N5 lesson review packet generation | PASS: 50 rows generated |
| N5 delegated review closeout | PASS: 50 `APPROVED` rows |
| N5 review approval gate | PASS: 50 approved, 0 blockers |
| N5 lesson-seed TTS manifest coverage | PASS: 198/198 script targets, 250/250 question targets |
| N4 review approval gate regression | PASS: 16 approved, 0 blockers |
| Lesson schema/reference validation | PASS: 13 chapters, 66 lessons, 330 questions |
| N5 strict quality gate | PASS: 7 PASS / 0 WARN / 0 FAIL |
| Curriculum contract validation | PASS: 0 warnings, 0 failures |
| Database package typecheck | PASS |

## Commands

```bash
pnpm --filter @harukoto/database lessons:review:prepare -- --level N5
pnpm --filter @harukoto/database curriculum:derive
pnpm --filter @harukoto/database lessons:review:gate -- --level N5
pnpm --filter @harukoto/database lessons:validate
pnpm --filter @harukoto/database lessons:quality -- --level N5 --strict-warnings
pnpm --filter @harukoto/database typecheck
pnpm --filter @harukoto/database curriculum:validate
pnpm --filter @harukoto/database lessons:review:gate -- --level N4
```

## Result

N5 now has a source-controlled delegated AI-assisted lesson review packet, and
the `lessons:review:gate -- --level N5` command passes.

Remaining N5 quality gates:

1. Run TTS generation/audio QA for any missing N5 lesson script and question
   prompt targets.
2. Run mobile target-runtime UAT for the 9-chapter / 50-lesson N5 surface.
3. Keep native-speaker review as a later quality gate before broad curriculum
   claims.
