# N4 Pilot Human Audio QA Packets

> Date: 2026-05-13
> Scope: published N4 controlled-pilot lesson TTS, HN4-001 through HN4-011
> Status: REVIEW PACKETS READY - human verdicts pending

## Boundary

This document indexes the human listening QA packets for all generated N4 pilot
lesson TTS targets. It does not claim pronunciation approval, native-speaker
review, or broad/full N4 rollout approval.

ASSUMPTION: Preparing review packets for all generated targets removes the
packet-preparation blocker, but human verdicts are still required before
broad/full rollout.

## Packet Inventory

| Packet | Lessons | Script-line targets | Question-prompt targets | Total targets | URL status |
|---|---:|---:|---:|---:|---|
| `n4-pilot-human-audio-qa-ch01-2026-05-13.md` | 5 | 20 | 25 | 45 | 0 missing / 0 failed |
| `n4-pilot-human-audio-qa-ch02-2026-05-13.md` | 5 | 20 | 25 | 45 | 0 missing / 0 failed |
| `n4-pilot-human-audio-qa-ch03-2026-05-13.md` | 1 | 4 | 5 | 9 | 0 missing / 0 failed |
| **Total** | **11** | **44** | **55** | **99** | **0 missing / 0 failed** |

## Machine Preflight Context

The automated audio preflight passed all 99 generated TTS targets with 0 machine
blockers. It found 11 non-blocking `HIGH_SILENCE_RATIO` warnings that should be
prioritized during listening:

| Packet | Warning targets |
|---|---|
| Chapter 1 | `HN4-001 question:3`, `HN4-002 question:4`, `HN4-003 question:3`, `HN4-003 question:4`, `HN4-004 question:4`, `HN4-005 question:4` |
| Chapter 2 | `HN4-006 question:4`, `HN4-008 question:3`, `HN4-009 question:4`, `HN4-010 question:4` |
| Chapter 3 | `HN4-011 question:3` |

Source: `docs/operations/plans/n4-pilot-tts-audio-quality-preflight-2026-05-13.md`.
Latest generated machine report:
`docs/operations/plans/n4-pilot-tts-machine-report-2026-05-14.md`.
Prioritized human review queue:
`docs/operations/plans/n4-human-audio-qa-review-queue-2026-05-14.md`.
Static listening sheet with audio controls:
`docs/operations/plans/n4-human-audio-qa-review-sheet-2026-05-14.html`.
Verdict CSV template:
`docs/operations/plans/n4-human-audio-qa-verdict-template-2026-05-14.csv`.
AI-assisted PASS candidate report:
`docs/operations/plans/n4-human-audio-qa-pass-candidates-2026-05-14.md`.
AI-assisted PASS candidate CSV:
`docs/operations/plans/n4-human-audio-qa-pass-candidates-2026-05-14.csv`.
AI-assisted PASS candidate HTML listening sheet:
`docs/operations/plans/n4-human-audio-qa-pass-candidates-2026-05-14.html`.
Delegated AI-assisted PASS application report:
`docs/operations/plans/n4-human-audio-qa-delegated-ai-pass-application-2026-05-14.md`.

The same preflight script now has an opt-in AI STT assist for cases where a
human listener is not immediately available:

```bash
cd apps/api
uv run python scripts/audit_n4_pilot_tts_audio_quality.py \
  --level N4 \
  --transcribe \
  --json \
  --markdown-output ../../docs/operations/plans/n4-pilot-tts-stt-assist-run-2026-05-14.md
```

`TRANSCRIPTION_TEXT_MISMATCH` should be treated as a review-priority signal
unless strict blocker mode is explicitly selected. It must not be used to
auto-fill `PASS` verdicts because transcript differences can be orthographic
rather than pronunciation failures.

The Markdown output is the handoff artifact for reviewing mismatches, STT
errors, and existing machine warnings before editing the chapter-packet
verdicts.

Latest optional STT assist report:
`docs/operations/plans/n4-pilot-tts-stt-assist-run-2026-05-14.md`.
It transcribed all 99 targets with 26 exact matches, 73 transcript mismatches,
and 0 STT errors. Treat the mismatches as review-priority signals, not automatic
`FLAG` or `FAIL` verdicts.

Use the generated review queue or static HTML listening sheet in this order:
11 P0 machine-warning rows, then 62 P1 STT-only mismatch rows. The previous 26
P2 no-signal rows were applied as delegated AI-assisted `PASS` verdicts in
`docs/operations/plans/n4-human-audio-qa-delegated-ai-pass-application-2026-05-14.md`.
Those verdict notes explicitly state that they are not native-speaker review.

## CSV Verdict Apply Flow

Reviewers may fill only `new_verdict` and `new_notes` in the verdict template.
Leave both columns blank for rows that are not reviewed yet.
`priority` and `review_signals` are read-only context columns for deciding
which rows to listen to first.

Dry-run before writing packet Markdown:

```bash
cd apps/api
uv run python scripts/apply_n4_audio_qa_verdicts.py \
  --csv-input ../../docs/operations/plans/n4-human-audio-qa-verdict-template-2026-05-14.csv
```

Apply reviewed rows after the dry-run output matches expectation:

```bash
cd apps/api
uv run python scripts/apply_n4_audio_qa_verdicts.py \
  --csv-input ../../docs/operations/plans/n4-human-audio-qa-verdict-template-2026-05-14.csv \
  --write
```

The script rejects unsupported verdict values and fails if a CSV target cannot
be matched back to the packet Markdown.

## Delegated AI-Assisted PASS Application

Because no native-speaker reviewer is currently available, the project owner
delegated the no-signal candidate rows to AI-assisted review. The 26 rows with
machine pass evidence and no parsed machine/STT review signal were applied as
`PASS` using:

```bash
cd apps/api
uv run python scripts/apply_n4_audio_qa_verdicts.py \
  --csv-input ../../docs/operations/plans/n4-human-audio-qa-pass-candidates-reviewed-2026-05-14.csv \
  --write
```

Every applied row carries this note:

> Delegated AI-assisted PASS: machine pass + no parsed machine/STT review signal; not native-speaker review.

Post-apply verdict state: 99 targets, 26 `PASS`, 73 `PENDING`, 0 `FLAG`, 0
`FAIL`, and 0 invalid verdicts. The remaining 73 P0/P1 rows continue to block
broad/full N4 rollout.

## Review Rules

- Every item starts as `PENDING`.
- A `PASS` verdict means the audio is complete, intelligible, and acceptable for
  learner playback.
- A `FLAG` verdict should block broad rollout until the item is waived or
  regenerated.
- A `FAIL` verdict should block broad rollout until fixed.
- These packets do not replace native-speaker curriculum review.

## Verdict Progress Check

After reviewers update the chapter packets, run the read-only verdict tracker:

```bash
cd apps/api
uv run python scripts/report_n4_audio_qa_verdicts.py --fail-on-blocker
```

Current initial state:

- 3 packets
- 99 review targets
- 0 `PASS`
- 99 `PENDING`
- 0 `FLAG`
- 0 `FAIL`

`--fail-on-blocker` exits non-zero while `PENDING`, `FLAG`, `FAIL`, or invalid
verdict values remain. This is the machine gate for the human audio verdict
step; it does not perform listening review itself.

## Decision

All human audio QA packets for the current published N4 pilot TTS set are ready.
This closes the packet-preparation task for 99 generated targets.

Broad/full N4 rollout remains on HOLD until the actual human audio verdicts are
recorded and any `FLAG` or `FAIL` items are resolved or explicitly waived.
