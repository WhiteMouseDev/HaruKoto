# N4 Pilot Seed Operational Review

> Date: 2026-05-11
> Scope: PR #74 N4 pilot lesson seeds plus PR #77 runtime answer-key redaction
> Commit: `16afbb66ac9eccdfd0516d5fe6d58be205034daa`
> Status: seeded, runtime-smoked, TTS-scoped, and delegated AI curriculum
> review approved; mobile happy-path and wrong-answer retry UAT passed; rollout decision remains open

## Summary

PR #74 promoted the first N4 pilot batch from seed candidates into official lesson seed files. This review checks whether the batch is operationally ready for the next gate, not whether the Japanese pedagogy is finally approved.

Result: the N4 pilot batch is structurally ready and has been applied to the current configured API DB target. Runtime API smoke verified N4 chapter/list/detail access and confirmed lesson-detail answer keys are redacted. The TTS manifest now tracks the official N4 lesson seed files directly. The review handoff is prepared at `docs/operations/plans/n4-pilot-human-review-handoff-2026-05-12.md`, and the user delegated curriculum approval to Codex because no human expert is currently available. All 10 rows are now `APPROVED` for target-runtime N4 mobile UAT. This is delegated AI curriculum approval, not native-speaker human approval, and it is not a final learner rollout decision: target-runtime mobile happy-path and wrong-answer retry UAT passed on 2026-05-12, while learner-rollout approval remains open.

ASSUMPTION: "configured API DB target" means the database selected by the current `apps/api` runtime environment used for the seed and smoke. This document intentionally does not record database URLs, tokens, or credentials.

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
| Configured DB seed sync | `cd apps/api && uv run python -m app.seeds.lessons --check --level N4` | PASS, 2 chapters / 10 lessons / 0 missing / 0 mismatches |
| Runtime API smoke | authenticated local API smoke against configured DB target | PASS, N4 chapters=2, lessons=10, first lesson detail=200 |
| Lesson-detail answer-key redaction | `cd apps/api && uv run pytest tests/test_lessons.py::test_get_lesson_detail` | PASS, `correctAnswer` and `correctOrder` redacted in lesson detail |
| Official lesson seed TTS scope | `pnpm --filter @harukoto/database curriculum:validate` | PASS, `lesson-seeds:HN4-*` covers 40 script lines and 50 question prompts |
| Review packet preparation | `pnpm --filter @harukoto/database lessons:review:prepare -- --level N4` | PASS, `lesson-human-review/n4-pilot-review.json` covers 10 lessons, 40 script TTS targets, and 50 question TTS targets |
| Review packet drift gate | `pnpm --filter @harukoto/database lessons:review:validate` | PASS, packet structure matches current lesson/TTS sources and reviewer decisions remain valid |
| Delegated AI review approval gate | `pnpm --filter @harukoto/database lessons:review:gate -- --level N4` | PASS, 10 `APPROVED` rows / 0 blockers |
| Delegated AI curriculum review | packet row notes in `lesson-human-review/n4-pilot-review.json` | PASS, obvious wording fixes applied; all rows approved for target-runtime N4 mobile UAT; not native-speaker human approval |
| Target-runtime mobile happy-path UAT | `docs/operations/plans/n4-pilot-mobile-uat-run-2026-05-12.md` | PASS, N4 selected, HN4-001 completed, result 100% / 5 of 5, SRS registration visible, Ch.1 progress 20% |
| Target-runtime wrong-answer retry UAT | `docs/operations/plans/n4-pilot-mobile-uat-run-2026-05-12.md` | PASS, HN4-002 completed with one intentional miss, result 80% / 4 of 5, missed `心配` explanation visible, retry CTA returned to lesson start |

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

4. PASS - Delegated AI curriculum review is complete for mobile UAT entry.
   The grammar order is coherent for an N4 foundation pilot. `〜ために` can remain in lesson 9 as a purpose-expression bridge before conditional `〜と`; broader ordering refinements are accepted as a non-blocking P2 curriculum follow-up.
   The handoff also asks reviewers to re-check HN4-010 `〜と` examples for automatic-result usage. Before handoff, `荷物が届くと、連絡します。` was corrected to `荷物が届くと、メールが来ます。` so the seed no longer models an intentional next action after `〜と`.
   Review also corrected HN4-002 `病院に相談する`, HN4-006 `浅さ`/`太さ` wording, and HN4-008 Korean explanation tone before approval. This approval is explicitly delegated AI review, not native-speaker human validation.

5. PASS - TTS scope is attached to official lesson seed files.
   The generated TTS manifest now uses `lesson-seeds:HN4-*` sources for the 40 N4 reading script lines and 50 N4 question prompts. Actual audio generation and playback review remain part of the lesson seed admin surface follow-up.

6. PASS - Review packet is approved for target-runtime mobile UAT.
   `packages/database/data/curriculum/lesson-human-review/n4-pilot-review.json` joins each N4 lesson with reference grammar, vocabulary, script lines, questions, answer keys, explanations, and linked TTS targets. The user delegated the curriculum decision to Codex, and all 10 N4 rows are now `APPROVED`.
   `pnpm --filter @harukoto/database lessons:review:validate` now guards this packet against lesson/TTS drift and invalid reviewer decisions.
   `pnpm --filter @harukoto/database lessons:review:gate -- --level N4` now passes with 10 `APPROVED` rows and 0 blockers.

7. PASS - Configured DB seed and runtime smoke are complete.
   The configured API DB target contains 2 N4 chapters and 10 N4 lessons. The first N4 lesson detail returned 4 script lines, 5 questions, 5 vocabulary items, and 1 grammar item. This does not by itself approve broad learner rollout.

8. PASS - Lesson detail no longer leaks answer keys.
   PR #77 redacts both `correctAnswer` and `correctOrder` in lesson detail responses. Authoritative correctness remains available through lesson submission results.

9. PASS - Target-runtime mobile happy path is complete.
   On 2026-05-12, the iPhone 17 Pro simulator selected N4, opened HN4-001, verified the synced `〜なさい` grammar meaning, triggered a dialogue-line TTS control without visible UI error, completed all five practice questions, showed 100% / 5 of 5, registered 6 review items, and returned to the N4 list with Ch.1 progress at 20%. See `docs/operations/plans/n4-pilot-mobile-uat-run-2026-05-12.md`.

10. PASS - Target-runtime wrong-answer retry entry is complete.
   On 2026-05-12, the iPhone 17 Pro simulator opened HN4-002, intentionally answered `心配의 뜻은?` incorrectly, displayed `心配(しんぱい)는 걱정입니다.`, completed the remaining practice items, showed 80% / 4 of 5, displayed the missed item as a wrong-answer result card, registered 6 review items, and routed `다시 풀기` back to the lesson start surface. See `docs/operations/plans/n4-pilot-mobile-uat-run-2026-05-12.md`.

## Next Gate Checklist

- [x] Delegated AI curriculum review: lesson order, grammar coverage, Korean explanations, and examples approved by Codex per user authorization; not native-speaker human approval.
- [x] Review approval gate: `lessons:review:gate -- --level N4` passes after all rows are `APPROVED`.
- [x] Review handoff: `docs/operations/plans/n4-pilot-human-review-handoff-2026-05-12.md` prepared with lesson queue, review standard, and closeout rule.
- [x] AI-assisted pre-review: obvious wording issues fixed and row-level notes added before delegated AI approval.
- [x] Review packet preparation: N4 review packet generated with lesson/TTS/answer-key context for reviewer use.
- [x] TTS scope: official `lesson-seeds:HN4-*` targets cover 40 reading script lines and 50 question prompts.
- [x] Configured DB seed sync: N4 seed check passes with 2 chapters, 10 lessons, and no mismatches.
- [x] Runtime API smoke: authenticated N4 list/detail smoke passes and answer keys are redacted.
- [x] Mobile UAT happy path: select N4, open lesson list, complete one N4 lesson, verify result/SRS/progress.
- [x] Mobile wrong-answer retry spot check: complete HN4-002 with one intentional miss, verify result-card explanation, SRS status, and retry CTA entry.
- [ ] Learner rollout decision: only after the remaining gates pass, decide whether this N4 pilot is approved for broader learner exposure.

## Release Gate Boundary

This N4 pilot review belongs to v1.2 curriculum expansion. The v1.1 stabilization gate is already closed separately; this document should not be used to reopen or close v1.1 release status.
