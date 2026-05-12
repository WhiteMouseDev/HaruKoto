# N4 Pilot Mobile UAT Run

> Date: 2026-05-12
> Scope: N4 pilot lesson list/detail/start/complete flow on target mobile runtime
> Basis: happy-path run on `origin/main@71accab` plus local seed sync fix in `codex/n4-mobile-uat-seed-sync`; wrong-answer spot check on `origin/main@110ca01` in `codex/n4-wrong-answer-uat`
> Status: happy-path and wrong-answer retry mobile UAT passed; learner-rollout decision remains open

## Summary

The N4 pilot happy path was verified on the iPhone 17 Pro simulator against the configured Cloud Run API target. The run found one reference-data drift issue before completion: HN4-001 lesson detail showed the old `〜なさい` Korean meaning, even though the source JSON already says `직접적인 지시`.

The drift was traced to the shared Prisma seed path. `packages/database/prisma/seed.ts` did not load `packages/database/.env` at runtime and the vocabulary/grammar loops swallowed Prisma errors as if rows already existed. The target DB was synced from the current N4 vocabulary and grammar JSON, then the mobile flow was rerun and passed.

A follow-up HN4-002 wrong-answer run intentionally missed one vocabulary question, then completed the remaining practice steps. The result screen highlighted the missed `心配` item, preserved the explanation, registered review items, and the `다시 풀기` CTA returned to the HN4-002 lesson start surface.

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

## Wrong-Answer Retry Evidence

| Step | Evidence |
|---|---|
| Lesson detail | HN4-002 `일찍 쉬는 편이 좋아요` loaded with grammar `〜たほうがいい — ~하는 편이 좋다 (조언)` |
| Intentional miss | First recognition prompt `心配의 뜻은?` was answered with `자신감` instead of `걱정` |
| Immediate feedback | The screen showed `心配(しんぱい)는 걱정입니다.` before continuing |
| Remaining practice | Q2 `相談`, both `たほうがいい` cloze items, the vocabulary matching step, and sentence reorder `今日は` / `早く` / `寝たほうがいいです` completed |
| Submit/result | Result screen showed `80%`, `4/5 정답` |
| Wrong-answer display | The missed `心配` item appeared as the red result card with the explanation and review status `학습 중`, `다음 복습: 1일 후` |
| SRS registration | Result screen showed `오늘 배운 6개를 복습 일정에 넣었어요`; submitted telemetry recorded `scoreCorrect: 4`, `scoreTotal: 5`, and `srsItemsRegistered: 6` |
| Retry entry | `다시 풀기` returned to the HN4-002 lesson detail with `학습 시작하기`, confirming the retry CTA reaches the lesson restart path |

## Outcome

N4 target-runtime mobile happy path and N4-specific wrong-answer retry entry are ready for learner-rollout decision review. This run does not replace native-speaker curriculum validation; it verifies that the delegated AI-approved seed can be selected, opened, played through, submitted, reflected in progress/SRS, and retried after an incorrect answer on the current mobile runtime. The rollout decision is recorded separately as LIMITED GO for controlled pilot exposure in `docs/operations/plans/n4-pilot-learner-rollout-decision-2026-05-12.md`.

## Follow-Ups

- Consider adding a narrow `db:seed` mode for level/reference subsets so future UAT syncs do not require the full vocabulary seed path.
- Keep the delegated AI curriculum approval boundary visible until native-speaker review becomes available.
