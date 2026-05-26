# N5 Human Audio QA Packets

> Generated: 2026-05-26
> Status: REVIEW PACKETS READY - verdicts pending
> Boundary: review packet preparation and machine audio preflight. This does
> not apply `PASS`, `FLAG`, `FAIL`, or native-speaker approval.

ASSUMPTION: N5 audio QA is tracked chapter by chapter, and broad rollout stays
blocked while any packet row remains `PENDING`, `FLAG`, `FAIL`, or invalid.

ASSUMPTION: Machine audio preflight warnings are review-priority signals, not
automatic audio failure verdicts.

## Summary

| Gate | Result |
|---|---:|
| Packet files | 9 |
| Review targets | 448 |
| Script-line targets | 198 |
| Question-prompt targets | 250 |
| Current PASS verdicts | 0 |
| Current PENDING verdicts | 448 |
| Current FLAG verdicts | 0 |
| Current FAIL verdicts | 0 |
| Invalid verdicts | 0 |
| Machine audio pass | 448/448 |
| Machine blockers | 0 |
| Machine review-priority warnings | 36 |

## Packet Files

| Packet | Targets | Status |
|---|---:|---|
| `docs/operations/plans/n5-human-audio-qa-ch01-2026-05-26.md` | 45 | PENDING |
| `docs/operations/plans/n5-human-audio-qa-ch02-2026-05-26.md` | 45 | PENDING |
| `docs/operations/plans/n5-human-audio-qa-ch03-2026-05-26.md` | 45 | PENDING |
| `docs/operations/plans/n5-human-audio-qa-ch04-2026-05-26.md` | 45 | PENDING |
| `docs/operations/plans/n5-human-audio-qa-ch05-2026-05-26.md` | 45 | PENDING |
| `docs/operations/plans/n5-human-audio-qa-ch06-2026-05-26.md` | 45 | PENDING |
| `docs/operations/plans/n5-human-audio-qa-ch07-2026-05-26.md` | 45 | PENDING |
| `docs/operations/plans/n5-human-audio-qa-ch08-2026-05-26.md` | 81 | PENDING |
| `docs/operations/plans/n5-human-audio-qa-ch09-2026-05-26.md` | 52 | PENDING |

## Machine Preflight

Evidence: `docs/operations/plans/n5-tts-audio-quality-preflight-2026-05-26.md`

```bash
cd apps/api
uv run python scripts/audit_n4_pilot_tts_audio_quality.py \
  --level N5 \
  --markdown-output ../../docs/operations/plans/n5-tts-audio-quality-preflight-2026-05-26.md \
  --timeout-seconds 15
```

Result:

```text
targets 448/448 pass
blocked 0
warnings 36
provider_model_counts {'elevenlabs/eleven_multilingual_v2': 448}
durations min=1.149 max=11.416 avg=4.127 total=1849.06
transcription transcribed=0 exact_match=0 mismatch=0 errors=0
```

## Verdict Report

```bash
cd apps/api
uv run python scripts/report_n4_audio_qa_verdicts.py \
  --level N5 \
  --json
```

Result:

```text
total_targets: 448
pass_count: 0
pending_count: 448
flag_count: 0
fail_count: 0
waived_count: 0
invalid_count: 0
blockers:
- PENDING_VERDICTS: 448 target(s) still need human verdicts
```

## Review Priority

Prioritize direct listening for the 36 `HIGH_SILENCE_RATIO` warning rows in the
machine preflight report. Most warnings are question prompts with Korean or
cloze context, so treat them as review lanes rather than automatic failures.

Next gate:

1. Run delegated STT-assist on a smaller high-risk slice, not all 448 targets at
   once.
2. Direct-listen the 36 warning targets.
3. Apply explicit verdicts to packets only after review evidence exists.
4. Re-run the verdict report with `--fail-on-blocker`.
