# N4 TTS Audio QA Machine Report

> Status: REVIEW
> Scope: generated lesson script-line and question-prompt TTS targets
> Boundary: machine/STT evidence only; human audio verdicts remain required

## Command

```bash
uv run python scripts/audit_n4_pilot_tts_audio_quality.py --level N4 --target-key 'HN4-022 script:0' --target-key 'HN4-022 script:1' --target-key 'HN4-022 script:3' --target-key 'HN4-023 script:1' --target-key 'HN4-024 script:0' --target-key 'HN4-024 script:3' --target-key 'HN4-025 script:0' --target-key 'HN4-025 script:1' --target-key 'HN4-025 script:3' --target-key 'HN4-026 script:0' --target-key 'HN4-026 script:1' --target-key 'HN4-026 script:3' --transcribe --transcription-timeout-seconds 60.0 --markdown-output ../../docs/operations/plans/n4-ch06-script-stt-retry-2026-06-01.md
```

## Summary

| Metric | Result |
|---|---:|
| Total targets | 12 |
| Machine pass | 12 |
| Blocked targets | 0 |
| Warning count | 10 |
| Transcribed targets | 12 |
| STT exact matches | 2 |
| STT mismatches | 10 |
| STT errors | 0 |
| Duration min | 3.37s |
| Duration max | 6.296s |
| Duration average | 4.637s |
| Total audio duration | 55.64s |

## Provider Models

- `elevenlabs/eleven_multilingual_v2`: 12

## Blockers

- None

## Review-Priority Warnings

- HN4-022 script:0: TRANSCRIPTION_TEXT_MISMATCH:後輩に地図を絵描いてあげました。
- HN4-022 script:1: TRANSCRIPTION_TEXT_MISMATCH:親切ですね。特定の場所も教えてあげましたか？
- HN4-022 script:3: TRANSCRIPTION_TEXT_MISMATCH:手伝って開ける時は相手の気持ちも大事ですね。
- HN4-023 script:1: TRANSCRIPTION_TEXT_MISMATCH:特ねの場所も説明してくれましたか？
- HN4-024 script:0: TRANSCRIPTION_TEXT_MISMATCH:とくねの人に住所を確認してもらいました。
- HN4-024 script:3: TRANSCRIPTION_TEXT_MISMATCH:必要なことは、テフの人にもう一度確認してもらいましょう。
- HN4-025 script:1: TRANSCRIPTION_TEXT_MISMATCH:それは残念ですね。手札に連絡しましたか？
- HN4-026 script:0: TRANSCRIPTION_TEXT_MISMATCH:いいの前で自転車を盗まれました。
- HN4-026 script:1: TRANSCRIPTION_TEXT_MISMATCH:落とし物ではなく盗まれてたんですか
- HN4-026 script:3: TRANSCRIPTION_TEXT_MISMATCH:近くのカメラの影響がこれから確認されます。

## STT Mismatches

| Target | Source text | STT transcript | Strict blocker mode | Audio |
|---|---|---|---|---|
| HN4-022 script:0 | 後輩に地図を描いてあげました。 | 後輩に地図を絵描いてあげました。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b9250446-d707-46d4-a461-66e273b8534e/script-line-0.mp3 |
| HN4-022 script:1 | 親切ですね。受付の場所も教えてあげましたか。 | 親切ですね。特定の場所も教えてあげましたか？ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b9250446-d707-46d4-a461-66e273b8534e/script-line-1.mp3 |
| HN4-022 script:3 | 手伝ってあげる時は、相手の気持ちも大事ですね。 | 手伝って開ける時は相手の気持ちも大事ですね。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b9250446-d707-46d4-a461-66e273b8534e/script-line-3.mp3 |
| HN4-023 script:1 | 受付の場所も説明してくれましたか。 | 特ねの場所も説明してくれましたか？ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/45466832-238e-429a-af10-e9811dc360d3/script-line-1.mp3 |
| HN4-024 script:0 | 受付の人に住所を確認してもらいました。 | とくねの人に住所を確認してもらいました。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/35093fd4-0511-4bdc-bfe4-e4c25c269654/script-line-0.mp3 |
| HN4-024 script:3 | 必要なことは受付の人にもう一度確認してもらいましょう。 | 必要なことは、テフの人にもう一度確認してもらいましょう。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/35093fd4-0511-4bdc-bfe4-e4c25c269654/script-line-3.mp3 |
| HN4-025 script:1 | それは残念ですね。受付に連絡しましたか。 | それは残念ですね。手札に連絡しましたか？ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b8b159a7-b8d4-45b3-a8d7-a9d07837b991/script-line-1.mp3 |
| HN4-026 script:0 | 駅の前で自転車を盗まれました。 | いいの前で自転車を盗まれました。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/ef3004f3-bca8-4621-b7aa-520cdde4e823/script-line-0.mp3 |
| HN4-026 script:1 | 落とし物ではなく、盗まれたんですね。 | 落とし物ではなく盗まれてたんですか | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/ef3004f3-bca8-4621-b7aa-520cdde4e823/script-line-1.mp3 |
| HN4-026 script:3 | 近くのカメラの映像がこれから確認されます。 | 近くのカメラの影響がこれから確認されます。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/ef3004f3-bca8-4621-b7aa-520cdde4e823/script-line-3.mp3 |

## Decision

REVIEW: inspect STT mismatches before recording final audio verdicts.
