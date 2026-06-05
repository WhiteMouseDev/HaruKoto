# N4 CH07 Official Lesson Seed Staging

> Date: 2026-06-05
> Scope: HN4-027 through HN4-031 official lesson JSON staging
> Boundary: curriculum staging only; not DB seed sync, TTS generation, audio QA, or learner-facing exposure

ASSUMPTION: The existing CH07 candidates remain the source of truth for this
staging wave, and paid PDFs are used only as topic coverage anchors, not as
example/script/question text.

## Goal

Move the approved N4 CH07 candidates into official lesson JSON so downstream
TTS generation and controlled pilot seed work can operate on `lesson-seeds:*`
targets instead of `lesson-seed-candidates:*` targets. The CH07 rows remain
`PENDING` in `lesson-human-review` because that packet is also the learner
rollout closeout gate.

## Staged Lessons

| Lesson | Topic | Source candidate | Status |
|---|---|---|---|
| HN4-027 | 〜たら | `lsc-n4-tara-conditional-001` | Staged official JSON |
| HN4-028 | 〜ば | `lsc-n4-ba-conditional-001` | Staged official JSON |
| HN4-029 | 〜なら | `lsc-n4-nara-conditional-001` | Staged official JSON |
| HN4-030 | 〜らしい | `lsc-n4-rashii-001` | Staged official JSON |
| HN4-031 | 〜ばかり | `lsc-n4-ta-bakari-001` | Staged official JSON |

The corresponding `lesson-human-review` rows intentionally use
`reviewerDecision: PENDING`. Their reviewer notes record AI curriculum
pre-approval, but do not clear the learner-rollout gate.

## Quality Fixes Applied

- HN4-031 source drift was fixed by aligning the lesson highlight, Q4 prompt,
  and explanation to `受けたばかり`, matching the linked `受ける` vocabulary and
  script line `連絡を受けたばかり`.
- HN4-027 and HN4-028 now link `受付` because the staged dialogue/reorder items
  use `受付で`.
- HN4-029 now uses `신호등` consistently for `信号`.
- HN4-031 reorder tokens were intentionally unsorted while preserving the same
  correct order, avoiding a weak pre-sorted production-like item.
- Official `grammar.pattern` values were normalized to the reference grammar
  rows: `〜たら`, `〜ば`, `〜なら`, `〜らしい`, and `〜ばかり`.

## Promotion Boundary

This wave does not add `ch07-condition-report-and-recency.json` to
`apps/api/app/seeds/lessons.py` `CONTENT_FILES_BY_LEVEL.N4`. Therefore the file
is available as official lesson staging data, but it is not part of the default
configured DB seed path yet.

The source candidates also remain `status: "draft"` because the current
candidate schema only allows draft candidates. The generated candidate review
packet hides them through inferred promotion matching, while the official lesson
review packet carries the rollout-blocking `PENDING` state.

Before learner-facing exposure, the next wave must:

1. Generate official lesson TTS for HN4-027 through HN4-031.
2. Run delegated AI/STT audio QA and apply PASS/FLAG verdicts.
3. Add CH07 to the configured N4 seed registry or seed it explicitly through an
   approved `--extra-content-file` operation.
4. Run configured DB seed check, API list/detail smoke, and mobile runtime UAT.
5. Refresh pilot feedback monitoring after exposure.

## Verification

Commands were run with `mise exec node@22 -- pnpm ...` because the default shell
`node` is v19.6.1 while the project pnpm/corepack path expects Node 22.

| Check | Result |
|---|---|
| `pnpm --filter @harukoto/database curriculum:derive` | PASS |
| `pnpm --filter @harukoto/database lessons:review:prepare -- --level N4` | PASS |
| `pnpm --filter @harukoto/database candidates:review:prepare -- --level N4` | PASS, 0 unpromoted N4 candidates |
| `pnpm --filter @harukoto/database curriculum:validate` | PASS, 0 warnings / 0 failures |
| `pnpm --filter @harukoto/database lessons:validate` | PASS, 16 chapters / 81 lessons |
| `pnpm --filter @harukoto/database lessons:quality -- --level N4 --strict-warnings` | PASS, 7 PASS / 0 WARN / 0 FAIL |
| `pnpm --filter @harukoto/database lessons:review:gate -- --level N4` | EXPECTED BLOCK, 26 APPROVED / 5 PENDING |
| `pnpm --filter @harukoto/database typecheck` | PASS |
| `cd apps/api && uv run pytest tests/test_admin_tts.py` | PASS, 18 tests |
| package/API TTS manifest and batch `cmp` | PASS |
| custom CH07 staging boundary check | PASS |

## Review Notes

Parallel read-only curriculum QA found one P1 and three lower-priority issues:
HN4-031 `受ける/受け取る` drift, missing `受付` links, inconsistent `信号` Korean
gloss, and weak HN4-031 reorder ordering. All were fixed before this packet was
left in staged official JSON form.

Parallel runtime-boundary QA also found that marking CH07 rows `APPROVED` would
incorrectly clear `lessons:review:gate`, even though TTS/audio/seed/UAT are not
complete. The CH07 rows were therefore reset to `PENDING` so the rollout gate
continues to block until the remaining gates are closed.
