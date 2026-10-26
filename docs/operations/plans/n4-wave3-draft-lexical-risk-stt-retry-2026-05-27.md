# N4 TTS Audio QA Machine Report

> Status: REVIEW
> Scope: generated lesson script-line and question-prompt TTS targets
> Boundary: machine/STT evidence only; human audio verdicts remain required

## Command

```bash
uv run python scripts/audit_n4_pilot_tts_audio_quality.py --level N4 --include-unpublished --target-key 'HN4-017 script:1' --target-key 'HN4-018 script:0' --target-key 'HN4-019 script:3' --transcribe --transcription-timeout-seconds 30.0 --markdown-output ../../docs/operations/plans/n4-wave3-draft-lexical-risk-stt-retry-2026-05-27.md
```

## Summary

| Metric | Result |
|---|---:|
| Total targets | 3 |
| Machine pass | 3 |
| Blocked targets | 0 |
| Warning count | 3 |
| Transcribed targets | 3 |
| STT exact matches | 0 |
| STT mismatches | 3 |
| STT errors | 0 |
| Duration min | 1.62s |
| Duration max | 4.545s |
| Duration average | 2.952s |
| Total audio duration | 8.856s |

## Provider Models

- `elevenlabs/eleven_multilingual_v2`: 3

## Blockers

- None

## Review-Priority Warnings

- HN4-017 script:1: TRANSCRIPTION_TEXT_MISMATCH:忙しい
- HN4-018 script:0: TRANSCRIPTION_TEXT_MISMATCH:この議会は壊れそう
- HN4-019 script:3: TRANSCRIPTION_TEXT_MISMATCH:てくてはさおむそうですから早く行きましょう

## STT Mismatches

| Target | Source text | STT transcript | Strict blocker mode | Audio |
|---|---|---|---|---|
| HN4-017 script:1 | 忙しいですね。 | 忙しい | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/script-line-1.mp3 |
| HN4-018 script:0 | この機械は壊れそうです。 | この議会は壊れそう | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/script-line-0.mp3 |
| HN4-019 script:3 | 受付は混むそうですから、早く行きましょう。 | てくてはさおむそうですから早く行きましょう | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/script-line-3.mp3 |

## Decision

REVIEW: inspect STT mismatches before recording final audio verdicts.
