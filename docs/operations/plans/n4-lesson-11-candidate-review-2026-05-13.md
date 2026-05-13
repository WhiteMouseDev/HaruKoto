# N4 Lesson 11 Candidate Review

> Date: 2026-05-13
> Scope: HN4-011 seed candidate before official lesson promotion
> Status: delegated AI candidate review approved; not native-speaker human approval

## Source of Truth

Candidate review packet:

- `packages/database/data/curriculum/lesson-seed-candidate-review/n4-candidate-review.json`

Candidate source files:

- `packages/database/data/curriculum/lesson-seed-candidates.json`
- `packages/database/data/curriculum/example-bank.json`
- `packages/database/data/curriculum/tts-target-manifest.json`

## Review Target

| Candidate | Target lesson | Topic | Grammar | Coverage | Decision |
|---|---|---|---|---|---|
| `lsc-n4-i-adjective-nominalization-001` | HN4-011 | `topic-i-adjective-nominalization` | `いAdj stem + さ` / N4 order 45 | 1 example / 4 script / 5 questions / TTS 1+4+5 | APPROVED |

## Review Result

PASS for official lesson promotion planning.

- The candidate stays scoped to い-adjective nominalization through concrete
  paper-thickness and softness examples, so it does not repeat HN4-006 as a
  generic `〜さ` lesson.
- The app-facing example, reading script, prompts, and explanations are
  HaruKoto-authored. Paid PDF material remains only a topic/order reference.
- The question shape uses existing runtime-supported types only:
  `VOCAB_MCQ`, `CONTEXT_CLOZE`, and `SENTENCE_REORDER`.
- TTS review coverage exists for the example sentence, all 4 reading script
  lines, and all 5 question prompts.

ASSUMPTION: The user-authorized no-human-expert path permits delegated AI
candidate approval for promotion planning. This is lower authority than future
native-speaker human review and must stay labeled as such.

## Gate Commands

Run these before official lesson promotion:

```bash
pnpm --filter @harukoto/database candidates:review:validate
pnpm --filter @harukoto/database candidates:review:gate -- --level N4 --candidate lsc-n4-i-adjective-nominalization-001
```

Expected current state:

- `candidates:review:validate` passes with 1 N4 candidate review row.
- `candidates:review:gate -- --level N4 --candidate lsc-n4-i-adjective-nominalization-001`
  passes with 1 `APPROVED` row and 0 blockers.

## Boundary

This review approves HN4-011 for the next promotion-planning slice only. It does
not seed the DB, expose the lesson to learners, approve broad/full N4 rollout,
or replace native-speaker curriculum review when one becomes available.

Next gate: promote HN4-011 into official lesson JSON, regenerate the official
N4 lesson human-review packet, then run DB/API/mobile validation.
