# N4 CH07 Seed Candidate Expansion

> Date: 2026-06-01
> Scope: N4 CH07 candidate-only expansion, HN4-027 through HN4-031
> Boundary: candidate curriculum approval only; not learner-facing promotion

## Summary

Added five N4 CH07 seed candidates to broaden N4 coverage after the CH01
through CH06 pilot slice reached broad-exposure readiness.

The new slice targets conditional and hearsay/recent-completion grammar that is
already present in the N4 reference grammar rows but not yet represented as
official learner-facing lesson seeds beyond HN4-026.

## Candidate Slice

| Lesson | Candidate | Topic | PDF coverage anchor | Grammar order | Review |
|---|---|---|---|---:|---|
| HN4-027 | `lsc-n4-tara-conditional-001` | `topic-tara-conditional` | PDF 052 | 21 | APPROVED |
| HN4-028 | `lsc-n4-ba-conditional-001` | `topic-ba-conditional` | PDF 088 | 22 | APPROVED |
| HN4-029 | `lsc-n4-nara-conditional-001` | `topic-nara-conditional` | PDF 089 | 23 | APPROVED |
| HN4-030 | `lsc-n4-rashii-001` | `topic-rashii` | PDF 094 | 15 | APPROVED |
| HN4-031 | `lsc-n4-ta-bakari-001` | `topic-ta-bakari` | PDF 054 | 32 | APPROVED |

## Gate Evidence

| Gate | Result | Evidence |
|---|---:|---|
| Candidate count | PASS | N4 seed candidates increased from 26 to 31 |
| Source originality boundary | PASS | PDF files are coverage anchors only; examples, dialogue, questions, and explanations are HaruKoto-authored |
| Runtime question compatibility | PASS | Each candidate uses only `VOCAB_MCQ`, `CONTEXT_CLOZE`, and `SENTENCE_REORDER` |
| Candidate review packet | PASS | `lesson-seed-candidate-review/n4-candidate-review.json` contains 5 CH07 rows |
| Delegated AI candidate review | PASS | 5/5 rows are `APPROVED` with explicit non-native-speaker boundary notes |
| TTS manifest coverage | PASS | 5/5 example, 20/20 script, and 25/25 question prompt targets exist as missing generation targets |
| Curriculum validation | PASS | `pnpm --filter @harukoto/database curriculum:validate` exits 0 |
| Candidate approval gate | PASS | `pnpm --filter @harukoto/database candidates:review:gate -- --level N4` exits 0 |
| Official lesson exposure | BLOCKED | No `data/lessons/n4/ch07-*.json` file was added; TTS generation, audio QA, official lesson review, seed promotion, and UAT remain open |

## Peer Review Follow-up

Two read-only sub-agent reviews were run before commit:

- Japanese curriculum review found three must-fix issues and they were applied:
  - changed `駅に出発します` to `駅へ出発します`;
  - changed the `なら` crossing instruction to `信号をよく見てください`;
  - replaced mismatched `たばかり` vocabulary links with lesson-aligned N4
    vocabulary.
- Contract/runtime review found no blockers and confirmed the candidate-only
  boundary, generated TTS artifacts, and approval gate shape.
- Minor reorder difficulty feedback was also applied by making CH07 reorder
  questions use at least three tokens where practical.

## Commands

```bash
pnpm --filter @harukoto/database curriculum:derive
```

```bash
pnpm --filter @harukoto/database candidates:review:prepare -- --level N4
```

```bash
pnpm --filter @harukoto/database curriculum:validate
```

```bash
pnpm --filter @harukoto/database candidates:review:gate -- --level N4
```

## Promotion Boundary

These candidates are ready for the next promotion planning step, but they are
not ready for learner-facing exposure.

Promotion still requires:

- official `packages/database/data/lessons/n4/ch07-*.json` promotion planning;
- `packages/database` lesson validation and quality gate after promotion;
- configured API DB seed sync check for N4;
- TTS generation for CH07 script and question prompt targets;
- delegated AI/STT audio QA packet with 45/45 PASS for CH07;
- official lesson human-review packet update;
- API/mobile smoke or representative UAT after seed apply.

ASSUMPTION: Because no human Japanese expert is currently available, the review
decision recorded here is delegated AI curriculum review. It must not be
marketed as native-speaker approval.
