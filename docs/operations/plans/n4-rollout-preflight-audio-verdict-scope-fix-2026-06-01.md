# N4 Rollout Preflight Audio Verdict Scope Fix

> Date: 2026-06-01
> Scope: N4 broad/full rollout preflight harness and audio QA verdict packet
> coverage
> Status: harness fixed; broad N4 preflight correctly blocked

## Boundary

This is a read-only harness correction and verification note. It does not seed
lesson rows, generate TTS, modify TTS URLs, apply audio QA verdicts, approve
native-speaker review, or change learner exposure.

ASSUMPTION: CH06 machine audio QA and STT-assist reports are useful review
signals, but they are not the same artifact as an audio QA verdict packet. Until
HN4-022 through HN4-026 have an included verdict packet, broad/full N4 rollout
must remain blocked even when CH06 controlled-pilot exposure is acceptable.

## Problem

The default N4 audio verdict report covered CH01 through CH04 only. CH05 already
had a 45-target PASS packet, but it was not included by default. The N4 rollout
preflight also checked whether the included verdict packet set was internally
clean, but did not compare the verdict target count against the current
learner-facing TTS target count.

That meant an older passing packet set could be mistaken for broad N4 audio QA
coverage after new published lessons increased the TTS target count.

## Change

- `report_n4_audio_qa_verdicts.py` now includes the CH05 verdict packet in the
  default packet set.
- `report_n4_rollout_preflight.py` now reports `audio_qa_target_coverage` and
  emits `AUDIO_QA_TARGET_MISMATCH` when audio verdict targets lag current TTS
  targets.
- The preflight now runs `pnpm` with the detected `pnpm` bin directory first in
  `PATH`, so `uv run` does not accidentally pair a package-manager shim with an
  older Homebrew `node`.
- The runbook now describes dynamic target-count matching instead of a stale
  fixed `144/144` N4 requirement.

## Evidence

| Check | Result | Evidence |
|---|---|---|
| Audio verdict aggregation | PASS | Default packets now include CH01, CH02, CH03, CH04, and CH05. Output: 189 targets, 189 PASS, 0 pending, 0 flag, 0 fail, 0 invalid, 0 blockers. |
| N4 preflight, URL check skipped | BLOCKED as expected | `curriculum_validate`, `lesson_seed_sync_check`, `tts_coverage`, and `audio_qa_verdicts` commands all exited 0. TTS coverage is 234/234, audio verdict coverage is 189/234. |
| Blocker | PASS | The only rollout blocker after the harness fix is `AUDIO_QA: AUDIO_QA_TARGET_MISMATCH: 189 verdict target(s) for 234 expected learner-facing TTS record(s)`. |

Commands:

```bash
cd apps/api
uv run python scripts/report_n4_audio_qa_verdicts.py --json
uv run python scripts/report_n4_rollout_preflight.py --level N4 --skip-audio-urls --json
```

Focused code checks:

```bash
cd apps/api
uv run ruff check scripts/report_n4_audio_qa_verdicts.py scripts/report_n4_rollout_preflight.py tests/test_report_n4_audio_qa_verdicts.py tests/test_report_n4_rollout_preflight.py
uv run ruff format --check scripts/report_n4_audio_qa_verdicts.py scripts/report_n4_rollout_preflight.py tests/test_report_n4_audio_qa_verdicts.py tests/test_report_n4_rollout_preflight.py
uv run pytest tests/test_report_n4_audio_qa_verdicts.py tests/test_report_n4_rollout_preflight.py
```

## Decision

The controlled CH06 pilot can remain exposed under its existing limited-go
decision, but broad/full N4 rollout is not ready. The next unblocked content
operation is to produce and include a CH06 audio QA verdict packet, then rerun
the same preflight until audio verdict coverage matches the current TTS target
count.
