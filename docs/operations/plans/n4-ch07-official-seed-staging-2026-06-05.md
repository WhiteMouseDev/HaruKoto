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

1. Seed CH07 through the explicit extra-file ops path without exposing it:

   ```bash
   cd apps/api
   uv run python -m app.seeds.lessons \
     --level N4 \
     --only-extra-content-files \
     --extra-content-file n4/ch07-condition-report-and-recency.json \
     --force-extra-unpublished
   ```

   Use `--check` with the same flags after seeding. Expected pre-rollout audit:
   `lessons=5`, `missing_lessons=0`, `content_mismatches=0`,
   `item_link_mismatches=0`, and `publish_state_mismatches=0`.
2. Generate official lesson TTS for HN4-027 through HN4-031 with
   `--include-unpublished`.
3. Run delegated AI/STT audio QA and apply PASS/FLAG verdicts.
4. Add CH07 to the configured N4 seed registry only after the TTS/audio gate is
   green and learner-facing rollout is intentionally approved.
5. Run configured DB seed check, API list/detail smoke, and mobile runtime UAT.
6. Refresh pilot feedback monitoring after exposure.

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

## Follow-up Seed Safety Path

The next operational wave adds an unpublished extra-file seed path for CH07 TTS
prep:

- `--only-extra-content-files` processes only explicit `--extra-content-file`
  lesson JSON, leaving the default N4 registry untouched.
- `--force-extra-unpublished` forces unregistered extra files to seed with
  `is_published=false` even when the source file remains `PILOT`.
- `--check` reports `publish_state_mismatches`, so the unpublished state can be
  audited after seeding.

This keeps the learner-facing rollout blocked: CH07 can exist in DB for TTS
generation with `--include-unpublished`, but chapter/lesson listing endpoints
should not expose it until the review rows are approved and the default registry
rollout is intentionally opened.

## Follow-up Execution - 2026-06-05

The unpublished extra-file seed path was exercised against the configured local
API database:

```bash
cd apps/api
uv run python -m app.seeds.lessons \
  --level N4 \
  --only-extra-content-files \
  --extra-content-file n4/ch07-condition-report-and-recency.json \
  --force-extra-unpublished
```

Post-seed check with the same flags passed with `lessons=5`,
`missing_lessons=0`, `content_mismatches=0`, `item_link_mismatches=0`, and
`publish_state_mismatches=0`. Direct DB inspection confirmed chapter 7 and
HN4-027 through HN4-031 all remain `is_published=false`.

TTS generation then ran through the approved lesson service path with
`--include-unpublished`. One target was generated first as a storage/provider
probe, then the remaining 44 targets were generated. Follow-up coverage:

- `scripts/report_n4_pilot_tts_coverage.py --level N4 --include-unpublished --check-audio-urls --fail-on-missing`
  reported `279/279` total records and `279/279` audio URLs ready.
- `scripts/audit_n4_pilot_tts_audio_quality.py --level N4 --include-unpublished --lesson-no 27 ... 31 --fail-on-blocker`
  reported CH07 `45/45` machine pass, 0 blockers, and 3 non-blocking
  `HIGH_SILENCE_RATIO` warnings.
- `docs/operations/plans/n4-ch07-pilot-human-audio-qa-ch07-2026-06-05.md`
  was generated with 45 review items and all URL checks `ok`.

STT-based AI audio verification remains blocked. The STT run wrote
`docs/operations/plans/n4-ch07-machine-stt-audio-qa-2026-06-05.md`, but all 45
targets failed transcription with Google GenAI `RESOURCE_EXHAUSTED` because
prepayment credits were depleted. Therefore CH07 review rows must remain
`PENDING`, and `lessons:review:gate -- --level N4` must continue to block
learner-facing rollout.

## Review Notes

Parallel read-only curriculum QA found one P1 and three lower-priority issues:
HN4-031 `受ける/受け取る` drift, missing `受付` links, inconsistent `信号` Korean
gloss, and weak HN4-031 reorder ordering. All were fixed before this packet was
left in staged official JSON form.

Parallel runtime-boundary QA also found that marking CH07 rows `APPROVED` would
incorrectly clear `lessons:review:gate`, even though TTS/audio/seed/UAT are not
complete. The CH07 rows were therefore reset to `PENDING` so the rollout gate
continues to block until the remaining gates are closed.
