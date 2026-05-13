---
gsd_state_version: 1.0
milestone: v1.2
milestone_name: (planning — use /gsd:new-milestone)
status: idle
stopped_at: v1.1 archived 2026-04-23; stabilization checkpoint closed with accepted P2 follow-ups
last_updated: "2026-05-13T15:18:32+09:00"
last_activity: 2026-05-13
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
**Current focus:** v1.1 shipped — stabilization UAT gate closed with accepted P2 follow-ups. v1.2 leading track is curriculum expansion; N4 pilot seed source promotion, configured DB seed, runtime API smoke, official lesson-seed TTS scope, review handoff, AI-assisted pre-review, delegated AI curriculum approval, mobile target-runtime happy-path UAT, N4 wrong-answer retry spot check, controlled learner-pilot rollout decision, and HN4-011 official promotion plus second limited-pilot publish are complete. HN4-011 configured DB list/detail, start/submit write smoke, lesson TTS audio QA, simulator mobile UAT, first aggregate pilot-feedback baseline, and first aggregate pilot-feedback refresh are complete with no automatic rollback trigger. Full N4 pilot-batch TTS generation is now 99/99 with generated URL validation passing, machine audio preflight passing 99/99 with 0 blockers, and human review packets prepared for all 99 targets; broad/full N4 rollout remains on hold pending human audio-quality verdicts, continued pilot feedback over time, and native-speaker review when available.

## Current Position

Milestone: — (none in progress)
Status: Idle after v1.1 ship (2026-04-23)
Last activity: 2026-05-13 — HN4-011 moved from official DRAFT to `meta.status=PILOT` for a second limited N4 pilot wave. The configured N4 seed was applied and checked with 3 chapters / 11 lessons / 0 missing / 0 mismatches. Published API smoke confirmed N4 list/detail exposure for HN4-011 with answer keys redacted, and configured DB start/submit write smoke passed with temporary smoke users: correct path 5/5, wrong path 0/5, 6 SRS items registered per path, 10 review events written, and all smoke rows cleaned up to 0 residue. HN4-011 lesson TTS generated 4/4 script-line MP3s and 5/5 question-prompt MP3s through the lesson TTS API/service path; all checked URLs returned `200 audio/mpeg` and decoded as MP3. iPhone 17 Pro Simulator UAT opened HN4-011, triggered line-0 TTS, reached a 4/5 result screen with review/retry UI, retried from the detail screen, submitted a corrected 5/5 path, and returned to the learning surface. The first aggregate pilot-feedback baseline found 1 non-smoke learner progress row, 30 review events, no automatic rollback trigger, and complete HN4-011 script-line/question-prompt TTS record coverage. The first refresh matched those aggregate counters, found no new visible aggregate traffic, and still found no automatic rollback trigger. The full published N4 pilot-batch TTS generation run now has 11 lessons, 99/99 generated records, and 99/99 generated audio URLs passing read-only HTTP validation. A machine audio preflight passed 99/99 targets with 0 blockers and 11 silence-ratio warnings. Human audio QA packets are prepared for Chapter 1, Chapter 2, and Chapter 3, covering all 99 targets with 0 missing URLs and 0 failed URL checks. Broad/full N4 rollout remains HOLD. Mobile MY tab launch hardening also landed at `b2262b465a9efce64102f93be780171b58066a00`; physical-device MY install/launch precheck and simulator on-screen smoke passed, while higher-fidelity physical-device screen smoke remains blocked by device lock in `docs/operations/plans/mobile-my-page-release-smoke-2026-05-12.md`. Delegated AI curriculum approval remains explicitly not native-speaker human validation.

Progress: v1.1 [██████████] 100% shipped

## Accumulated Context

### Decisions

Historical decisions logged in PROJECT.md Key Decisions table and archived milestone files (`.planning/milestones/v1.0-ROADMAP.md`, `.planning/milestones/v1.1-ROADMAP.md`).

### Pending Todos

- Mobile MY tab launch smoke — code hardening, automated verification, physical-device install/launch precheck, and simulator on-screen smoke are complete; higher-fidelity physical-device screen smoke remains blocked by device lock using `docs/operations/plans/mobile-my-page-release-smoke-2026-05-12.md`.
- N4 pilot seed operationalization — controlled learner-pilot exposure is approved for HN4-001 through HN4-010, full N4 coverage planning is opened, and staging coverage contracts plus derived priority queue are synced through HN4-011. Lesson 11+ closeout selected `topic-i-adjective-nominalization`; `lsc-n4-i-adjective-nominalization-001` has an `APPROVED` source-controlled delegated AI candidate review packet and is promoted to official limited-pilot lesson HN4-011. Configured DB seed check, published API list/detail smoke, API start/submit write smoke, HN4-011 lesson TTS audio QA, simulator mobile UAT, first aggregate pilot-feedback baseline/refresh, full N4 pilot-batch TTS coverage audit, full N4 machine audio preflight, and full N4 human audio QA packet preparation all pass as evidence-gathering gates. Continued pilot feedback review over time, native-speaker review when available, and actual human audio QA verdicts remain broad-rollout blockers.

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

Last session: 2026-05-11T17:01:44+09:00
Stopped at: HN4-011 second limited-pilot publish plus configured DB seed/list-detail/start-submit API smoke, lesson TTS audio QA, simulator mobile UAT, first aggregate pilot-feedback baseline/refresh, full N4 pilot-batch TTS generation/coverage audit, full N4 machine audio preflight, and full N4 human audio QA packet preparation complete; continued pilot feedback over time, native-speaker review when available, and human audio QA verdicts remain blockers for broader N4 rollout
Resume file: `docs/operations/release/v1.1-stabilization-checkpoint-2026-04-23.md`
