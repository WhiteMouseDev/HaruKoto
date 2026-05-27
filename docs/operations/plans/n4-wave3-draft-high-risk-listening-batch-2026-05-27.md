# N4 Audio QA High-Risk Listening Batch

> Status: LISTENING BATCH - no verdicts applied
> Boundary: high-risk audio review surface only; does not approve rollout

ASSUMPTION: This batch only separates rows that should be listened to
first. It does not set `PASS`, `FLAG`, `FAIL`, or `WAIVED` on any packet
row, and it does not replace native-speaker review.

## Sources

- Packet: `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md`
- Quality signal report: `docs/operations/plans/n4-wave3-draft-tts-machine-report-2026-05-27.md`
- Quality signal report: `docs/operations/plans/n4-wave3-draft-tts-stt-assist-run-2026-05-27.md`
- Quality signal report: `docs/operations/plans/n4-wave3-draft-tts-stt-timeout-retry-2026-05-27.md`
- Quality signal report: `docs/operations/plans/n4-wave3-draft-lexical-risk-stt-retry-2026-05-27.md`

## Summary

| Metric | Count |
|---|---:|
| Total review items | 45 |
| Pending review-signal items | 35 |
| High-risk listening batch | 0 |
| P0 machine-warning rows | 0 |
| Lexical-risk rows | 0 |

## Review Sequence

1. Listen to `P0_MACHINE_WARNING` rows first. These rows include machine
   warnings such as silence-ratio signals, so pacing or truncation can hide
   behind an otherwise reachable audio URL.
2. Listen to `LEXICAL_RISK` rows next. These rows have Japanese source/STT
   divergence large enough that wrong-word audio is plausible.
3. Leave `new_verdict` and `new_notes` blank until direct listening or an
   explicitly delegated review step confirms the audio quality.

## P0_MACHINE_WARNING

- None

## LEXICAL_RISK

- None

## CSV And HTML Use

The companion CSV is an input worksheet only. The HTML file is a static
listening surface with audio controls. Neither file applies verdicts.

## Decision

Broad/full N4 rollout remains blocked. This batch makes the first listening
slice explicit but does not lower the audio-quality verdict gate.
