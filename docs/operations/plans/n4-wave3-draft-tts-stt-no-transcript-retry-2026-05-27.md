# N4 TTS Audio QA Machine Report

> Status: REVIEW
> Scope: generated lesson script-line and question-prompt TTS targets
> Boundary: machine/STT evidence only; human audio verdicts remain required

## Command

```bash
uv run python scripts/audit_n4_pilot_tts_audio_quality.py --level N4 --include-unpublished --target-key 'HN4-019 question:4' --target-key 'HN4-020 script:1' --target-key 'HN4-020 script:2' --target-key 'HN4-020 script:3' --target-key 'HN4-021 script:1' --timeout-seconds 20.0 --transcribe --transcription-timeout-seconds 60.0 --markdown-output ../../docs/operations/plans/n4-wave3-draft-tts-stt-no-transcript-retry-2026-05-27.md
```

## Summary

| Metric | Result |
|---|---:|
| Total targets | 5 |
| Machine pass | 5 |
| Blocked targets | 0 |
| Warning count | 2 |
| Transcribed targets | 5 |
| STT exact matches | 3 |
| STT mismatches | 2 |
| STT errors | 0 |
| Duration min | 2.821s |
| Duration max | 4.31s |
| Duration average | 3.526s |
| Total audio duration | 17.632s |

## Provider Models

- `elevenlabs/eleven_multilingual_v2`: 5

## Blockers

- None

## Review-Priority Warnings

- HN4-019 question:4: TRANSCRIPTION_TEXT_MISMATCH:聞いた情報を伝えるとき、適切な表現は
- HN4-020 script:2: TRANSCRIPTION_TEXT_MISMATCH:挨拶は普通1000にするものです。

## STT Mismatches

| Target | Source text | STT transcript | Strict blocker mode | Audio |
|---|---|---|---|---|
| HN4-019 question:4 | 들은 정보를 전달할 때 알맞은 표현은? | 聞いた情報を伝えるとき、適切な表現は | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/question-4.mp3 |
| HN4-020 script:2 | 挨拶は普通、先にするものです。 | 挨拶は普通1000にするものです。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/script-line-2.mp3 |

## Decision

REVIEW: inspect STT mismatches before recording final audio verdicts.
