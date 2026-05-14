# N4 TTS Audio QA Machine Report

> Status: REVIEW
> Scope: generated lesson script-line and question-prompt TTS targets
> Boundary: machine/STT evidence only; human audio verdicts remain required

## Command

```bash
uv run python scripts/audit_n4_pilot_tts_audio_quality.py --level N4 --fail-on-blocker --markdown-output ../../docs/operations/plans/n4-pilot-tts-machine-report-2026-05-14.md
```

## Summary

| Metric | Result |
|---|---:|
| Total targets | 99 |
| Machine pass | 99 |
| Blocked targets | 0 |
| Warning count | 11 |
| Transcribed targets | 0 |
| STT exact matches | 0 |
| STT mismatches | 0 |
| STT errors | 0 |
| Duration min | 1.437s |
| Duration max | 8.673s |
| Duration average | 3.819s |
| Total audio duration | 378.044s |

## Provider Models

- `elevenlabs/eleven_multilingual_v2`: 99

## Blockers

- None

## Review-Priority Warnings

- HN4-001 question:3: HIGH_SILENCE_RATIO:0.3863
- HN4-002 question:4: HIGH_SILENCE_RATIO:0.3876
- HN4-003 question:3: HIGH_SILENCE_RATIO:0.3646
- HN4-003 question:4: HIGH_SILENCE_RATIO:0.4078
- HN4-004 question:4: HIGH_SILENCE_RATIO:0.3813
- HN4-005 question:4: HIGH_SILENCE_RATIO:0.3968
- HN4-006 question:4: HIGH_SILENCE_RATIO:0.3523
- HN4-008 question:3: HIGH_SILENCE_RATIO:0.4026
- HN4-009 question:4: HIGH_SILENCE_RATIO:0.4041
- HN4-010 question:4: HIGH_SILENCE_RATIO:0.3915
- HN4-011 question:3: HIGH_SILENCE_RATIO:0.359

## STT Mismatches

- None

## Decision

REVIEW: inspect non-blocking warnings before recording final audio verdicts.
