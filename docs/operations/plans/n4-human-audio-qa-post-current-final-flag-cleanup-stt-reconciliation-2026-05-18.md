# N4 Audio QA STT Reconciliation

> Status: TRIAGE ONLY - no verdicts applied
> Boundary: STT mismatch reconciliation only; does not replace listening or native-speaker review

ASSUMPTION: This report helps reduce review ambiguity while preserving
the current verdict gate. It does not set `PASS`, `FLAG`, `FAIL`, or
`WAIVED` on any packet row.

## Sources

- Packet: `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md`
- Packet: `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md`
- Packet: `docs/operations/plans/n4-pilot-human-audio-qa-ch03-2026-05-13.md`
- Quality signal report: `docs/operations/plans/n4-pilot-tts-machine-report-2026-05-14.md`
- Quality signal report: `docs/operations/plans/n4-pilot-tts-stt-assist-run-2026-05-14.md`

## Summary

| Metric | Count |
|---|---:|
| Total review items | 99 |
| Pending review-signal items | 0 |
| P0 machine-warning retained first | 0 |
| P1 STT-only items | 0 |
| Canonical text matches | 0 |
| Near Japanese matches | 0 |
| Mixed/Korean prompt STT-unreliable | 0 |
| Lexical-risk Japanese mismatches | 0 |
| Missing STT transcript | 0 |

## Review Order

1. Listen to `P0_MACHINE_WARNING` rows first because high silence ratio
   can hide pacing or truncation problems even when the audio file exists.
2. Review `LEXICAL_RISK` rows next because the transcript diverges from
   the source enough to suggest possible wrong-word audio.
3. Use `NEAR_JAPANESE_MATCH` and `CANONICAL_MATCH` rows as lower-risk
   candidates for delegated PASS after a spot listen.
4. Treat `MIXED_PROMPT_STT_UNRELIABLE` as a prompt-design/STT limitation;
   decide by direct playback rather than transcript mismatch alone.

## CSV Apply Boundary

The companion CSV leaves `new_verdict` and `new_notes` blank. Fill those
columns only after direct listening or an explicitly delegated review step.


## P0_MACHINE_WARNING

- None

## LEXICAL_RISK

- None

## NEAR_JAPANESE_MATCH

- None

## CANONICAL_MATCH

- None

## MIXED_PROMPT_STT_UNRELIABLE

- None

## NO_STT_TRANSCRIPT

- None

## Decision

Broad/full N4 rollout remains blocked. This triage only narrows the
remaining 0 pending review-signal audio QA rows
into review lanes and does not lower the verdict gate by itself.
