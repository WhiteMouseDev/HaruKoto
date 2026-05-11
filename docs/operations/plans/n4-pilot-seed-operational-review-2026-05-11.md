# N4 Pilot Seed Operational Review

> Date: 2026-05-11
> Scope: PR #74 N4 pilot lesson seeds on `main`
> Commit: `2a1ec4a3ecae2f2a20822f42b2d032c504b3d101`
> Status: ready for human curriculum review

## Summary

PR #74 promoted the first N4 pilot batch from seed candidates into official lesson seed files. This review checks whether the batch is operationally ready for the next gate, not whether the Japanese pedagogy is finally approved.

Result: the N4 pilot batch is structurally ready to enter human curriculum review and staging seed dry-run. It should not be seeded directly to production until a reviewer accepts the curriculum order and a staging/disposable DB seed run verifies runtime behavior.

## Source Files

| File | Chapter | Lessons | Status |
|---|---|---:|---|
| `packages/database/data/lessons/n4/ch01-core-directions-and-judgment.json` | N4-CH01 지시와 판단 표현 | 5 | `PILOT` |
| `packages/database/data/lessons/n4/ch02-reasons-conditions-and-intent.json` | N4-CH02 이유・조건・의도 표현 | 5 | `PILOT` |

Both files state that paid PDFs were used only for topic coverage reference, and the app-facing examples, dialogue, and questions are HaruKoto-authored seed content.

## Automated Gate Results

| Gate | Command | Result |
|---|---|---|
| Lesson schema/reference validation | `pnpm --filter @harukoto/database lessons:validate` | PASS |
| N4 lesson quality heuristics | `pnpm --filter @harukoto/database lessons:quality -- --level N4` | PASS, 7 PASS / 0 WARN / 0 FAIL |
| N4 seed policy tests | `cd apps/api && uv run pytest tests/test_lesson_seed_policy.py` | PASS, 12 passed |

Quality gate summary:

- 2 chapters
- 10 lessons
- 50 questions
- 40 reading script lines
- 50 vocabulary links
- 10 grammar links

## Lesson Matrix

| Lesson | Title | Grammar | Vocabulary orders | Runtime shape |
|---|---|---|---|---|
| HN4-001 | 이름을 쓰세요 | 42 `〜なさい` | 79, 75, 35, 115, 153 | 4 script lines, 5 questions |
| HN4-002 | 일찍 쉬는 편이 좋아요 | 43 `〜たほうがいい` | 40, 41, 126, 61, 55 | 4 script lines, 5 questions |
| HN4-003 | 늦을지도 몰라요 | 41 `〜かもしれない` | 44, 45, 97, 40, 77 | 4 script lines, 5 questions |
| HN4-004 | 달릴 수밖에 없어요 | 48 `〜しかない` | 94, 87, 88, 16, 17 | 4 script lines, 5 questions |
| HN4-005 | 한자를 찾아볼 수 있어요 | 44 `可能形` | 27, 52, 90, 98, 42 | 4 script lines, 5 questions |
| HN4-006 | 호수의 깊이를 말해요 | 45 `〜さ` | 142, 143, 144, 145, 146 | 4 script lines, 5 questions |
| HN4-007 | 참가하려고 생각해요 | 46 `意向形` | 127, 83, 85, 128, 88 | 4 script lines, 5 questions |
| HN4-008 | 회의가 길었던 거예요 | 47 `〜のだ` | 55, 59, 76, 54, 61 | 4 script lines, 5 questions |
| HN4-009 | 면접을 위해 준비해요 | 17 `〜ために` | 38, 39, 16, 62, 33 | 4 script lines, 5 questions |
| HN4-010 | 누르면 바뀌어요 | 40 `〜と (条件)` | 21, 20, 100, 82, 118 | 4 script lines, 5 questions |

Every lesson currently uses the runtime-supported question mix:

- 2 `VOCAB_MCQ`
- 2 `CONTEXT_CLOZE`
- 1 `SENTENCE_REORDER`

## Operational Findings

1. PASS - The batch is structurally publishable.
   The seed files use `meta.status = PILOT`; the seed policy maps `PILOT` to `is_published=true` during seed execution.

2. PASS - The runtime question shape is conservative.
   The batch uses only existing mobile-supported question types, so it avoids introducing a new mobile quiz contract.

3. PASS - Reference links resolve.
   The quality gate confirms vocabulary and grammar orders resolve to current reference data.

4. FLAG - Curriculum order still needs human review.
   The grammar order is coherent for an N4 foundation pilot, but a Japanese curriculum reviewer should confirm whether `〜ために` should remain in lesson 9 after higher-priority N4 expressions such as potential/volitional/conditionals.

5. FLAG - TTS generation is not complete.
   Reading script lines and question prompts are TTS-addressable, but this batch should enter the TTS scope and batch review process before production learner rollout.

6. FLAG - Production seed is not executed.
   This review does not prove that the production DB contains the N4 chapters/lessons. Run a staging or disposable DB seed dry-run before any production seed execution.

## Next Gate Checklist

- [ ] Human curriculum review: approve lesson order, grammar coverage, Korean explanations, and examples.
- [ ] TTS scope: add or confirm TTS targets for N4 reading script lines and question prompts.
- [ ] Staging seed dry-run: seed N4 into a non-production DB and verify chapter/lesson rows plus `lesson_item_links`.
- [ ] Mobile UAT: select N4, open lesson list, complete one N4 lesson, verify result/SRS/wrong-answer behavior.
- [ ] Production decision: only after the above gates pass, decide whether to seed N4 pilot into production.

## Release Gate Boundary

This N4 pilot review belongs to v1.2 curriculum expansion. It does not close the v1.1 target-runtime UAT gate, which still requires microphone-backed voice and N5 study-flow sign-off or explicit release-owner deferral.
