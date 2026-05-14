---
gsd_state_version: 1.0
milestone: v1.2
milestone_name: (planning — use /gsd:new-milestone)
status: idle
stopped_at: v1.1 archived 2026-04-23; stabilization checkpoint closed with accepted P2 follow-ups
last_updated: "2026-05-14T17:39:31+09:00"
last_activity: 2026-05-14
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
**Current focus:** v1.1 shipped — stabilization UAT gate closed with accepted P2 follow-ups. v1.2 leading track is curriculum expansion; N4 pilot seed source promotion, configured DB seed, runtime API smoke, official lesson-seed TTS scope, review handoff, AI-assisted pre-review, delegated AI curriculum approval, mobile target-runtime happy-path UAT, N4 wrong-answer retry spot check, controlled learner-pilot rollout decision, and HN4-011 official promotion plus second limited-pilot publish are complete. HN4-011 configured DB list/detail, start/submit write smoke, lesson TTS audio QA, simulator mobile UAT, first aggregate pilot-feedback baseline, and two aggregate pilot-feedback refreshes are complete with no automatic rollback trigger. Full N4 pilot-batch TTS generation is now 99/99 with generated URL validation passing, machine audio preflight passing 99/99 with 0 blockers, opt-in AI STT assist plus Markdown report handoff available for wrong-text triage, and 2026-05-14 generated reports confirm 99/99 machine pass, 11 silence-ratio review-priority warnings, and STT assist coverage for all 99 targets with 26 exact matches, 73 review-priority mismatches, and 0 STT errors; human review packets are prepared for all 99 targets, a prioritized review queue plus static HTML listening sheet now surfaces 11 P0 machine-warning rows, 62 P1 STT-only mismatch rows, and 26 delegated AI-assisted PASS rows, and a verdict tracker plus CSV apply flow is available. The 26 no-signal PASS-candidate rows were applied with explicit `not native-speaker review` notes; STT reconciliation split the remaining 73 unresolved rows into 11 P0 machine-warning, 8 lexical-risk, 11 near Japanese match, 3 canonical match, and 40 mixed/Korean prompt STT-unreliable rows. Focused Markdown/CSV/HTML listening batches now cover those STT lanes, the 8 lexical-risk rows were marked delegated AI-assisted `FLAG`, the 3 canonical rows were marked delegated AI-assisted `PASS`, the 8 current `FLAG` rows now have a regeneration handoff manifest, a dry-run-first targeted TTS replacement harness is available with explicit `--execute`, and the 8 FLAG rows have regenerated audio URLs with DB and HTTP URL verification passing. Current verdict state is still 29 PASS, 62 PENDING, 8 FLAG, 0 FAIL because post-regeneration listening has not cleared those verdicts. Broad/full N4 rollout remains on hold pending the remaining audio-quality verdicts, post-regeneration FLAG review, continued pilot feedback over time, and native-speaker review when available.

## Current Position

Milestone: — (none in progress)
Status: Idle after v1.1 ship (2026-04-23)
Last activity: 2026-05-14 — Full N4 TTS machine QA was rerun through the Markdown report path. `docs/operations/plans/n4-pilot-tts-machine-report-2026-05-14.md` records 99/99 machine pass, 0 blockers, `elevenlabs/eleven_multilingual_v2` for all 99 targets, 378.044s total duration, and the same 11 `HIGH_SILENCE_RATIO` review-priority warnings. `docs/operations/plans/n4-pilot-tts-stt-assist-run-2026-05-14.md` records the optional Google STT assist run: 99/99 transcribed, 26 exact matches, 73 transcript mismatches, and 0 STT errors. These mismatches are review-priority signals, not automatic audio-fail verdicts. `docs/operations/plans/n4-human-audio-qa-delegated-ai-pass-application-2026-05-14.md` records delegated AI-assisted PASS application for the 26 no-signal rows; every applied row says it is not native-speaker review. `docs/operations/plans/n4-human-audio-qa-review-queue-2026-05-14.md` and `docs/operations/plans/n4-human-audio-qa-review-sheet-2026-05-14.html` captured the pre-flag state as 26 PASS rows and 73 pending P0/P1 review-signal rows. `docs/operations/plans/n4-human-audio-qa-stt-reconciliation-2026-05-14.md` plus CSV triage those 73 rows into 11 P0 machine-warning, 8 lexical-risk, 11 near Japanese match, 3 canonical match, and 40 mixed/Korean prompt STT-unreliable rows. `docs/operations/plans/n4-human-audio-qa-high-risk-listening-batch-2026-05-14.md` plus CSV/HTML extract the 19 first-listen rows: 11 P0 machine-warning and 8 lexical-risk. `docs/operations/plans/n4-human-audio-qa-lexical-risk-review-2026-05-14.md` plus CSV/HTML remain available as the 8-row lexical-risk-only focused batch, and `docs/operations/plans/n4-human-audio-qa-lexical-risk-flag-application-2026-05-14.md` records the delegated AI-assisted `FLAG` application from `docs/operations/plans/n4-human-audio-qa-lexical-risk-flags-reviewed-2026-05-14.csv`. `docs/operations/plans/n4-human-audio-qa-canonical-pass-application-2026-05-14.md` records delegated AI-assisted `PASS` application for the 3 canonical-match rows from `docs/operations/plans/n4-human-audio-qa-canonical-pass-reviewed-2026-05-14.csv`. `docs/operations/plans/n4-human-audio-qa-flag-regeneration-plan-2026-05-14.md` plus CSV extract all 8 current `FLAG` rows into exact lesson/target regeneration handoff rows without generating audio or changing verdicts. `docs/operations/plans/n4-flagged-tts-replacement-harness-2026-05-14.md` documents `apps/api/scripts/regenerate_n4_audio_qa_flagged_tts.py`, the dry-run-by-default targeted replacement path for those rows, and `docs/operations/plans/n4-human-audio-qa-flag-regeneration-results-2026-05-14.md` plus CSV record 8 regenerated rows, 8/8 DB URL matches, and 8/8 new audio URL HTTP checks passing. `docs/operations/plans/n4-human-audio-qa-near-canonical-review-2026-05-14.md` plus CSV/HTML now extract the remaining 11 near/canonical rows, and `docs/operations/plans/n4-human-audio-qa-mixed-prompt-review-2026-05-14.md` plus CSV/HTML extract the 40 mixed-prompt rows. `docs/operations/plans/n4-human-audio-qa-verdict-template-2026-05-14.csv` plus `apps/api/scripts/apply_n4_audio_qa_verdicts.py` provide a dry-run-first CSV apply path for remaining verdict updates. Current verdict state is 99 targets, 29 PASS, 62 PENDING, 8 FLAG, 0 FAIL, and 0 invalid because the regenerated audio still needs post-regeneration listening. HN4-011 remains in second limited N4 pilot, and broad/full N4 rollout remains HOLD until remaining audio-quality verdicts, FLAG post-regeneration review, continued pilot feedback over time, and native-speaker review are available. Mobile MY tab launch hardening remains documented as simulator on-screen smoke passed and physical-device screen smoke blocked by device lock in `docs/operations/plans/mobile-my-page-release-smoke-2026-05-12.md`.

Progress: v1.1 [██████████] 100% shipped

## Accumulated Context

### Decisions

Historical decisions logged in PROJECT.md Key Decisions table and archived milestone files (`.planning/milestones/v1.0-ROADMAP.md`, `.planning/milestones/v1.1-ROADMAP.md`).

### Pending Todos

- Mobile MY tab launch smoke — code hardening, automated verification, physical-device install/launch precheck, and simulator on-screen smoke are complete; higher-fidelity physical-device screen smoke remains blocked by device lock using `docs/operations/plans/mobile-my-page-release-smoke-2026-05-12.md`.
- N4 pilot seed operationalization — controlled learner-pilot exposure is approved for HN4-001 through HN4-010, full N4 coverage planning is opened, and staging coverage contracts plus derived priority queue are synced through HN4-011. Lesson 11+ closeout selected `topic-i-adjective-nominalization`; `lsc-n4-i-adjective-nominalization-001` has an `APPROVED` source-controlled delegated AI candidate review packet and is promoted to official limited-pilot lesson HN4-011. Configured DB seed check, published API list/detail smoke, API start/submit write smoke, HN4-011 lesson TTS audio QA, simulator mobile UAT, first aggregate pilot-feedback baseline plus two refreshes, full N4 pilot-batch TTS coverage audit, full N4 machine audio preflight, 2026-05-14 generated machine report, 2026-05-14 optional STT assist report, full N4 human audio QA packet preparation, prioritized human review queue/listening sheet generation, human-verdict tracker plus CSV apply setup, PASS-candidate split, 26 delegated AI-assisted PASS applications, 73-row STT reconciliation triage, 19-row high-risk listening batch, 8-row lexical-risk focused review batch, 8 delegated AI-assisted lexical-risk FLAG applications, 3 delegated AI-assisted canonical PASS applications, 8-row FLAG regeneration handoff, dry-run-first FLAG TTS replacement harness, 8-row FLAG audio regeneration result with DB/URL verification, 11-row near/canonical batch, and 40-row mixed-prompt batch all pass as evidence-gathering gates. Continued pilot feedback review over time, native-speaker review when available, 62 pending audio QA verdicts, and post-regeneration review for the 8 regenerated FLAG rows remain broad-rollout blockers.

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
Stopped at: HN4-011 second limited-pilot publish plus configured DB seed/list-detail/start-submit API smoke, lesson TTS audio QA, simulator mobile UAT, first aggregate pilot-feedback baseline plus two refreshes, full N4 pilot-batch TTS generation/coverage audit, full N4 machine audio preflight, 2026-05-14 generated machine report plus optional STT assist report, full N4 human audio QA packet preparation, human-verdict tracker plus CSV apply setup, PASS-candidate split, 26 delegated AI-assisted PASS applications, 73-row STT reconciliation triage, focused review batches for all STT lanes, 8 delegated lexical-risk FLAG applications, 3 delegated canonical PASS applications, 8-row FLAG regeneration handoff, dry-run-first FLAG TTS replacement harness, and 8-row FLAG audio regeneration result with DB/URL verification complete; continued pilot feedback over time, native-speaker review when available, 62 pending audio QA verdicts, and post-regeneration review for the 8 regenerated FLAG rows remain blockers for broader N4 rollout
Resume file: `docs/operations/release/v1.1-stabilization-checkpoint-2026-04-23.md`
