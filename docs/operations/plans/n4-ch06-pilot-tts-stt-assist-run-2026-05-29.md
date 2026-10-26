# N4 TTS Audio QA Machine Report

> Status: REVIEW
> Scope: generated lesson script-line and question-prompt TTS targets
> Boundary: machine/STT evidence only; human audio verdicts remain required

## Command

```bash
uv run python scripts/audit_n4_pilot_tts_audio_quality.py --level N4 --lesson-no 22 --lesson-no 23 --lesson-no 24 --lesson-no 25 --lesson-no 26 --transcribe --transcription-timeout-seconds 20.0 --markdown-output ../../docs/operations/plans/n4-ch06-pilot-tts-stt-assist-run-2026-05-29.md
```

## Summary

| Metric | Result |
|---|---:|
| Total targets | 45 |
| Machine pass | 45 |
| Blocked targets | 0 |
| Warning count | 39 |
| Transcribed targets | 45 |
| STT exact matches | 8 |
| STT mismatches | 37 |
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

- HN4-022 script:0: TRANSCRIPTION_TEXT_MISMATCH:後輩に実を絵描いてあげました。
- HN4-022 script:1: TRANSCRIPTION_TEXT_MISMATCH:親切ですね。特定の場所も教えてあげましたか？
- HN4-022 script:3: TRANSCRIPTION_TEXT_MISMATCH:手伝って開ける時は相手の気持ちも大事ですね。
- HN4-022 question:1: TRANSCRIPTION_TEXT_MISMATCH:コバヤシ
- HN4-022 question:2: TRANSCRIPTION_TEXT_MISMATCH:手伝いウィトスン
- HN4-022 question:3: HIGH_SILENCE_RATIO:0.3669, TRANSCRIPTION_TEXT_MISMATCH:後輩に質を書いていました
- HN4-022 question:4: TRANSCRIPTION_TEXT_MISMATCH:ムンメクサン ウィチルル アルリョジュダ エ マンヌン ピョヒョヌン
- HN4-022 question:5: TRANSCRIPTION_TEXT_MISMATCH:後輩に地図を書いてくださいます。を配列してください。
- HN4-023 script:1: TRANSCRIPTION_TEXT_MISMATCH:とくねの場所も説明してくれましたか？
- HN4-023 question:1: TRANSCRIPTION_TEXT_MISMATCH:先輩へ
- HN4-023 question:2: TRANSCRIPTION_TEXT_MISMATCH:こいちょん
- HN4-023 question:3: TRANSCRIPTION_TEXT_MISMATCH:先輩が会場まで案内してました
- HN4-023 question:4: TRANSCRIPTION_TEXT_MISMATCH:灯台の場所もあららにくれましたか
- HN4-023 question:5: TRANSCRIPTION_TEXT_MISMATCH:ソンベガ ヘンサジャンカジ アンネヘ ジュオッスムニダ ルル ペヨルハセヨ
- HN4-024 script:0: TRANSCRIPTION_TEXT_MISMATCH:特許の人に住所を確認してもらいました。
- HN4-024 script:3: TRANSCRIPTION_TEXT_MISMATCH:必要なことはテフの人にもう一度確認してもらいましょう。
- HN4-024 question:1: TRANSCRIPTION_TEXT_MISMATCH:豆腐屋さん
- HN4-024 question:2: TRANSCRIPTION_TEXT_MISMATCH:ジュソイエ
- HN4-024 question:3: HIGH_SILENCE_RATIO:0.3828, TRANSCRIPTION_TEXT_MISMATCH:特地の人に住所確認してました
- HN4-024 question:4: TRANSCRIPTION_TEXT_MISMATCH:予約の時間もあからん もらいましたか
- HN4-024 question:5: TRANSCRIPTION_TEXT_MISMATCH:受付の職員に住所を確認してほしいと頼みました。を配列してください。
- HN4-025 script:0: TRANSCRIPTION_TEXT_MISMATCH:予約したのに西がありませんでした。
- HN4-025 script:1: TRANSCRIPTION_TEXT_MISMATCH:それは残念ですね。デフテに連絡しましたか？
- HN4-025 script:3: TRANSCRIPTION_TEXT_MISMATCH:期待と違う結果を話す時に何を使いますか？
- HN4-025 question:1: TRANSCRIPTION_TEXT_MISMATCH:CZSNN
- HN4-025 question:2: TRANSCRIPTION_TEXT_MISMATCH:残念ない
- HN4-025 question:3: TRANSCRIPTION_TEXT_MISMATCH:予約したリーダー日記がありませんでした
- HN4-025 question:4: TRANSCRIPTION_TEXT_MISMATCH:時間に間に合わないのに確認に時間がかかりました。
- HN4-025 question:5: TRANSCRIPTION_TEXT_MISMATCH:イェヤッ ケッヌンデド チャリガ オプソッスムニダを ベヨルハセヨ
- HN4-026 script:0: TRANSCRIPTION_TEXT_MISMATCH:家の前で自転車を盗まれました。
- HN4-026 script:1: TRANSCRIPTION_TEXT_MISMATCH:落とし物ではなくお盗まれなんですね。
- HN4-026 script:3: TRANSCRIPTION_TEXT_MISMATCH:近くのカメラの影響がこれから確認されます。
- HN4-026 question:1: TRANSCRIPTION_TEXT_MISMATCH:自転車へディスイン
- HN4-026 question:2: TRANSCRIPTION_TEXT_MISMATCH:タオムエタンシン
- HN4-026 question:3: TRANSCRIPTION_TEXT_MISMATCH:自転車をアニメました。
- HN4-026 question:4: TRANSCRIPTION_TEXT_MISMATCH:近くの人に声をかけーてすぐ警察に来ました。
- HN4-026 question:5: TRANSCRIPTION_TEXT_MISMATCH:チャジョンゴル ドナンタンヘッスムニダ を ベヨルハセヨ

## STT Mismatches

| Target | Source text | STT transcript | Strict blocker mode | Audio |
|---|---|---|---|---|
| HN4-022 script:0 | 後輩に地図を描いてあげました。 | 後輩に実を絵描いてあげました。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b9250446-d707-46d4-a461-66e273b8534e/script-line-0.mp3 |
| HN4-022 script:1 | 親切ですね。受付の場所も教えてあげましたか。 | 親切ですね。特定の場所も教えてあげましたか？ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b9250446-d707-46d4-a461-66e273b8534e/script-line-1.mp3 |
| HN4-022 script:3 | 手伝ってあげる時は、相手の気持ちも大事ですね。 | 手伝って開ける時は相手の気持ちも大事ですね。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b9250446-d707-46d4-a461-66e273b8534e/script-line-3.mp3 |
| HN4-022 question:1 | 後輩의 뜻은? | コバヤシ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b9250446-d707-46d4-a461-66e273b8534e/question-1.mp3 |
| HN4-022 question:2 | 手伝う의 뜻은? | 手伝いウィトスン | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b9250446-d707-46d4-a461-66e273b8534e/question-2.mp3 |
| HN4-022 question:3 | 後輩に地図を描いて___ました。 | 後輩に質を書いていました | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b9250446-d707-46d4-a461-66e273b8534e/question-3.mp3 |
| HN4-022 question:4 | 문맥상 "위치를 알려 주다"에 맞는 표현은? | ムンメクサン ウィチルル アルリョジュダ エ マンヌン ピョヒョヌン | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b9250446-d707-46d4-a461-66e273b8534e/question-4.mp3 |
| HN4-022 question:5 | '후배에게 지도를 그려 주었습니다'를 배열하세요. | 後輩に地図を書いてくださいます。を配列してください。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b9250446-d707-46d4-a461-66e273b8534e/question-5.mp3 |
| HN4-023 script:1 | 受付の場所も説明してくれましたか。 | とくねの場所も説明してくれましたか？ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/45466832-238e-429a-af10-e9811dc360d3/script-line-1.mp3 |
| HN4-023 question:1 | 先輩의 뜻은? | 先輩へ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/45466832-238e-429a-af10-e9811dc360d3/question-1.mp3 |
| HN4-023 question:2 | 会場의 뜻은? | こいちょん | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/45466832-238e-429a-af10-e9811dc360d3/question-2.mp3 |
| HN4-023 question:3 | 先輩が会場まで案内して___ました。 | 先輩が会場まで案内してました | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/45466832-238e-429a-af10-e9811dc360d3/question-3.mp3 |
| HN4-023 question:4 | 受付の場所も___くれましたか。 | 灯台の場所もあららにくれましたか | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/45466832-238e-429a-af10-e9811dc360d3/question-4.mp3 |
| HN4-023 question:5 | '선배가 행사장까지 안내해 주었습니다'를 배열하세요. | ソンベガ ヘンサジャンカジ アンネヘ ジュオッスムニダ ルル ペヨルハセヨ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/45466832-238e-429a-af10-e9811dc360d3/question-5.mp3 |
| HN4-024 script:0 | 受付の人に住所を確認してもらいました。 | 特許の人に住所を確認してもらいました。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/35093fd4-0511-4bdc-bfe4-e4c25c269654/script-line-0.mp3 |
| HN4-024 script:3 | 必要なことは受付の人にもう一度確認してもらいましょう。 | 必要なことはテフの人にもう一度確認してもらいましょう。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/35093fd4-0511-4bdc-bfe4-e4c25c269654/script-line-3.mp3 |
| HN4-024 question:1 | 受付의 뜻은? | 豆腐屋さん | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/35093fd4-0511-4bdc-bfe4-e4c25c269654/question-1.mp3 |
| HN4-024 question:2 | 住所의 뜻은? | ジュソイエ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/35093fd4-0511-4bdc-bfe4-e4c25c269654/question-2.mp3 |
| HN4-024 question:3 | 受付の人に住所を確認して___ました。 | 特地の人に住所確認してました | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/35093fd4-0511-4bdc-bfe4-e4c25c269654/question-3.mp3 |
| HN4-024 question:4 | 予約の時間も___もらいましたか。 | 予約の時間もあからん もらいましたか | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/35093fd4-0511-4bdc-bfe4-e4c25c269654/question-4.mp3 |
| HN4-024 question:5 | '접수처 직원에게 주소를 확인해 달라고 했습니다'를 배열하세요. | 受付の職員に住所を確認してほしいと頼みました。を配列してください。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/35093fd4-0511-4bdc-bfe4-e4c25c269654/question-5.mp3 |
| HN4-025 script:0 | 予約したのに、席がありませんでした。 | 予約したのに西がありませんでした。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b8b159a7-b8d4-45b3-a8d7-a9d07837b991/script-line-0.mp3 |
| HN4-025 script:1 | それは残念ですね。受付に連絡しましたか。 | それは残念ですね。デフテに連絡しましたか？ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b8b159a7-b8d4-45b3-a8d7-a9d07837b991/script-line-1.mp3 |
| HN4-025 script:3 | 期待と違う結果を話す時に、のにを使います。 | 期待と違う結果を話す時に何を使いますか？ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b8b159a7-b8d4-45b3-a8d7-a9d07837b991/script-line-3.mp3 |
| HN4-025 question:1 | 席의 뜻은? | CZSNN | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b8b159a7-b8d4-45b3-a8d7-a9d07837b991/question-1.mp3 |
| HN4-025 question:2 | 残念な의 뜻은? | 残念ない | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b8b159a7-b8d4-45b3-a8d7-a9d07837b991/question-2.mp3 |
| HN4-025 question:3 | 予約した___、席がありませんでした。 | 予約したリーダー日記がありませんでした | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b8b159a7-b8d4-45b3-a8d7-a9d07837b991/question-3.mp3 |
| HN4-025 question:4 | 時間に___のに、確認に時間がかかりました。 | 時間に間に合わないのに確認に時間がかかりました。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b8b159a7-b8d4-45b3-a8d7-a9d07837b991/question-4.mp3 |
| HN4-025 question:5 | '예약했는데도 자리가 없었습니다'를 배열하세요. | イェヤッ ケッヌンデド チャリガ オプソッスムニダを ベヨルハセヨ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b8b159a7-b8d4-45b3-a8d7-a9d07837b991/question-5.mp3 |
| HN4-026 script:0 | 駅の前で自転車を盗まれました。 | 家の前で自転車を盗まれました。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/ef3004f3-bca8-4621-b7aa-520cdde4e823/script-line-0.mp3 |
| HN4-026 script:1 | 落とし物ではなく、盗まれたんですね。 | 落とし物ではなくお盗まれなんですね。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/ef3004f3-bca8-4621-b7aa-520cdde4e823/script-line-1.mp3 |
| HN4-026 script:3 | 近くのカメラの映像がこれから確認されます。 | 近くのカメラの影響がこれから確認されます。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/ef3004f3-bca8-4621-b7aa-520cdde4e823/script-line-3.mp3 |
| HN4-026 question:1 | 自転車의 뜻은? | 自転車へディスイン | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/ef3004f3-bca8-4621-b7aa-520cdde4e823/question-1.mp3 |
| HN4-026 question:2 | 盗む의 뜻은? | タオムエタンシン | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/ef3004f3-bca8-4621-b7aa-520cdde4e823/question-2.mp3 |
| HN4-026 question:3 | 自転車を盗___ました。 | 自転車をアニメました。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/ef3004f3-bca8-4621-b7aa-520cdde4e823/question-3.mp3 |
| HN4-026 question:4 | 近くの人に声をかけ___て、すぐ警察に来ました。 | 近くの人に声をかけーてすぐ警察に来ました。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/ef3004f3-bca8-4621-b7aa-520cdde4e823/question-4.mp3 |
| HN4-026 question:5 | '자전거를 도난당했습니다'를 배열하세요. | チャジョンゴル ドナンタンヘッスムニダ を ベヨルハセヨ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/ef3004f3-bca8-4621-b7aa-520cdde4e823/question-5.mp3 |

## Decision

REVIEW: inspect STT mismatches before recording final audio verdicts.
