# N4 TTS Audio QA Machine Report

> Status: REVIEW
> Scope: generated lesson script-line and question-prompt TTS targets
> Boundary: machine/STT evidence only; human audio verdicts remain required

## Command

```bash
uv run python scripts/audit_n4_pilot_tts_audio_quality.py --level N4 --include-unpublished --lesson-no 27 --lesson-no 28 --lesson-no 29 --lesson-no 30 --lesson-no 31 --fail-on-blocker --markdown-output ../../docs/operations/plans/n4-ch07-machine-audio-qa-2026-06-05.md
```

## Summary

| Metric | Result |
|---|---:|
| Total targets | 45 |
| Machine pass | 45 |
| Blocked targets | 0 |
| Warning count | 3 |
| Transcribed targets | 0 |
| STT exact matches | 0 |
| STT mismatches | 0 |
| STT errors | 0 |
| Duration min | 1.437s |
| Duration max | 7.184s |
| Duration average | 3.743s |
| Total audio duration | 168.442s |

## Provider Models

- `elevenlabs/eleven_multilingual_v2`: 45

## Blockers

- None

## Review-Priority Warnings

- HN4-027 question:4: HIGH_SILENCE_RATIO:0.3837
- HN4-028 question:4: HIGH_SILENCE_RATIO:0.3966
- HN4-029 question:3: HIGH_SILENCE_RATIO:0.4243

## STT Mismatches

- None

## Decision

REVIEW: inspect non-blocking warnings before recording final audio verdicts.
