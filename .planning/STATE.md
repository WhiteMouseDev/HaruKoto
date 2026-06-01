---
gsd_state_version: 1.0
milestone: v1.2
milestone_name: (planning — use /gsd:new-milestone)
status: idle
stopped_at: v1.1 archived 2026-04-23; stabilization checkpoint closed with accepted P2 follow-ups
last_updated: "2026-06-01T16:22:00+09:00"
last_activity: 2026-06-01
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

**Latest update (2026-06-01, N4 CH07 candidates):** N4 CH07 candidate-only expansion added five new seed candidates for HN4-027 through HN4-031: `たら`, `ば`, `なら`, `らしい`, and `たばかり`. `docs/operations/plans/n4-ch07-seed-candidate-expansion-2026-06-01.md` records the scope; candidate review packet reports 5/5 delegated AI `APPROVED`; TTS target manifest includes 5/5 example, 20/20 script, and 25/25 question prompt targets as missing generation targets. No official lesson JSON, DB seed promotion, TTS generation, audio QA, or learner-facing CH07 exposure has been done yet.

## Current Position

Milestone: — (none in progress)
Status: Idle after v1.1 ship (2026-04-23)
Latest activity: 2026-06-01 - N4 CH07 candidate-only expansion added five new seed candidates for HN4-027 through HN4-031 after the current N4 26-lesson PILOT slice moved to BETA-WIDE GO. The new candidates passed delegated AI candidate review and curriculum validation, but remain blocked from learner-facing exposure until official lesson promotion, TTS generation, audio QA, DB seed sync, and UAT are completed.
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
- N4 CH07 promotion follow-up - HN4-027 through HN4-031 exist only as approved seed candidates. Next promotion wave should create official N4 CH07 lesson JSON, derive/validate curriculum, generate TTS, run CH07 audio QA, apply configured DB seed, and run API/mobile smoke before any learner-facing exposure.
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

Last session: 2026-06-01T10:33:41+09:00
Latest stopped at: N4 CH07 candidate-only expansion is added for HN4-027 through HN4-031; delegated AI candidate review is 5/5 APPROVED; TTS manifest has 5 example, 20 script, and 25 question prompt targets for CH07. CH07 is not promoted to official lessons or learner-facing exposure.
Stopped at: N4 CH01 through CH06 configured seed, TTS coverage, delegated audio QA, URL-inclusive rollout preflight, and broad exposure decision are green; CH07 candidate source data is ready for promotion planning, while official lesson promotion, TTS generation, audio QA, DB seed sync, and UAT remain open.
Resume file: `docs/operations/release/v1.1-stabilization-checkpoint-2026-04-23.md`
