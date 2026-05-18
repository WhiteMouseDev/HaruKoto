# N4 Delegated Mixed-Prompt Audio QA Application

> Status: APPLIED - rollout still HOLD
> Scope: N4 packet rows that remained `PENDING` after final FLAG clearance
> Date: 2026-05-18

## Boundary

This pass applies delegated AI-assisted verdicts only to question prompts where
the STT mismatch is structurally unreliable because the prompt mixes Japanese,
Korean, cloze blanks, or Korean arrangement instructions.

ASSUMPTION: For mixed-prompt question audio with no `HIGH_SILENCE_RATIO` machine
warning, a single-language Japanese STT mismatch is weak evidence of audio
failure. This does not equal native-speaker approval.

Rows with high-silence machine warnings or script-line near matches remain
`PENDING` because they require direct listening or regeneration judgment.

## Application Summary

| Metric | Count |
|---|---:|
| Packet targets | 99 |
| Previous PASS | 37 |
| Previous PENDING | 62 |
| Delegated mixed-prompt PASS applied | 40 |
| Current PASS | 77 |
| Current PENDING | 22 |
| Current FLAG | 0 |
| Current FAIL | 0 |

## Applied Evidence

- Clearance report: `docs/operations/plans/n4-human-audio-qa-delegated-mixed-prompt-clearance-2026-05-18.md`
- Apply CSV: `docs/operations/plans/n4-human-audio-qa-delegated-mixed-prompt-clearance-2026-05-18.csv`
- Post-application review queue: `docs/operations/plans/n4-human-audio-qa-post-mixed-prompt-review-queue-2026-05-18.md`
- Post-application STT reconciliation: `docs/operations/plans/n4-human-audio-qa-post-mixed-prompt-stt-reconciliation-2026-05-18.md`

## Remaining Pending Buckets

| Bucket | Count | Reason held |
|---|---:|---|
| `P0_MACHINE_WARNING` | 11 | High silence ratio can hide spacing, clipping, or prompt-shape problems even when the file exists. |
| `NEAR_JAPANESE_MATCH` | 11 | Script-line transcript is close but may alter punctuation, sentence mood, word choice, or lexical target. |

## Remaining Pending Targets

### P0 Machine Warning

- `HN4-001 question:3`
- `HN4-002 question:4`
- `HN4-003 question:3`
- `HN4-003 question:4`
- `HN4-004 question:4`
- `HN4-005 question:4`
- `HN4-006 question:4`
- `HN4-008 question:3`
- `HN4-009 question:4`
- `HN4-010 question:4`
- `HN4-011 question:3`

### Near Japanese Match

- `HN4-002 script:0`
- `HN4-002 script:2`
- `HN4-004 script:0`
- `HN4-004 script:1`
- `HN4-005 script:1`
- `HN4-005 script:2`
- `HN4-006 script:1`
- `HN4-008 script:2`
- `HN4-011 script:0`
- `HN4-011 script:2`
- `HN4-011 script:3`

## Decision

The mixed-prompt false-positive lane is cleared. Broad/full N4 rollout remains
blocked by 22 pending rows until those rows are either directly listened to,
regenerated, or explicitly waived with rationale.
