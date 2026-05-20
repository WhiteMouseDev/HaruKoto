# N4 TTS Audio QA Machine Report

> Status: REVIEW
> Scope: generated lesson script-line and question-prompt TTS targets
> Boundary: machine/STT evidence only; human audio verdicts remain required

## Command

```bash
uv run python scripts/audit_n4_pilot_tts_audio_quality.py --level N4 --include-unpublished --lesson-no 12 --lesson-no 13 --lesson-no 14 --lesson-no 15 --lesson-no 16 --fail-on-blocker --markdown-output ../../docs/operations/plans/n4-wave2-draft-tts-machine-report-2026-05-20.md
```

## Summary

| Metric | Result |
|---|---:|
| Total targets | 45 |
| Machine pass | 45 |
| Blocked targets | 0 |
| Warning count | 1 |
| Transcribed targets | 0 |
| STT exact matches | 0 |
| STT mismatches | 0 |
| STT errors | 0 |
| Duration min | 1.489s |
| Duration max | 6.4s |
| Duration average | 3.439s |
| Total audio duration | 154.75s |

## Provider Models

- `elevenlabs/eleven_multilingual_v2`: 45

## Blockers

- None

## Review-Priority Warnings

- HN4-015 question:4: HIGH_SILENCE_RATIO:0.4203

## STT Mismatches

- None

## Decision

REVIEW: inspect non-blocking warnings before recording final audio verdicts.
