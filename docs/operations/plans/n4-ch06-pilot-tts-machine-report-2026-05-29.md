# N4 TTS Audio QA Machine Report

> Status: REVIEW
> Scope: generated lesson script-line and question-prompt TTS targets
> Boundary: machine/STT evidence only; human audio verdicts remain required

## Command

```bash
uv run python scripts/audit_n4_pilot_tts_audio_quality.py --level N4 --lesson-no 22 --lesson-no 23 --lesson-no 24 --lesson-no 25 --lesson-no 26 --fail-on-blocker --markdown-output ../../docs/operations/plans/n4-ch06-pilot-tts-machine-report-2026-05-29.md
```

## Summary

| Metric | Result |
|---|---:|
| Total targets | 45 |
| Machine pass | 45 |
| Blocked targets | 0 |
| Warning count | 2 |
| Transcribed targets | 0 |
| STT exact matches | 0 |
| STT mismatches | 0 |
| STT errors | 0 |
| Duration min | 1.437s |
| Duration max | 7.34s |
| Duration average | 4.094s |
| Total audio duration | 184.243s |

## Provider Models

- `elevenlabs/eleven_multilingual_v2`: 45

## Blockers

- None

## Review-Priority Warnings

- HN4-022 question:3: HIGH_SILENCE_RATIO:0.3669
- HN4-024 question:3: HIGH_SILENCE_RATIO:0.3828

## STT Mismatches

- None

## Decision

REVIEW: inspect non-blocking warnings before recording final audio verdicts.
