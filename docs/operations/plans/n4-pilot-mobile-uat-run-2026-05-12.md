# N4 Pilot Mobile UAT Run

> Date: 2026-05-12
> Scope: N4 pilot lesson list/detail/start/complete flow on target mobile runtime
> Basis: `origin/main@71accab` plus local seed sync fix in `codex/n4-mobile-uat-seed-sync`
> Status: happy-path mobile UAT passed; learner-rollout decision remains open

## Summary

The N4 pilot happy path was verified on the iPhone 17 Pro simulator against the configured Cloud Run API target. The run found one reference-data drift issue before completion: HN4-001 lesson detail showed the old `〜なさい` Korean meaning, even though the source JSON already says `직접적인 지시`.

The drift was traced to the shared Prisma seed path. `packages/database/prisma/seed.ts` did not load `packages/database/.env` at runtime and the vocabulary/grammar loops swallowed Prisma errors as if rows already existed. The target DB was synced from the current N4 vocabulary and grammar JSON, then the mobile flow was rerun and passed.

ASSUMPTION: The existing simulator test account is acceptable for UAT state mutations such as lesson progress and review-schedule registration.

## Environment

| Area | Value |
|---|---|
| Mobile runtime | Flutter app launched from `apps/mobile` |
| Device | iPhone 17 Pro Simulator, iOS 26.4 |
| API target | `https://harukoto-api-842843944454.asia-northeast3.run.app` |
| Account | Existing simulator test session |
| Secrets/log policy | Raw auth headers, DB URLs, and DIO request logs were not copied into this report |

## Pre-UAT Sync

| Check | Result |
|---|---|
| Initial N4 lesson seed check | FAIL: 4 content mismatches in HN4-002, HN4-006, HN4-008, HN4-010 |
| N4 lesson seed apply | PASS: 2 chapters, 10 lessons, 60 item links |
| Final N4 lesson seed check | PASS: 2 chapters, 10 lessons, 0 missing, 0 content mismatches, 0 item-link mismatches |
| N4 reference sync | PASS: 944 N4 vocabulary rows and 49 N4 grammar rows updated from source JSON |
| `〜なさい` DB verification | PASS: `~하시오 / ~해라 (직접적인 지시)` |

The broad `pnpm --filter @harukoto/database db:seed` command was interrupted after it spent several minutes in the full vocabulary phase. The code fix in this branch makes that seed path load `.env` and fail visibly for vocabulary/grammar errors, but the runtime DB correction for this UAT used the narrower N4 reference sync above.

## Mobile Evidence

| Step | Evidence |
|---|---|
| N4 selection | Study tab switched to N4 and showed 2 chapters / 10 lessons |
| Lesson list | Ch.1 `지시와 판단 표현` showed five lessons and recommended HN4-001 |
| Lesson detail | HN4-001 loaded with topic `교실에서 선생님이 과제 제출 전 주의사항을 안내함` |
| Grammar reference | Detail and grammar-learning screens showed `〜なさい — ~하시오 / ~해라 (직접적인 지시)` |
| TTS trigger | First dialogue-line speaker control showed a loading spinner and returned to the speaker icon without a visible error |
| Practice flow | 4 recognition/cloze questions plus 1 sentence reorder completed |
| Submit/result | Result screen showed `100%`, `5/5 정답` |
| SRS registration | Result screen showed `오늘 배운 6개를 복습 일정에 넣었어요` and per-item next review `3일 후` |
| Progress return | N4 Ch.1 progress updated to `20%`; HN4-001 showed `5/5`; recommended lesson advanced to HN4-002 |

## Outcome

N4 target-runtime mobile happy path is ready for learner-rollout decision review. This run does not replace native-speaker curriculum validation; it verifies that the delegated AI-approved seed can be selected, opened, played through, submitted, and reflected in progress/SRS on the current mobile runtime.

## Follow-Ups

- Run a wrong-answer retry spot check before broad learner exposure if the rollout decision requires N4-specific wrong-answer UI evidence.
- Consider adding a narrow `db:seed` mode for level/reference subsets so future UAT syncs do not require the full vocabulary seed path.
- Keep the delegated AI curriculum approval boundary visible until native-speaker review becomes available.
