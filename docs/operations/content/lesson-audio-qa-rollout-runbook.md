# Lesson Seed/TTS Rollout Runbook

> Scope: lesson source data, configured API DB seed sync, generated lesson TTS,
> and audio QA verdict gates.
> Boundary: this runbook proves operational readiness. It does not replace
> native-speaker curriculum review.

ASSUMPTION: Until a human/native-speaker reviewer is available, HaruKoto uses
delegated AI/STT-assisted audio QA as an explicit limited gate, not as a claim
of expert approval.

## N4 Current Gate

The current N4 learner-facing audio gate is clear when this command passes:

```bash
cd apps/api
uv run python scripts/report_n4_rollout_preflight.py \
  --level N4 \
  --fail-on-blocker \
  --markdown-output ../../docs/operations/plans/n4-seed-tts-rollout-preflight-2026-05-20.md
```

Required passing signals:

| Gate | Required result |
|---|---|
| Curriculum contracts | `pnpm --filter @harukoto/database curriculum:validate` exits 0 |
| Configured DB seed sync | `uv run python -m app.seeds.lessons --check --level N4` exits 0 |
| TTS coverage | generated record count equals the current published N4 learner-facing TTS target count |
| TTS URL validation | every generated audio URL passes read-only HTTP validation |
| Audio QA verdicts | verdict target count equals the current TTS target count, and all verdicts are PASS with 0 PENDING, 0 FLAG, 0 FAIL, 0 invalid |

`GOOGLE_API_KEY` is not required for this preflight. It is only needed for
separate optional STT-assist flows that explicitly pass `--transcribe`.

## Operational Sequence

Use this sequence after a content or TTS QA PR merges to `main`.

1. Confirm the PR is merged and CI is green.
2. Update local `main` and verify the worktree is clean.
3. Run the preflight command above against the target environment variables.
4. If seed sync fails because source content changed, run the approved seed
   apply for that target DB:

```bash
cd apps/api
uv run python -m app.seeds.lessons --level N4
```

5. Re-run the preflight. Do not continue while any blocker remains.
6. If TTS coverage is missing, generate or regenerate only the missing/flagged
   targets through the existing lesson TTS service scripts. Do not edit
   `tts_audio` rows manually.
7. If audio QA verdicts are not clear, build a regeneration/review packet,
   regenerate the affected rows, then apply verdicts through
   `scripts/apply_n4_audio_qa_verdicts.py`.
   If the preflight reports `AUDIO_QA_TARGET_MISMATCH`, first add or include the
   missing audio QA packet for the newly published lesson slice; do not treat
   passing older chapter packets as broad-level audio coverage.
8. Record a short evidence note under `docs/operations/plans/` with the command
   output, target DB scope, and any remaining limitation.

## Rollout Decision Boundary

Passing N4 preflight means:

- source JSON, generated manifests, configured DB lesson content, TTS records,
  TTS URLs, and packet verdicts agree;
- no known audio QA blocker remains for the N4 pilot packet set;
- the N4 pilot can move to the next controlled rollout decision.

After the 2026-06-01 CH06 audio QA closeout, the current N4 broad exposure
decision is BETA-WIDE GO for the existing 26-lesson N4 pilot slice. See
`docs/operations/plans/n4-broad-exposure-decision-2026-06-01.md`.

Use the level-wide feedback monitor after broad exposure is opened:

```bash
cd apps/api
uv run python scripts/report_level_pilot_feedback.py \
  --level N4 \
  --since-days 14 \
  --fail-on-blocker \
  --markdown-output ../../docs/operations/plans/n4-broad-exposure-feedback-refresh-YYYY-MM-DD.md
```

Passing N4 preflight does not mean:

- the N4 course is complete;
- native-speaker review is complete;
- N3/N2/N1 lessons can reuse N4 verdicts without their own gate;
- external marketing can claim full N4 coverage without a fresh product
  decision.

## N3+ Expansion Gate

Before promoting any N3, N2, or N1 lesson into learner-facing pilot status,
require the same contract shape as N4:

| Gate | Requirement |
|---|---|
| Source originality | Paid/reference PDFs are topic/order references only; examples, dialogue, and questions are HaruKoto-authored |
| JLPT scope | Every lesson has an explicit grammar/topic target and does not smuggle higher-level grammar into lower-level practice |
| Candidate packet | Candidate review packet exists and has reviewer decisions recorded |
| Runtime-safe questions | Question types are supported by API, web, and mobile consumers |
| TTS target manifest | Example/script/question targets are derived and validated |
| Configured DB seed sync | `app.seeds.lessons --check --level <LEVEL>` passes after seed apply |
| TTS generation | Every learner-facing script line and question prompt has a `tts_audio` record |
| TTS URL validation | Every generated URL passes read-only HTTP validation |
| Audio QA packet | Human/delegated packet has explicit `PASS`, `FLAG`, or `FAIL` for every target |
| Blocker policy | `PENDING`, `FLAG`, `FAIL`, and invalid verdicts block broad rollout |
| UAT | At least one lesson detail, answer submission, retry, and TTS playback path is exercised on the target app surface |

For N3/N2/N1, add stricter content review before TTS generation:

- check register and politeness consistency;
- check long sentence parsing and clause boundary clarity;
- avoid homophones or orthographic traps in TTS-critical lines unless the lesson
  explicitly teaches them;
- keep Korean translations literal enough to preserve grammar contrast;
- record any AI-only judgment as delegated review, not expert approval.

## Rollback Path

If a preflight or rollout monitor finds a P0/P1 issue:

1. Stop expanding exposure for the affected level.
2. Unpublish or reseed the affected lesson rows in the configured DB, or hide
   the level selector if the issue is client-side.
3. Regenerate only the affected TTS targets if audio is wrong or stale.
4. Re-run seed sync, TTS coverage, audio verdict, and the affected app UAT path.
5. Record the incident and updated decision under `docs/operations/plans/`.
