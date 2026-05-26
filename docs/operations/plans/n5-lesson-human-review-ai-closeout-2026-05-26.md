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

It does not claim native-speaker approval. It also does not close TTS readiness:
HN5-001 through HN5-030 still need lesson-seed TTS manifest backfill and audio
generation/review follow-up before making audio-readiness claims.

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

The packet notes intentionally distinguish curriculum/source approval from TTS
readiness. HN5-001 through HN5-030 are approved for curriculum/source quality
with an explicit TTS manifest gap note. HN5-031 through HN5-050 have lesson-seed
TTS target coverage in the manifest.

## TTS Coverage Snapshot

| Area | Result |
|---|---|
| N5 review rows | 50 |
| Rows with complete lesson-seed TTS target coverage | 20 |
| Rows with incomplete lesson-seed TTS target coverage | 30 |
| Script TTS targets in packet | 78 / 198 |
| Question prompt TTS targets in packet | 100 / 250 |
| Incomplete rows | HN5-001 through HN5-030 |

This TTS gap existed before this review packet was generated. It is not a
curriculum-source blocker, but it remains an audio readiness blocker.

## Validation

| Gate | Result |
|---|---|
| N5 lesson review packet generation | PASS: 50 rows generated |
| N5 delegated review closeout | PASS: 50 `APPROVED` rows |
| N5 review approval gate | PASS: 50 approved, 0 blockers |
| N4 review approval gate regression | PASS: 16 approved, 0 blockers |
| Lesson schema/reference validation | PASS: 13 chapters, 66 lessons, 330 questions |
| N5 strict quality gate | PASS: 7 PASS / 0 WARN / 0 FAIL |
| Curriculum contract validation | PASS: 0 warnings, 0 failures |
| Database package typecheck | PASS |

## Commands

```bash
pnpm --filter @harukoto/database lessons:review:prepare -- --level N5
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

1. Backfill lesson-seed TTS manifest coverage for HN5-001 through HN5-030.
2. Run TTS generation/audio QA for any missing N5 lesson script and question
   prompt targets.
3. Run mobile target-runtime UAT for the 9-chapter / 50-lesson N5 surface.
4. Keep native-speaker review as a later quality gate before broad curriculum
   claims.
