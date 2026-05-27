# N4 TTS Audio QA Machine Report

> Status: BLOCK
> Scope: generated lesson script-line and question-prompt TTS targets
> Boundary: machine/STT evidence only; human audio verdicts remain required

## Command

```bash
uv run python scripts/audit_n4_pilot_tts_audio_quality.py --level N4 --include-unpublished --target-key 'HN4-019 question:4' --target-key 'HN4-020 script:1' --target-key 'HN4-020 script:2' --target-key 'HN4-020 script:3' --target-key 'HN4-020 question:1' --target-key 'HN4-020 question:2' --target-key 'HN4-020 question:3' --target-key 'HN4-020 question:4' --target-key 'HN4-020 question:5' --target-key 'HN4-021 script:0' --target-key 'HN4-021 script:1' --target-key 'HN4-021 script:2' --target-key 'HN4-021 script:3' --target-key 'HN4-021 question:1' --target-key 'HN4-021 question:2' --target-key 'HN4-021 question:3' --target-key 'HN4-021 question:4' --target-key 'HN4-021 question:5' --transcribe --transcription-timeout-seconds 30.0 --markdown-output ../../docs/operations/plans/n4-wave3-draft-tts-stt-timeout-retry-2026-05-27.md
```

## Summary

| Metric | Result |
|---|---:|
| Total targets | 18 |
| Machine pass | 17 |
| Blocked targets | 1 |
| Warning count | 13 |
| Transcribed targets | 17 |
| STT exact matches | 4 |
| STT mismatches | 13 |
| STT errors | 1 |
| Duration min | 1.437s |
| Duration max | 5.016s |
| Duration average | 3.035s |
| Total audio duration | 54.622s |

## Provider Models

- `elevenlabs/eleven_multilingual_v2`: 18

## Blockers

- HN4-019 question:4: TRANSCRIPTION_FAILED:TimeoutError:

## Review-Priority Warnings

- HN4-020 question:1: TRANSCRIPTION_TEXT_MISMATCH:原則、
- HN4-020 question:2: TRANSCRIPTION_TEXT_MISMATCH:モロヘイヤ
- HN4-020 question:3: TRANSCRIPTION_TEXT_MISMATCH:約束は守るならです
- HN4-020 question:4: TRANSCRIPTION_TEXT_MISMATCH:規則はみんなで交わらぬものですな
- HN4-020 question:5: TRANSCRIPTION_TEXT_MISMATCH:約束を守る法です。を配列하세요。
- HN4-021 script:0: TRANSCRIPTION_TEXT_MISMATCH:予約したので昔はあるはずです。
- HN4-021 script:2: TRANSCRIPTION_TEXT_MISMATCH:会議の予定は午後二時に決まるはずです。
- HN4-021 script:3: TRANSCRIPTION_TEXT_MISMATCH:準備はできそうね
- HN4-021 question:1: TRANSCRIPTION_TEXT_MISMATCH:予約恵子
- HN4-021 question:2: TRANSCRIPTION_TEXT_MISMATCH:とくえ とくえ
- HN4-021 question:3: TRANSCRIPTION_TEXT_MISMATCH:かしわるーさに
- HN4-021 question:4: TRANSCRIPTION_TEXT_MISMATCH:資料も今日は初です。
- HN4-021 question:5: TRANSCRIPTION_TEXT_MISMATCH:資料は今日到着するでしょう。を配列してください。

## STT Mismatches

| Target | Source text | STT transcript | Strict blocker mode | Audio |
|---|---|---|---|---|
| HN4-020 question:1 | 約束의 뜻은? | 原則、 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/question-1.mp3 |
| HN4-020 question:2 | 守る의 뜻은? | モロヘイヤ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/question-2.mp3 |
| HN4-020 question:3 | 約束は守る___です。 | 約束は守るならです | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/question-3.mp3 |
| HN4-020 question:4 | 規則はみんなで___ものですね。 | 規則はみんなで交わらぬものですな | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/question-4.mp3 |
| HN4-020 question:5 | '약속은 지키는 법입니다'를 배열하세요. | 約束を守る法です。を配列하세요。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/question-5.mp3 |
| HN4-021 script:0 | 予約したので、席はあるはずです。 | 予約したので昔はあるはずです。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/script-line-0.mp3 |
| HN4-021 script:2 | 会議の予定は午後に決まるはずです。 | 会議の予定は午後二時に決まるはずです。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/script-line-2.mp3 |
| HN4-021 script:3 | 準備はできそうですね。 | 準備はできそうね | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/script-line-3.mp3 |
| HN4-021 question:1 | 予約의 뜻은? | 予約恵子 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/question-1.mp3 |
| HN4-021 question:2 | 届く의 뜻은? | とくえ とくえ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/question-2.mp3 |
| HN4-021 question:3 | 席はある___です。 | かしわるーさに | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/question-3.mp3 |
| HN4-021 question:4 | 資料も今日___はずです。 | 資料も今日は初です。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/question-4.mp3 |
| HN4-021 question:5 | '자료는 오늘 도착할 것입니다'를 배열하세요. | 資料は今日到着するでしょう。を配列してください。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/question-5.mp3 |

## Decision

BLOCK: resolve machine/STT blockers before considering broader rollout.
