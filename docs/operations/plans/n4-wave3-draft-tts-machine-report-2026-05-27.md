# N4 TTS Audio QA Machine Report

> Status: PASS
> Scope: generated lesson script-line and question-prompt TTS targets
> Boundary: machine/STT evidence only; human audio verdicts remain required

## Command

```bash
uv run python scripts/audit_n4_pilot_tts_audio_quality.py --level N4 --include-unpublished --lesson-no 17 --lesson-no 18 --lesson-no 19 --lesson-no 20 --lesson-no 21 --fail-on-blocker --markdown-output ../../docs/operations/plans/n4-wave3-draft-tts-machine-report-2026-05-27.md
```

## Summary

| Metric | Result |
|---|---:|
| Total targets | 45 |
| Machine pass | 45 |
| Blocked targets | 0 |
| Warning count | 0 |
| Transcribed targets | 0 |
| STT exact matches | 0 |
| STT mismatches | 0 |
| STT errors | 0 |
| Duration min | 1.437s |
| Duration max | 7.288s |
| Duration average | 3.404s |
| Total audio duration | 153.184s |

## Provider Models

- `elevenlabs/eleven_multilingual_v2`: 45

## Blockers

- None

## Review-Priority Warnings

- None

## STT Mismatches

- None

## Decision

PASS: no machine blockers or review-priority warnings were found.
