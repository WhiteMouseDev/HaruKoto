# N5 Draft-to-Pilot Promotion Review

> Date: 2026-05-12
> Scope: N5 Ch.07-Ch.09 lesson seed promotion
> Status: source-level pilot promotion complete; target DB seed sync and
> mobile UAT remain separate gates

## Summary

N5 now has 9 pilot chapters and 50 pilot lessons in source. Ch.07-Ch.09 were
reviewed against the lesson schema, reference links, N5 quality heuristics, and
API seed publish policy before changing their `meta.status` from `DRAFT` to
`PILOT`.

This is a source and automated-quality promotion. It does not claim native
speaker final curriculum approval or that any production database has already
been reseeded.

ASSUMPTION: "review" in this document means Codex-assisted structural and
content sanity review plus automated gates, not final human curriculum approval.

## Promoted Source Files

| File | Chapter | Lessons | Status |
|---|---|---:|---|
| `packages/database/data/lessons/n5/ch07-foundation-expression-reinforcement.json` | CH07 기초 표현 보강 | 5 | `PILOT` |
| `packages/database/data/lessons/n5/ch08-daily-expressions-and-verb-foundations.json` | CH08 생활 표현과 동사 기초 | 9 | `PILOT` |
| `packages/database/data/lessons/n5/ch09-expression-contrast-and-choice.json` | CH09 표현 대조와 선택 | 6 | `PILOT` |

Total N5 source scope after promotion:

- 9 chapters
- 50 lessons
- 250 questions
- 198 reading script lines
- 291 vocabulary links
- 50 grammar links

## Review Fixes Applied

1. Corrected grammar references where dedicated N5 grammar rows already exist.
   - HN5-039 now links to order 55 `ある・いる`.
   - HN5-047 now links to order 60 `〜くなる / 〜になる`.
   - HN5-048 now links to order 56 `〜だけ`.
   - HN5-050 now links to order 57 `N + という + N`.
   - HN5-049 uses canonical pattern `N + にする`.

2. Reduced two over-dense vocabulary link sets to the pilot target.
   - HN5-037 removed unused `-分`, keeping `-半` for `十時半`.
   - HN5-040 removed unused `来る`, keeping the verbs used by the lesson focus.

3. Registered explicit teaching aliases in the quality gate for N5 expressions
   that intentionally teach a learner-facing phrase while linking to a broader
   reference grammar row.

4. Added an API seed policy regression test asserting every N5 source file is
   `PILOT`, publishable, internally counted, and totals 50 lessons.

## Automated Gate Results

| Gate | Command | Result |
|---|---|---|
| Lesson schema/reference validation | `pnpm --filter @harukoto/database lessons:validate` | PASS, 60 total lessons / 300 questions |
| N5 strict quality gate | `pnpm --filter @harukoto/database lessons:quality -- --level N5 --strict-warnings` | PASS, 7 PASS / 0 WARN / 0 FAIL |
| Database package typecheck | `pnpm --filter @harukoto/database typecheck` | PASS |
| API seed policy tests | `cd apps/api && uv run pytest tests/test_lesson_seed_policy.py -q` | PASS, 13 passed |

## Operational Findings

1. PASS - Ch.07-Ch.09 are structurally publishable.
   The strict quality gate passes with no warnings after the reference and
   density fixes.

2. PASS - Publish behavior is explicit.
   All N5 lesson files now use `meta.status = PILOT`; the API seed policy maps
   `PILOT` to `is_published=true` and rejects unknown statuses.

3. PASS - Runtime question shape remains conservative.
   The promoted lessons only use existing supported types:
   `VOCAB_MCQ`, `CONTEXT_CLOZE`, and `SENTENCE_REORDER`.

4. FLAG - Target database sync is not part of this source promotion.
   After merge, run the configured seed/check path against the intended DB
   target before saying deployed learners can see all 50 N5 lessons.

5. FLAG - Human curriculum review remains useful before broad expansion.
   The automated gate is now clean, but the next expansion decision should still
   include human review of topic order, Korean explanations, and example
   naturalness.

## Next Gate Checklist

- [x] Source-level Ch.07-Ch.09 promotion to `PILOT`.
- [x] Strict N5 quality gate has 0 warnings and 0 failures.
- [x] API seed policy test covers the 50-lesson N5 pilot set.
- [ ] Target DB seed/check for N5 after merge.
- [ ] Mobile UAT after target DB sync: open N5 lesson list and confirm 9
  chapters / 50 lessons are visible.
- [ ] Complete at least one lesson from Ch.07-Ch.09 on device and verify result
  and SRS behavior.
