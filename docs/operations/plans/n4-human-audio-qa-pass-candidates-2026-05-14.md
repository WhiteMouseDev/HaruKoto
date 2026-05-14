# N4 Audio QA AI-Assisted PASS Candidates

> Status: PASS CANDIDATES - no verdicts applied
> Boundary: machine/STT-assisted triage only; does not approve rollout

ASSUMPTION: A candidate means the target is still `PENDING`, has machine
audio pass evidence, and has no parsed machine/STT review signal. It is
not a final human audio-quality verdict.

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
| Pending verdicts | 73 |
| AI-assisted PASS candidates | 0 |
| Held for listening/regeneration review | 73 |
| Machine-warning items | 11 |
| STT-mismatch signal items | 73 |

## Candidate Criteria

- Current verdict is `PENDING`.
- Priority is `P2 pending` in the review queue.
- No parsed `HIGH_SILENCE_RATIO`, `TRANSCRIPTION_TEXT_MISMATCH`, or other machine/STT review signal is attached.
- Candidate status only reduces review order; it does not replace listening.

## Candidate CSV Contract

The companion CSV leaves `new_verdict` and `new_notes` blank on purpose.
After listening, set `new_verdict=PASS` only for rows that are complete,
intelligible, and acceptable for learner playback. Keep uncertain rows
`PENDING`, or mark `FLAG` / `FAIL` in the source verdict workflow.

## Candidates

- None

## Held Items

P0 machine-warning and P1 STT-mismatch rows stay out of the candidate CSV.
They should be listened to before waiver or regenerated if the signal is
confirmed as a content, clipping, pacing, pronunciation, or prompt-shape issue.

## Decision

Use this file to batch the safest listen-once checks first. Broad/full N4
rollout remains blocked until packet verdicts contain no `PENDING`,
`FLAG`, `FAIL`, or invalid values.
