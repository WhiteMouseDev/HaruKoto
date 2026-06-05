---
gsd_state_version: 1.0
milestone: v1.2
milestone_name: (planning — use /gsd:new-milestone)
status: idle
stopped_at: v1.1 archived 2026-04-23; stabilization checkpoint closed with accepted P2 follow-ups
last_updated: "2026-06-05T09:54:13+09:00"
last_activity: 2026-06-05
progress:
  total_phases: 0
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md

**Core value:** 원어민이 학습 데이터를 쉽고 빠르게 검증·수정할 수 있어야 한다
**Current focus:** v1.2 leading track is curriculum expansion and N4 pilot hardening. N4 CH01 through CH06 are published in the configured target DB, TTS coverage is 234/234, delegated AI/STT audio QA is complete, N4 rollout preflight reports 234/234 audio verdict PASS with 234/234 audio URL checks passing, and N4 is now BETA-WIDE GO for in-app/free-user pilot exposure. Native-speaker/formal human approval remains a later quality upgrade, not a current automated preflight blocker.
**Latest update (2026-06-01):** N4-CH06 `HN4-022` through `HN4-026` is merged and deployed for controlled pilot exposure. PR #163 merged at `aedcccfcb5f633e825fb4d7a6981623cf1c014c3`; main CI and Deploy API both succeeded; Cloud Run `harukoto-api` serves the `aedcccfcb5f633e825fb4d7a6981623cf1c014c3` image; the configured N4 DB seed check reports 6 chapters, 26 lessons, 0 missing, 0 content mismatches, and 0 item-link mismatches; read-only service-path detail smoke reports HN4-022 through HN4-026 in chapter 6 with expected script/question shape, non-empty vocab/grammar, stripped answer keys, and 0 blockers; authenticated remote HTTP list/detail smoke against Cloud Run reports N4 26 lessons and HN4-022 through HN4-026 detail checks with 0 blockers; representative mobile target-runtime UAT for HN4-022 passed on iPhone 17 Pro Simulator iOS 26.5 with detail/start/vocab TTS/dialogue TTS/recognition/matching/reorder/submit/result/retry/return-to-learning; and first aggregate pilot-feedback baseline found no automatic rollback trigger. HN4-022 has one same-day runtime completion, HN4-023 through HN4-026 are waiting for learner traffic, all CH06 TTS records are present, and native-speaker/formal human approval remains open.

**Latest update (2026-06-01, N4 CH06 delegated audio QA):** CH06 audio QA is closed for the temporary delegated AI/STT gate. Ten script-line TTS rows were regenerated after retry STT review, post-regeneration audit reports 10/10 machine pass with 0 blockers, CH06 packet `docs/operations/plans/n4-ch06-pilot-human-audio-qa-ch06-2026-06-01.md` now reports 45/45 PASS, and the full N4 preflight in `docs/operations/plans/n4-ch06-audio-qa-broad-preflight-2026-06-01.md` reports curriculum validation PASS, configured seed check PASS, TTS coverage 234/234, audio URLs 234/234, and audio verdicts 234/234 PASS. Native-speaker/formal human approval remains explicitly open.

**Latest update (2026-06-01, N4 broad exposure):** N4 broad exposure is approved as BETA-WIDE GO for the current 26-lesson PILOT slice, not a complete N4 course claim. `docs/operations/plans/n4-broad-exposure-decision-2026-06-01.md` records the decision; `docs/operations/plans/n4-broad-exposure-preflight-2026-06-01.md` records 234/234 TTS and audio verdict PASS; `docs/operations/plans/n4-broad-exposure-feedback-baseline-2026-06-01.md` records 26 published lessons, 26/26 TTS-ready, 3 lessons with progress, 23 waiting for traffic, and 0 blockers. `apps/api/scripts/report_level_pilot_feedback.py` now provides the level-wide feedback monitor for periodic refreshes.

**Latest update (2026-06-05, N4 CH07 official staging):** N4 CH07 official lesson JSON staging is prepared for HN4-027 through HN4-031 in `packages/database/data/lessons/n4/ch07-condition-report-and-recency.json`. TTS target derivation now uses official `lesson-seeds:HN4-027..031` script/question targets instead of CH07 `lesson-seed-candidates:*` targets, package/API TTS runtime copies match, and `docs/operations/plans/n4-ch07-official-seed-staging-2026-06-05.md` records the gate boundary. CH07 is intentionally not added to `apps/api/app/seeds/lessons.py` default N4 seed registry. `lesson-human-review` rows for CH07 remain `PENDING`, not `APPROVED`, so `lessons:review:gate -- --level N4` continues to block learner rollout until TTS generation, delegated audio QA, DB seed sync, API smoke, and mobile UAT are complete.

**Latest update (2026-06-05, N4 CH07 unpublished seed ops):** The API lesson seed CLI now has an explicit CH07-safe ops path: `--only-extra-content-files` limits a run to the provided `--extra-content-file`, and `--force-extra-unpublished` keeps unregistered extra lesson files `is_published=false` even when their source `meta.status` remains `PILOT`. Seed audit now reports `publish_state_mismatches`, so CH07 can be seeded for unpublished TTS generation and checked without opening learner-facing rollout. The next gate is to run the extra-file unpublished seed operation, generate CH07 TTS with `--include-unpublished`, run delegated AI/STT audio QA, then approve CH07 review rows only after API/mobile smoke and UAT pass.

**Latest update (2026-06-05, N4 CH07 TTS generated):** CH07 was seeded through the approved extra-only unpublished path and verified with `publish_state_mismatches=0`; direct DB inspection confirmed chapter 7 and HN4-027 through HN4-031 remain `is_published=false`. CH07 TTS generation completed for all 45 lesson script/question targets, and N4 `--include-unpublished` coverage now reports `279/279` records plus `279/279` audio URLs ready. Machine audio QA for CH07 reports `45/45` pass with 0 blockers and 3 non-blocking high-silence-ratio warnings. STT-based AI audio verification is still blocked by Google GenAI `RESOURCE_EXHAUSTED`/depleted prepayment credits, so CH07 review rows remain `PENDING` and learner-facing rollout remains blocked.

## Current Position

Milestone: — (none in progress)
Status: Idle after v1.1 ship (2026-04-23)
Latest activity: 2026-06-05 - N4 CH07 candidate-only data was staged as official lesson JSON for HN4-027 through HN4-031, but not added to the configured API seed registry. CH07 official TTS manifest targets are present and runtime copies match; delegated AI curriculum review issues were fixed, including HN4-031 `受ける/受け取る` drift, `受付` vocabulary links, `信号` Korean gloss consistency, and weak reorder ordering. The API seed CLI now supports extra-only unpublished seeding for CH07 TTS prep, with audit coverage for publish-state drift. CH07 unpublished seed sync and 45/45 TTS generation are complete, and machine audio QA has 0 blockers, but STT-based AI audio verification is blocked by depleted Google GenAI prepayment credits. CH07 remains blocked from learner-facing exposure: `lesson-human-review` keeps these five rows `PENDING` and the learner rollout gate should fail until STT/delegated audio QA, API smoke, and mobile UAT are completed.
Historical activity: 2026-05-14 - Early N4 audio QA established the delegated AI/STT review pattern for CH01 through CH03, including machine reports, STT reconciliation, regeneration handoff, and explicit `not native-speaker review` notes. This history is superseded for current rollout state by the 2026-06-01 CH06 closeout and 234/234 preflight PASS evidence above.

Progress: v1.1 [██████████] 100% shipped

## Accumulated Context

### Decisions

Historical decisions logged in PROJECT.md Key Decisions table and archived milestone files (`.planning/milestones/v1.0-ROADMAP.md`, `.planning/milestones/v1.1-ROADMAP.md`).

### Pending Todos

- N4 CH05 controlled pilot follow-up — first pilot-feedback baseline passed in `docs/operations/plans/n4-ch05-pilot-feedback-baseline-2026-05-27.md`; continue feedback refreshes over time and keep native-speaker review as a later quality upgrade.
- N4 CH05 physical-device smoke — `Kun Woo's iPhone` is visible over wireless/CoreDevice, but `docs/operations/plans/n4-ch05-physical-device-smoke-2026-05-27.md` records a device-lock blocker before install/launch proof; rerun after the phone is unlocked and kept awake.
- N4 CH06 controlled pilot follow-up — post-merge deploy, configured DB seed sync, read-only service-path list/detail smoke, authenticated remote HTTP list/detail smoke, representative HN4-022 mobile target-runtime UAT, and first aggregate pilot-feedback baseline passed in `docs/operations/plans/n4-ch06-post-merge-operational-check-2026-06-01.md`, `docs/operations/plans/n4-ch06-mobile-uat-2026-06-01.md`, and `docs/operations/plans/n4-ch06-pilot-feedback-baseline-2026-06-01.md`; continue feedback refreshes over time and keep native-speaker review as a later quality upgrade.
- N4 broad exposure monitoring - BETA-WIDE GO is approved for the current 26-lesson PILOT slice. Continue level-wide feedback refreshes with `apps/api/scripts/report_level_pilot_feedback.py`; keep product wording as pilot/beta coverage until fuller N4 curriculum coverage and native-speaker review are available.
- N4 CH07 rollout follow-up - HN4-027 through HN4-031 now have staged official lesson JSON, unpublished DB seed rows, and generated TTS for all 45 script/question targets, but the file is not in the default API seed registry and the five `lesson-human-review` rows remain `PENDING`. Next wave should resolve Google GenAI STT credit blockage or run an alternate delegated audio QA path, inspect the 3 high-silence-ratio warnings, run API/mobile smoke, then close `lessons:review:gate` before learner-facing exposure.
- Mobile MY tab launch smoke — code hardening, automated verification, physical-device install/launch precheck, and simulator on-screen smoke are complete; higher-fidelity physical-device screen smoke remains blocked by device lock using `docs/operations/plans/mobile-my-page-release-smoke-2026-05-12.md`.
- N4 pilot seed operationalization - controlled learner-pilot exposure is approved for HN4-001 through HN4-026. Configured DB seed checks, published API smoke, simulator/mobile UAT slices, TTS generation/coverage, machine audio preflight, delegated AI/STT audio verdict packets, CH06 targeted TTS regeneration, and full N4 234/234 audio preflight now pass as evidence-gathering gates. Continued pilot feedback review over time and native-speaker review when available remain quality follow-ups rather than automated audio QA blockers.

### Release Gate

- v1.1 tag stays fixed at `d7a8c89`; post-tag commits (`950681d`, `c629aae`) are stabilization.
- Current checkpoint: closed-with-accepted-P2. Physical H1/H3 target-runtime UAT passed, H2 generation-failure path is accepted as automated-only coverage because no safe production fault-injection target is approved, and H5 is accepted within visible API/web Sentry scope because no separate mobile/admin Sentry projects are available in the current org view. See `docs/operations/release/v1.1-stabilization-checkpoint-2026-04-23.md`.
- If the post-tag mobile fix should ship as a release artifact, cut `v1.1.1` at `c629aae`.
- New API/mobile work should now follow the v1.2 planning and validation path rather than the v1.1 stabilization gate.

### Blockers/Concerns

v1.1 stabilization checkpoint is closed with accepted P2 follow-ups. Keep the accepted H2 automated-only decision and H5 mobile/admin Sentry enhancement visible during v1.2 planning, but they are not v1.1 release blockers.

### Resolved Carry-overs (2026-04-23 PM)

- P0-2 음성 통화 리포트 silent-fail: mobile fix shipped (commit 950681d). Backend already classified errors in d020b79; mobile now threads `feedbackError` end-to-end with differentiated no-data UI (no_transcript / generation_failed / generic).
- `feature/study-path-redesign` branch: dropped. Main already implements frozen lesson design (ChapterCard + LessonTile + 6-step lesson flow). Serpentine experiment had no design-doc backing, 5-week stale, data-model mismatch. Local + remote branch + archive tag all deleted.
- Branch hygiene: merged `feature/flutter-native` remote deleted; `worktree-agent-a0c31a9c` worktree + branch removed.

## Session Continuity

Last session: 2026-06-05T09:54:13+09:00
Latest stopped at: N4 CH07 official lesson JSON staging is prepared for HN4-027 through HN4-031, unpublished CH07 seed sync is complete, and all 45 CH07 TTS records are generated with URL checks passing. `lesson-human-review` keeps the five CH07 rows `PENDING` because STT-based AI audio verification is blocked by depleted Google GenAI prepayment credits and API/mobile UAT has not yet run.
Stopped at: N4 CH01 through CH06 configured seed, TTS coverage, delegated audio QA, URL-inclusive rollout preflight, and broad exposure decision are green. CH07 has official lesson staging data, safe unpublished seed rows, and generated TTS; the next operational wave should resolve/replace the STT audio QA gate, inspect 3 high-silence warnings, smoke API/mobile, then close `lessons:review:gate`.
Resume file: `docs/operations/release/v1.1-stabilization-checkpoint-2026-04-23.md`
