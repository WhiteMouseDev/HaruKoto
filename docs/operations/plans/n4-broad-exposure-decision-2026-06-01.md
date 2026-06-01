# N4 Broad Exposure Decision

> Date: 2026-06-01
> Scope: N4 CH01 through CH06, HN4-001 through HN4-026
> Decision: BETA-WIDE GO for in-app/free-user N4 pilot exposure
> Boundary: not a complete N4 course claim and not native-speaker approval

## Decision

Expand N4 from chapter-by-chapter controlled pilot exposure to beta-wide
in-app exposure for all currently published N4 `PILOT` lessons.

This means:

- Existing beta/free users who select N4 may access HN4-001 through HN4-026.
- The lessons remain `meta.status = PILOT`; no source JSON status change to
  `PUBLISHED` is required for this decision.
- No mobile reinstall is required for lesson-list exposure because the app
  fetches the published lesson list from the API.
- Learner traffic and feedback should now be collected across the whole N4
  pilot slice, not only one chapter at a time.

This does not mean:

- HaruKoto can market a complete N4 curriculum.
- N4 content has native-speaker or formal human approval.
- N4 CH07+ or N3/N2/N1 can skip the same seed, TTS, audio QA, UAT, and monitor
  gates.

ASSUMPTION: Broad exposure here means app-internal beta/free learner access to
the current 26-lesson N4 pilot slice. It is not an externally marketed full N4
launch.

## Gate Evidence

| Gate | Result | Evidence |
|---|---:|---|
| Source scope | PASS | `apps/api/app/seeds/lessons.py` includes six N4 seed files, CH01 through CH06 |
| Published lesson count | PASS | Configured DB seed check reports 6 chapters and 26 lessons |
| Curriculum contracts | PASS | `pnpm --filter @harukoto/database curriculum:validate` exits 0 |
| Seed sync | PASS | `python -m app.seeds.lessons --check --level N4` exits 0 |
| TTS coverage | PASS | 234/234 learner-facing TTS records exist |
| TTS URL validation | PASS | 234/234 audio URLs passed read-only HTTP validation |
| Audio QA verdicts | PASS | 234/234 PASS, 0 pending, 0 flag, 0 fail, 0 invalid |
| Level-wide feedback monitor | PASS | 26 published lessons, 26/26 TTS-ready, 3 lessons with progress, 23 waiting for traffic, 0 blockers |
| CI / deploy | PASS | PR #169 merged into `main` at `aebc779`; main CI and Deploy API passed |

Primary evidence files:

- `docs/operations/plans/n4-broad-exposure-preflight-2026-06-01.md`
- `docs/operations/plans/n4-broad-exposure-feedback-baseline-2026-06-01.md`
- `docs/operations/plans/n4-ch06-audio-qa-delegated-closeout-2026-06-01.md`

## Operating Guardrails

- Keep product/admin wording as N4 pilot or beta coverage, not complete N4.
- Run the level-wide feedback monitor after broad exposure starts receiving
  traffic, then keep periodic refreshes while the pilot is active.
- Treat the following as immediate rollback triggers:
  - impossible quiz or answer-key mismatch;
  - repeated API lesson detail/start/submit errors;
  - repeated mobile crash on N4 lesson list/detail/quiz/result;
  - visible TTS 404, wrong audio, or unusable playback;
  - content issue that changes the taught grammar meaning.
- Treat low or confusing learner outcomes as investigation triggers even when
  they are not automatic rollback blockers.

## Monitoring Commands

```bash
cd apps/api
uv run python scripts/report_n4_rollout_preflight.py \
  --level N4 \
  --check-audio-urls \
  --fail-on-blocker
```

```bash
cd apps/api
uv run python scripts/report_level_pilot_feedback.py \
  --level N4 \
  --since-days 14 \
  --fail-on-blocker
```

## Rollback Path

If broad N4 pilot exposure reveals a P0/P1 runtime, content, or audio blocker:

1. Stop expanding N4 exposure and record the incident under
   `docs/operations/plans/`.
2. If the issue is lesson-specific, change the affected chapter seed file back
   to `DRAFT` or remove it from the configured N4 seed registry.
3. Re-apply the target DB lesson seed with `uv run python -m app.seeds.lessons
   --level N4`.
4. Re-run seed check, TTS coverage, audio QA verdict report, level-wide
   feedback monitor, and the affected mobile/API smoke path.
5. Re-open this decision before resuming broad exposure.
