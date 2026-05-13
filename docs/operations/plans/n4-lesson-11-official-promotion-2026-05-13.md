# N4 Lesson 11 Official Promotion

> Date: 2026-05-13
> Scope: promote approved HN4-011 seed candidate into official lesson JSON
> Status: official DRAFT lesson promoted; seed validation passed; learner exposure still gated

## Decision

Promote `lsc-n4-i-adjective-nominalization-001` into official lesson seed
`HN4-011` with chapter `meta.status=DRAFT`.

The promotion makes HN4-011 part of the official N4 lesson source set and the
configured seed-check target. It does not publish HN4-011 to learner-facing
routes. HN4-011 still needs a second limited-pilot publish-status decision
before API/mobile UAT can exercise it as learner-ready content.

ASSUMPTION: The user-authorized delegated AI review path is sufficient for
official DRAFT promotion, but remains lower authority than native-speaker human
curriculum approval.

## Promoted Lesson

| Field | Value |
|---|---|
| Lesson ID | `HN4-011` |
| Chapter | `N4-CH03` / `성질과 정도 표현` |
| Publish status | `DRAFT` |
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
| N4 quality gate | WARN: DRAFT file included intentionally; 0 failures |
| Curriculum validation | PASS: 0 warnings / 0 failures; review packet rows 11 |
| Candidate review gate | PASS: 1 `APPROVED` / 0 blockers |
| Official review gate | PASS: 11 `APPROVED` / 0 blockers |
| Database typecheck | PASS: `tsc --noEmit` |
| API lint/type/tests | PASS: ruff check, ruff format check, mypy, 443 pytest passed / 13 skipped |
| Configured DB seed check | PASS: 3 chapters / 11 lessons / 0 missing / 0 content mismatches / 0 item-link mismatches |
| TTS manifest sync | PASS: package and API manifest/review-batch copies match |

## Validation Boundary

HN4-011 is promoted to official DRAFT and is synced to the configured API DB.
The remaining learner-readiness gates are:

1. A second limited-pilot publish decision that explicitly covers HN4-011.
2. Move HN4-011 from `DRAFT` to `PILOT` only after that decision.
3. Learner-facing API/mobile UAT for one correct path and one wrong-answer
   retry path after the publish-status change.
4. TTS audio generation/playback QA before any broader N4 rollout.

Broad/full N4 rollout remains HOLD until pilot feedback, native-speaker review
when available, and generated/audio-QA evidence are complete.
