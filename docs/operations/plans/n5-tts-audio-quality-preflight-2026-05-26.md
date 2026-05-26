# N5 TTS Audio QA Machine Report

> Status: REVIEW
> Scope: generated lesson script-line and question-prompt TTS targets
> Boundary: machine/STT evidence only; human audio verdicts remain required

## Command

```bash
uv run python scripts/audit_n4_pilot_tts_audio_quality.py --level N5 --markdown-output ../../docs/operations/plans/n5-tts-audio-quality-preflight-2026-05-26.md
```

## Summary

| Metric | Result |
|---|---:|
| Total targets | 448 |
| Machine pass | 448 |
| Blocked targets | 0 |
| Warning count | 36 |
| Transcribed targets | 0 |
| STT exact matches | 0 |
| STT mismatches | 0 |
| STT errors | 0 |
| Duration min | 1.149s |
| Duration max | 11.416s |
| Duration average | 4.127s |
| Total audio duration | 1849.06s |

## Provider Models

- `elevenlabs/eleven_multilingual_v2`: 448

## Blockers

- None

## Review-Priority Warnings

- HN5-001 question:4: HIGH_SILENCE_RATIO:0.442
- HN5-003 question:3: HIGH_SILENCE_RATIO:0.3724
- HN5-005 question:3: HIGH_SILENCE_RATIO:0.4487
- HN5-005 question:4: HIGH_SILENCE_RATIO:0.4416
- HN5-008 question:3: HIGH_SILENCE_RATIO:0.4391
- HN5-011 question:4: HIGH_SILENCE_RATIO:0.3864
- HN5-014 question:4: HIGH_SILENCE_RATIO:0.4013
- HN5-015 question:3: HIGH_SILENCE_RATIO:0.5219
- HN5-015 question:4: HIGH_SILENCE_RATIO:0.3726
- HN5-016 question:4: HIGH_SILENCE_RATIO:0.4416
- HN5-017 question:4: HIGH_SILENCE_RATIO:0.4666
- HN5-018 question:3: HIGH_SILENCE_RATIO:0.5121
- HN5-018 question:4: HIGH_SILENCE_RATIO:0.5132
- HN5-019 question:3: HIGH_SILENCE_RATIO:0.5279
- HN5-020 question:3: HIGH_SILENCE_RATIO:0.4065
- HN5-020 question:4: HIGH_SILENCE_RATIO:0.4446
- HN5-021 question:4: HIGH_SILENCE_RATIO:0.4188
- HN5-022 question:3: HIGH_SILENCE_RATIO:0.5102
- HN5-022 question:4: HIGH_SILENCE_RATIO:0.4055
- HN5-024 question:3: HIGH_SILENCE_RATIO:0.4403
- HN5-024 question:4: HIGH_SILENCE_RATIO:0.3928
- HN5-028 question:4: HIGH_SILENCE_RATIO:0.383
- HN5-030 question:3: HIGH_SILENCE_RATIO:0.447
- HN5-030 question:4: HIGH_SILENCE_RATIO:0.5119
- HN5-031 question:4: HIGH_SILENCE_RATIO:0.5364
- HN5-032 question:3: HIGH_SILENCE_RATIO:0.3736
- HN5-034 question:3: HIGH_SILENCE_RATIO:0.3718
- HN5-034 question:4: HIGH_SILENCE_RATIO:0.4672
- HN5-035 question:3: HIGH_SILENCE_RATIO:0.3807
- HN5-036 question:3: HIGH_SILENCE_RATIO:0.3674
- HN5-038 script:1: HIGH_SILENCE_RATIO:0.3561
- HN5-040 question:3: HIGH_SILENCE_RATIO:0.4955
- HN5-041 script:3: HIGH_SILENCE_RATIO:0.4175
- HN5-041 question:3: HIGH_SILENCE_RATIO:0.4414
- HN5-043 question:4: HIGH_SILENCE_RATIO:0.4298
- HN5-048 question:4: HIGH_SILENCE_RATIO:0.3965

## STT Mismatches

- None

## Decision

REVIEW: inspect non-blocking warnings before recording final audio verdicts.
