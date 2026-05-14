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
STT mismatch reconciliation report:
`docs/operations/plans/n4-human-audio-qa-stt-reconciliation-2026-05-14.md`.
STT mismatch reconciliation CSV:
`docs/operations/plans/n4-human-audio-qa-stt-reconciliation-2026-05-14.csv`.
High-risk listening batch:
`docs/operations/plans/n4-human-audio-qa-high-risk-listening-batch-2026-05-14.md`.
High-risk listening CSV:
`docs/operations/plans/n4-human-audio-qa-high-risk-listening-batch-2026-05-14.csv`.
High-risk listening HTML sheet:
`docs/operations/plans/n4-human-audio-qa-high-risk-listening-batch-2026-05-14.html`.
LEXICAL_RISK focused review batch:
`docs/operations/plans/n4-human-audio-qa-lexical-risk-review-2026-05-14.md`.
LEXICAL_RISK focused review CSV:
`docs/operations/plans/n4-human-audio-qa-lexical-risk-review-2026-05-14.csv`.
LEXICAL_RISK focused HTML listening sheet:
`docs/operations/plans/n4-human-audio-qa-lexical-risk-review-2026-05-14.html`.
LEXICAL_RISK delegated FLAG application report:
`docs/operations/plans/n4-human-audio-qa-lexical-risk-flag-application-2026-05-14.md`.
LEXICAL_RISK delegated FLAG reviewed CSV:
`docs/operations/plans/n4-human-audio-qa-lexical-risk-flags-reviewed-2026-05-14.csv`.
Near/canonical focused review batch:
`docs/operations/plans/n4-human-audio-qa-near-canonical-review-2026-05-14.md`.
Near/canonical focused review CSV:
`docs/operations/plans/n4-human-audio-qa-near-canonical-review-2026-05-14.csv`.
Near/canonical focused HTML listening sheet:
`docs/operations/plans/n4-human-audio-qa-near-canonical-review-2026-05-14.html`.
Mixed-prompt focused review batch:
`docs/operations/plans/n4-human-audio-qa-mixed-prompt-review-2026-05-14.md`.
Mixed-prompt focused review CSV:
`docs/operations/plans/n4-human-audio-qa-mixed-prompt-review-2026-05-14.csv`.
Mixed-prompt focused HTML listening sheet:
`docs/operations/plans/n4-human-audio-qa-mixed-prompt-review-2026-05-14.html`.

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

The generated review queue and static HTML listening sheet originally ordered
11 P0 machine-warning rows, then 62 P1 STT-only mismatch rows. The previous 26
P2 no-signal rows were applied as delegated AI-assisted `PASS` verdicts in
`docs/operations/plans/n4-human-audio-qa-delegated-ai-pass-application-2026-05-14.md`.
Those verdict notes explicitly state that they are not native-speaker review.

The STT reconciliation report split the 73 unresolved P0/P1 rows into review
lanes before any lexical-risk flags were applied:

- 11 `P0_MACHINE_WARNING`
- 8 `LEXICAL_RISK`
- 11 `NEAR_JAPANESE_MATCH`
- 3 `CANONICAL_MATCH`
- 40 `MIXED_PROMPT_STT_UNRELIABLE`

Use that order after the P0 queue: lexical-risk script rows first, then
near/canonical script rows for delegated PASS consideration after spot listening,
then mixed/Korean question prompts where STT mismatch alone is weak evidence.

The high-risk listening batch extracts the 19 first-listen rows into Markdown,
CSV, and a static HTML listening sheet: 11 `P0_MACHINE_WARNING` rows plus 8
`LEXICAL_RISK` rows. It applies no verdicts; fill only `new_verdict` and
`new_notes` in the CSV after direct listening or an explicitly delegated review
step.

The LEXICAL_RISK focused batch extracts those 8 highest-risk script rows into
Markdown, CSV, and a static HTML listening sheet. It applies no verdicts; fill
only `new_verdict` and `new_notes` in the CSV after direct listening or an
explicitly delegated review step.

The remaining lower-risk STT lanes are also split into focused Markdown, CSV,
and HTML listening sheets: 14 `NEAR_JAPANESE_MATCH` / `CANONICAL_MATCH` rows
and 40 `MIXED_PROMPT_STT_UNRELIABLE` rows. These batches complete the review
handoff coverage for the unresolved STT lanes, but they do not apply verdicts.

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

## Delegated AI-Assisted LEXICAL_RISK FLAG Application

The 8 `LEXICAL_RISK` script rows were marked `FLAG` using the reviewed CSV:

```bash
cd apps/api
uv run python scripts/apply_n4_audio_qa_verdicts.py \
  --csv-input ../../docs/operations/plans/n4-human-audio-qa-lexical-risk-flags-reviewed-2026-05-14.csv \
  --write
```

Every applied row carries this note:

> Delegated AI-assisted FLAG: STT/source lexical divergence suggests possible wrong-word audio; regenerate or direct-listen before broad rollout; not native-speaker review.

Post-flag verdict state: 99 targets, 26 `PASS`, 65 `PENDING`, 8 `FLAG`, 0
`FAIL`, and 0 invalid verdicts. The 8 `FLAG` rows need regeneration, direct
listening waiver, or native-speaker review before broad/full N4 rollout.

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

Current state after delegated AI-assisted PASS application:

- 3 packets
- 99 review targets
- 26 `PASS`
- 73 `PENDING`
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
