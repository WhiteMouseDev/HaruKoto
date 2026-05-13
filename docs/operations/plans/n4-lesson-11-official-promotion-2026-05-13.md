# N4 Lesson 11 Official Promotion

> Date: 2026-05-13
> Scope: promote approved HN4-011 seed candidate into official lesson JSON
> Status: official lesson promoted; HN4-011 moved to limited-pilot publish status

## Decision

Promote `lsc-n4-i-adjective-nominalization-001` into official lesson seed
`HN4-011`, then move the chapter to `meta.status=PILOT` for a second limited
pilot wave.

The promotion makes HN4-011 part of the official N4 lesson source set and the
configured seed-check target. The follow-up publish-status decision is recorded
in `docs/operations/plans/n4-lesson-11-pilot-rollout-decision-2026-05-13.md`.
After configured DB seed apply, HN4-011 is expected to become learner-facing in
the same controlled pilot boundary as the first N4 batch.

ASSUMPTION: The user-authorized delegated AI review path is sufficient for
official lesson promotion, but remains lower authority than native-speaker human
curriculum approval.

## Promoted Lesson

| Field | Value |
|---|---|
| Lesson ID | `HN4-011` |
| Chapter | `N4-CH03` / `성질과 정도 표현` |
| Publish status | `PILOT` |
| Source candidate | `lsc-n4-i-adjective-nominalization-001` |
| Topic | `topic-i-adjective-nominalization` |
| Grammar anchor | `〜さ` / order 45 |
| Runtime question types | `VOCAB_MCQ`, `CONTEXT_CLOZE`, `SENTENCE_REORDER` |
| TTS target source | `lesson-seeds:HN4-011:*` |

## Changed Source Files

- `packages/database/data/lessons/n4/ch03-quality-and-degree.json`
  - official HN4-011 lesson JSON.
- `apps/api/app/seeds/lessons.py`
  - N4 seed registry includes the new chapter file.
- `packages/database/data/curriculum/lesson-human-review/n4-pilot-review.json`
  - official review packet includes the HN4-011 approval row.
- `packages/database/data/curriculum/lesson-seed-candidate-review/n4-candidate-review.json`
  - candidate review records `promotedLessonId` and points review evidence at
    official lesson-seed TTS targets.
- `packages/database/data/curriculum/curriculum-topics.json`
  - `topic-i-adjective-nominalization` is covered by HN4-011.
- `packages/database/data/curriculum/coverage-priorities.json`
  - the HN4-011 topic is removed from the N4 foundation priority queue.

## Validation Evidence

| Gate | Result |
|---|---|
| Lesson validation | PASS: 12 chapters / 61 lessons / 305 questions |
| N4 quality gate | PASS: 0 failures |
| Curriculum validation | PASS: 0 warnings / 0 failures; review packet rows 11 |
| Candidate review gate | PASS: 1 `APPROVED` / 0 blockers |
| Official review gate | PASS: 11 `APPROVED` / 0 blockers |
| API regression suite | PASS: 443 passed / 13 skipped |
| Configured DB seed apply | PASS: 3 chapters / 11 lessons / 66 item links; HN4-011 chapter status `PILOT`, published `true` |
| Configured DB seed check | PASS: 3 chapters / 11 lessons / 0 missing / 0 content mismatches / 0 item-link mismatches |
| Published list/detail route smoke | PASS: route-service smoke returns 3 N4 chapters / 11 lessons; HN4-011 detail returns 4 script lines / 5 questions / 5 vocab / 1 grammar with answer keys redacted |
| API start/submit write smoke | PASS: `apps/api/scripts/smoke_lesson_flow.py --level N4 --lesson-no 11 --label HN4-011` completed correct submit 5/5 and wrong submit 0/5; each path registered 6 SRS items and cleanup left 0 smoke residue rows |
| Mobile regression suite | PASS: 526 Flutter tests |
| TTS manifest sync | PASS: package and API manifest/review-batch copies match |
| TTS audio QA | PASS for learner-facing script lines: 4/4 HN4-011 dialogue line TTS calls returned `200`, produced `audio/mpeg` URLs, and decoded as MP3 |

## Validation Boundary

HN4-011 is promoted to official `PILOT` source status and synced to the
configured API DB target. The remaining learner-readiness gates are:

1. Learner-facing mobile UAT for one correct path and one wrong-answer
   retry path after the publish-status change.
2. Full lesson-seed prompt/batch TTS generation and human audio-quality review
   before any broader N4 rollout.

Broad/full N4 rollout remains HOLD until pilot feedback, native-speaker review
when available, and generated/audio-QA evidence are complete.
