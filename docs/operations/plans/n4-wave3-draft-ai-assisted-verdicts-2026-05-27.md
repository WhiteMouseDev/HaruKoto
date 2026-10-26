# N4 Wave 3 Draft AI-Assisted Audio Verdicts

> Date: 2026-05-27
> Status: PARTIAL VERDICTS READY TO APPLY
> Boundary: AI-assisted and machine/STT-assisted review only; not native-speaker approval

## Sources

- `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md`
- `docs/operations/plans/n4-wave3-draft-tts-machine-report-2026-05-27.md`
- `docs/operations/plans/n4-wave3-draft-tts-stt-assist-run-2026-05-27.md`
- `docs/operations/plans/n4-wave3-draft-tts-stt-timeout-retry-2026-05-27.md`
- `docs/operations/plans/n4-wave3-draft-lexical-risk-stt-retry-2026-05-27.md`
- `docs/operations/plans/n4-wave3-draft-tts-stt-no-transcript-retry-2026-05-27.md`
- `docs/operations/plans/n4-wave3-draft-delegated-pending-clearance-2026-05-27.md`
- `docs/operations/plans/n4-wave3-draft-pass-candidates-2026-05-27.md`

ASSUMPTION: Rows with no parsed machine/STT review signal, or a 60-second
STT retry exact match after a previous timeout, can receive delegated
AI-assisted `PASS` while preserving the native-speaker-review boundary.

## Decision

Apply 9 additional AI-assisted `PASS` verdicts after the mixed-prompt
clearance pass:

- 6 script rows with machine audio pass and no parsed STT or machine review
  signal.
- 3 script rows where the 60-second STT retry resolved the previous timeout
  and matched the source exactly.

Keep the remaining 8 rows pending because they still carry near-match,
language-shape, or lexical-risk review signals:

| Target | Reason |
|---|---|
| `HN4-018 script:2` | STT heard `機械` as `機会`; direct listening or regeneration judgment required |
| `HN4-019 script:0` | STT normalized `三時` as `3時`; low risk but still direct-listen before PASS |
| `HN4-019 question:4` | 60-second retry produced a Japanese transcript for a Korean prompt; verify learner-facing language |
| `HN4-020 script:0` | STT omitted final `です`; direct listening required |
| `HN4-020 script:2` | 60-second retry heard `先に` as `1000`; direct listening or regeneration required |
| `HN4-021 script:0` | STT heard `席` as `昔`; direct listening or regeneration required |
| `HN4-021 script:2` | STT inserted `二時`; direct listening or regeneration required |
| `HN4-021 script:3` | STT omitted final `です`; direct listening required |

## Apply Command

```bash
cd apps/api
uv run python scripts/apply_n4_audio_qa_verdicts.py \
  --csv-input ../../docs/operations/plans/n4-wave3-draft-delegated-pending-clearance-2026-05-27.csv \
  --write
uv run python scripts/apply_n4_audio_qa_verdicts.py \
  --csv-input ../../docs/operations/plans/n4-wave3-draft-ai-assisted-verdicts-2026-05-27.csv \
  --write
```

## Expected Verdict State

| Verdict | Count |
|---|---:|
| PASS | 37 |
| FLAG | 0 |
| PENDING | 8 |
| FAIL | 0 |

## Next Gate

Regenerate or directly adjudicate the 8 remaining rows before moving
`N4-CH05` from `DRAFT` toward `PILOT`.
