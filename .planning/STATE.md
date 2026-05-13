---
gsd_state_version: 1.0
milestone: v1.2
milestone_name: (planning — use /gsd:new-milestone)
status: idle
stopped_at: v1.1 archived 2026-04-23; stabilization checkpoint closed with accepted P2 follow-ups
last_updated: "2026-05-13T11:05:28+09:00"
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
**Current focus:** v1.1 shipped — stabilization UAT gate closed with accepted P2 follow-ups. v1.2 leading track is curriculum expansion; N4 pilot seed source promotion, configured DB seed, runtime API smoke, official lesson-seed TTS scope, review handoff, AI-assisted pre-review, delegated AI curriculum approval, mobile target-runtime happy-path UAT, N4 wrong-answer retry spot check, controlled learner-pilot rollout decision, and HN4-011 official promotion plus second limited-pilot publish are complete. HN4-011 configured DB list/detail, start/submit write smoke, learner-facing script-line TTS audio QA, and target-runtime rendering/navigation probe are complete. HN4-011 submit-path mobile UAT and broad/full N4 rollout remain on hold.

## Current Position

Milestone: — (none in progress)
Status: Idle after v1.1 ship (2026-04-23)
Last activity: 2026-05-13 — HN4-011 moved from official DRAFT to `meta.status=PILOT` for a second limited N4 pilot wave. The configured N4 seed was applied and checked with 3 chapters / 11 lessons / 0 missing / 0 mismatches. Published API smoke confirmed N4 list/detail exposure for HN4-011 with answer keys redacted, and configured DB start/submit write smoke passed with temporary smoke users: correct path 5/5, wrong path 0/5, 6 SRS items registered per path, 10 review events written, and all smoke rows cleaned up to 0 residue. HN4-011 learner-facing dialogue TTS generated 4/4 script-line MP3s through the lesson TTS API; all returned `200 audio/mpeg` and decoded as MP3. iPhone 17 Pro Simulator target-runtime probe opened HN4-011 from Study and rendered detail, word/dialogue/quiz/matching/sentence-reorder steps without a visible crash; clean correct-path submit and wrong-answer retry UAT remain pending. Mobile debug DIO logging now redacts auth/token material before target mobile UAT continues. Broad/full N4 rollout remains HOLD. Mobile MY tab launch hardening also landed at `b2262b465a9efce64102f93be780171b58066a00`; physical-device MY install/launch precheck passed on `Kun Woo's iPhone`, while screen-level smoke remains pending in `docs/operations/plans/mobile-my-page-release-smoke-2026-05-12.md`. Delegated AI curriculum approval remains explicitly not native-speaker human validation.

Progress: v1.1 [██████████] 100% shipped

## Accumulated Context

### Decisions

Historical decisions logged in PROJECT.md Key Decisions table and archived milestone files (`.planning/milestones/v1.0-ROADMAP.md`, `.planning/milestones/v1.1-ROADMAP.md`).

### Pending Todos

- Mobile MY tab launch smoke — code hardening, automated verification, and physical-device install/launch precheck are complete; next gate is screen-level physical-device smoke using `docs/operations/plans/mobile-my-page-release-smoke-2026-05-12.md`.
- N4 pilot seed operationalization — controlled learner-pilot exposure is approved for HN4-001 through HN4-010, full N4 coverage planning is opened, and staging coverage contracts plus derived priority queue are synced through HN4-011. Lesson 11+ closeout selected `topic-i-adjective-nominalization`; `lsc-n4-i-adjective-nominalization-001` has an `APPROVED` source-controlled delegated AI candidate review packet and is promoted to official limited-pilot lesson HN4-011. Configured DB seed check, published API list/detail smoke, API start/submit write smoke, HN4-011 learner-facing script-line TTS audio QA, and target-runtime rendering/navigation probe all pass. Next gate is target mobile submit-path UAT. Pilot feedback review, native-speaker review when available, and full lesson-seed prompt/batch TTS generation/audio QA remain broad-rollout blockers.

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
Stopped at: HN4-011 second limited-pilot publish plus configured DB seed/list-detail/start-submit API smoke, learner-facing script-line TTS audio QA, and target-runtime rendering/navigation probe complete; submit-path mobile UAT, pilot feedback, native-speaker review when available, and full prompt/batch TTS generation/audio QA remain blockers for broader N4 rollout
Resume file: `docs/operations/release/v1.1-stabilization-checkpoint-2026-04-23.md`
