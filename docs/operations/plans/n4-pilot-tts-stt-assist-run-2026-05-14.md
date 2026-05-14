# N4 TTS Audio QA Machine Report

> Status: REVIEW
> Scope: generated lesson script-line and question-prompt TTS targets
> Boundary: machine/STT evidence only; human audio verdicts remain required

## Command

```bash
uv run python scripts/audit_n4_pilot_tts_audio_quality.py --level N4 --transcribe --markdown-output ../../docs/operations/plans/n4-pilot-tts-stt-assist-run-2026-05-14.md
```

## Summary

| Metric | Result |
|---|---:|
| Total targets | 99 |
| Machine pass | 99 |
| Blocked targets | 0 |
| Warning count | 84 |
| Transcribed targets | 99 |
| STT exact matches | 26 |
| STT mismatches | 73 |
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

- HN4-001 script:3: TRANSCRIPTION_TEXT_MISMATCH:わかりました。定時に確認します。
- HN4-001 question:1: TRANSCRIPTION_TEXT_MISMATCH:機序、イエッスン
- HN4-001 question:2: TRANSCRIPTION_TEXT_MISMATCH:ジュリー、イェー
- HN4-001 question:3: HIGH_SILENCE_RATIO:0.3863, TRANSCRIPTION_TEXT_MISMATCH:名前を書き イムルスセヨ
- HN4-001 question:4: TRANSCRIPTION_TEXT_MISMATCH:基礎を確認 キジクルファキナセヨ
- HN4-001 question:5: TRANSCRIPTION_TEXT_MISMATCH:名前を쓰세요を正しい順序で配列してください。
- HN4-002 script:0: TRANSCRIPTION_TEXT_MISMATCH:少し頭が痛い
- HN4-002 script:1: TRANSCRIPTION_TEXT_MISMATCH:心配ですね。今日は早く寝た方がいいです。
- HN4-002 script:2: TRANSCRIPTION_TEXT_MISMATCH:医者に相談した方がいいです。
- HN4-002 script:3: TRANSCRIPTION_TEXT_MISMATCH:熱があれば医者に相談した方が安心です。
- HN4-002 question:1: TRANSCRIPTION_TEXT_MISMATCH:しんぺいげんつ
- HN4-002 question:2: TRANSCRIPTION_TEXT_MISMATCH:シャンダンエー
- HN4-002 question:3: TRANSCRIPTION_TEXT_MISMATCH:たやこ へん あら イルチッ ジャヌン ピョニ チョッスムニダ
- HN4-002 question:4: HIGH_SILENCE_RATIO:0.3876, TRANSCRIPTION_TEXT_MISMATCH:医者に相談 医者と相談する方がいいです
- HN4-003 script:1: TRANSCRIPTION_TEXT_MISMATCH:じゃあ、会計に値に合わないかもしれないですね。
- HN4-003 question:1: TRANSCRIPTION_TEXT_MISMATCH:タイフン
- HN4-003 question:2: TRANSCRIPTION_TEXT_MISMATCH:カニアウエイト
- HN4-003 question:3: HIGH_SILENCE_RATIO:0.3646, TRANSCRIPTION_TEXT_MISMATCH:転写が遅れる ちょんちょり ぬじるちど もるにだ
- HN4-003 question:4: HIGH_SILENCE_RATIO:0.4078, TRANSCRIPTION_TEXT_MISMATCH:間に合わない。 時間に間に合わないかもしれません。
- HN4-004 script:0: TRANSCRIPTION_TEXT_MISMATCH:時間が足りません。江木まで走るしかありません。
- HN4-004 script:1: TRANSCRIPTION_TEXT_MISMATCH:次の予定がありますから
- HN4-004 script:3: TRANSCRIPTION_TEXT_MISMATCH:始めないで競いに行きましょう
- HN4-004 question:1: TRANSCRIPTION_TEXT_MISMATCH:たりとえぬ
- HN4-004 question:2: TRANSCRIPTION_TEXT_MISMATCH:ゆでやしん
- HN4-004 question:3: TRANSCRIPTION_TEXT_MISMATCH:走るかい タリル スバッケ オプスムニダ
- HN4-004 question:4: HIGH_SILENCE_RATIO:0.3813, TRANSCRIPTION_TEXT_MISMATCH:電車に乗るは ちょんちょろをたるすわけありません。
- HN4-004 question:5: TRANSCRIPTION_TEXT_MISMATCH:よっかぢ たっりるしゅばっけ おぷすんにだ を はいれつはぜよ
- HN4-005 script:1: TRANSCRIPTION_TEXT_MISMATCH:文も翻訳できます。
- HN4-005 script:2: TRANSCRIPTION_TEXT_MISMATCH:はい、授業の予約にも申し込みます。
- HN4-005 question:1: TRANSCRIPTION_TEXT_MISMATCH:ファンヤクエトス
- HN4-005 question:2: TRANSCRIPTION_TEXT_MISMATCH:申し込む
- HN4-005 question:3: TRANSCRIPTION_TEXT_MISMATCH:漢字を調べ、赤字ら、한자를 찾아볼 수 있습니다。
- HN4-005 question:4: HIGH_SILENCE_RATIO:0.3968, TRANSCRIPTION_TEXT_MISMATCH:文語翻訳 文章を翻訳することができます
- HN4-006 script:0: TRANSCRIPTION_TEXT_MISMATCH:骨の傘を実で確認しました。
- HN4-006 script:1: TRANSCRIPTION_TEXT_MISMATCH:この歯の舞さも分かりますか
- HN4-006 script:2: TRANSCRIPTION_TEXT_MISMATCH:はい。不当操作や操作もみられます。
- HN4-006 question:1: TRANSCRIPTION_TEXT_MISMATCH:カメヤギ
- HN4-006 question:2: TRANSCRIPTION_TEXT_MISMATCH:正しい
- HN4-006 question:3: TRANSCRIPTION_TEXT_MISMATCH:国の金を確認します。法成企ビルを確認します。
- HN4-006 question:4: HIGH_SILENCE_RATIO:0.3523, TRANSCRIPTION_TEXT_MISMATCH:洗脳体を見ます。そうね、クッキリを見ます。
- HN4-006 question:5: TRANSCRIPTION_TEXT_MISMATCH:ホスエエギピルル確認しましたを配列はせよ
- HN4-007 question:1: TRANSCRIPTION_TEXT_MISMATCH:ジャンカするエポ
- HN4-007 question:2: TRANSCRIPTION_TEXT_MISMATCH:カツメルシン
- HN4-007 question:3: TRANSCRIPTION_TEXT_MISMATCH:イベントに参加 と思っています。
- HN4-007 question:4: TRANSCRIPTION_TEXT_MISMATCH:案内を奏なちと思っています。
- HN4-007 question:5: TRANSCRIPTION_TEXT_MISMATCH:弊社に参加しようと 考えていますを 手配ください
- HN4-008 script:0: TRANSCRIPTION_TEXT_MISMATCH:半時が遅れてすみません。
- HN4-008 script:2: TRANSCRIPTION_TEXT_MISMATCH:会議が長かった
- HN4-008 question:1: TRANSCRIPTION_TEXT_MISMATCH:ディユーイェスン
- HN4-008 question:2: TRANSCRIPTION_TEXT_MISMATCH:ファンシー
- HN4-008 question:3: HIGH_SILENCE_RATIO:0.4026, TRANSCRIPTION_TEXT_MISMATCH:会議がなかった フェイが消ろとんごよ
- HN4-008 question:4: TRANSCRIPTION_TEXT_MISMATCH:理由があった。なーなか。理由があったんがよ？
- HN4-008 question:5: TRANSCRIPTION_TEXT_MISMATCH:フェイが長かったんですよを配列세요。
- HN4-009 question:1: TRANSCRIPTION_TEXT_MISMATCH:面接
- HN4-009 question:2: TRANSCRIPTION_TEXT_MISMATCH:準備役員
- HN4-009 question:3: TRANSCRIPTION_TEXT_MISMATCH:面接、アクタ、練習しています。 面接、ウィヘ、練習、ハコイスミダ。
- HN4-009 question:4: HIGH_SILENCE_RATIO:0.4041, TRANSCRIPTION_TEXT_MISMATCH:給食する 準備します
- HN4-009 question:5: TRANSCRIPTION_TEXT_MISMATCH:面接のために準備していますを配列
- HN4-010 script:2: TRANSCRIPTION_TEXT_MISMATCH:はい、自然な結果を言う時に使います。
- HN4-010 script:3: TRANSCRIPTION_TEXT_MISMATCH:何か届くとメールが来ます。
- HN4-010 question:1: TRANSCRIPTION_TEXT_MISMATCH:新興エコタウン
- HN4-010 question:2: TRANSCRIPTION_TEXT_MISMATCH:得てして
- HN4-010 question:3: TRANSCRIPTION_TEXT_MISMATCH:ボタンを押す 画面が変わります
- HN4-010 question:4: HIGH_SILENCE_RATIO:0.3915, TRANSCRIPTION_TEXT_MISMATCH:信号が青になる 車が進みます
- HN4-010 question:5: TRANSCRIPTION_TEXT_MISMATCH:ボタンを押すと画面が変わります。る ベヨルハセヨ
- HN4-011 script:0: TRANSCRIPTION_TEXT_MISMATCH:ノートを選ぶ前に コムの厚さを比べています
- HN4-011 script:1: TRANSCRIPTION_TEXT_MISMATCH:石と薄い石があります。
- HN4-011 script:2: TRANSCRIPTION_TEXT_MISMATCH:はい、このシビの柔らかさも確認します。
- HN4-011 script:3: TRANSCRIPTION_TEXT_MISMATCH:硬さ、柔らかさを比べて選びましょう。
- HN4-011 question:1: TRANSCRIPTION_TEXT_MISMATCH:ほ いえすん
- HN4-011 question:2: TRANSCRIPTION_TEXT_MISMATCH:やわらかい
- HN4-011 question:3: HIGH_SILENCE_RATIO:0.359, TRANSCRIPTION_TEXT_MISMATCH:カビの音 お比べます。 ジョンギエたける比較します。
- HN4-011 question:4: TRANSCRIPTION_TEXT_MISMATCH:この詩の柔らかを確認します。イ チョンゲ ブドロウン ジョンドゥルル ホギナムニダ。

## STT Mismatches

| Target | Source text | STT transcript | Strict blocker mode | Audio |
|---|---|---|---|---|
| HN4-001 script:3 | 分かりました。丁寧に確認します。 | わかりました。定時に確認します。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/script-line-3.mp3 |
| HN4-001 question:1 | 規則의 뜻은? | 機序、イエッスン | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/question-1.mp3 |
| HN4-001 question:2 | 注意의 뜻은? | ジュリー、イェー | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/question-2.mp3 |
| HN4-001 question:3 | 名前を書き___. (이름을 쓰세요.) | 名前を書き イムルスセヨ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/question-3.mp3 |
| HN4-001 question:4 | 規則を確認___. (규칙을 확인하세요.) | 基礎を確認 キジクルファキナセヨ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/question-4.mp3 |
| HN4-001 question:5 | '이름을 쓰세요'를 올바른 순서로 배열하세요. | 名前を쓰세요を正しい順序で配列してください。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/question-5.mp3 |
| HN4-002 script:0 | 少し頭が痛いです。 | 少し頭が痛い | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/script-line-0.mp3 |
| HN4-002 script:1 | 心配ですね。今日は早く寝たほうがいいです。 | 心配ですね。今日は早く寝た方がいいです。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/script-line-1.mp3 |
| HN4-002 script:2 | 医者に相談したほうがいいですか。 | 医者に相談した方がいいです。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/script-line-2.mp3 |
| HN4-002 script:3 | 熱があれば、医者に相談したほうが安心です。 | 熱があれば医者に相談した方が安心です。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/script-line-3.mp3 |
| HN4-002 question:1 | 心配의 뜻은? | しんぺいげんつ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/question-1.mp3 |
| HN4-002 question:2 | 相談의 뜻은? | シャンダンエー | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/question-2.mp3 |
| HN4-002 question:3 | 早く寝___。 (일찍 자는 편이 좋습니다.) | たやこ へん あら イルチッ ジャヌン ピョニ チョッスムニダ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/question-3.mp3 |
| HN4-002 question:4 | 医者に相談___。 (의사와 상담하는 편이 좋습니다.) | 医者に相談 医者と相談する方がいいです | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/question-4.mp3 |
| HN4-003 script:1 | じゃあ、会議に間に合わないかもしれませんね。 | じゃあ、会計に値に合わないかもしれないですね。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/script-line-1.mp3 |
| HN4-003 question:1 | 台風의 뜻은? | タイフン | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/question-1.mp3 |
| HN4-003 question:2 | 間に合う의 뜻은? | カニアウエイト | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/question-2.mp3 |
| HN4-003 question:3 | 電車が遅れる___。 (전철이 늦을지도 모릅니다.) | 転写が遅れる ちょんちょり ぬじるちど もるにだ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/question-3.mp3 |
| HN4-003 question:4 | 間に合わない___。 (시간에 맞지 못할지도 모릅니다.) | 間に合わない。 時間に間に合わないかもしれません。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/question-4.mp3 |
| HN4-004 script:0 | 時間が足りません。駅まで走るしかありません。 | 時間が足りません。江木まで走るしかありません。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/script-line-0.mp3 |
| HN4-004 script:1 | 次の予定がありますからね。 | 次の予定がありますから | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/script-line-1.mp3 |
| HN4-004 script:3 | 諦めないで、急いで行きましょう。 | 始めないで競いに行きましょう | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/script-line-3.mp3 |
| HN4-004 question:1 | 足りる의 뜻은? | たりとえぬ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/question-1.mp3 |
| HN4-004 question:2 | 予定의 뜻은? | ゆでやしん | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/question-2.mp3 |
| HN4-004 question:3 | 走る___。 (달릴 수밖에 없습니다.) | 走るかい タリル スバッケ オプスムニダ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/question-3.mp3 |
| HN4-004 question:4 | 電車に乗る___。 (전철을 탈 수밖에 없습니다.) | 電車に乗るは ちょんちょろをたるすわけありません。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/question-4.mp3 |
| HN4-004 question:5 | '역까지 달릴 수밖에 없습니다'를 배열하세요. | よっかぢ たっりるしゅばっけ おぷすんにだ を はいれつはぜよ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/question-5.mp3 |
| HN4-005 script:1 | 文も翻訳できますか。 | 文も翻訳できます。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/script-line-1.mp3 |
| HN4-005 script:2 | はい。授業の予約にも申し込めます。 | はい、授業の予約にも申し込みます。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/script-line-2.mp3 |
| HN4-005 question:1 | 翻訳의 뜻은? | ファンヤクエトス | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/question-1.mp3 |
| HN4-005 question:2 | 申し込む의 뜻은? | 申し込む | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/question-2.mp3 |
| HN4-005 question:3 | 漢字を調べ___。 (한자를 찾아볼 수 있습니다.) | 漢字を調べ、赤字ら、한자를 찾아볼 수 있습니다。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/question-3.mp3 |
| HN4-005 question:4 | 文を翻訳___。 (문장을 번역할 수 있습니다.) | 文語翻訳 文章を翻訳することができます | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/question-4.mp3 |
| HN4-006 script:0 | 湖の深さを地図で確認しました。 | 骨の傘を実で確認しました。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/script-line-0.mp3 |
| HN4-006 script:1 | この川の浅さも分かりますか。 | この歯の舞さも分かりますか | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/script-line-1.mp3 |
| HN4-006 script:2 | はい。線の太さや細さも見られます。 | はい。不当操作や操作もみられます。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/script-line-2.mp3 |
| HN4-006 question:1 | 深い의 뜻은? | カメヤギ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/question-1.mp3 |
| HN4-006 question:2 | 正しい의 뜻은? | 正しい | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/question-2.mp3 |
| HN4-006 question:3 | 湖の深___を確認します。 (호수의 깊이를 확인합니다.) | 国の金を確認します。法成企ビルを確認します。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/question-3.mp3 |
| HN4-006 question:4 | 線の太___を見ます。 (선의 굵기를 봅니다.) | 洗脳体を見ます。そうね、クッキリを見ます。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/question-4.mp3 |
| HN4-006 question:5 | '호수의 깊이를 확인했습니다'를 배열하세요. | ホスエエギピルル確認しましたを配列はせよ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/question-5.mp3 |
| HN4-007 question:1 | 参加する의 뜻은? | ジャンカするエポ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/question-1.mp3 |
| HN4-007 question:2 | 集める의 뜻은? | カツメルシン | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/question-2.mp3 |
| HN4-007 question:3 | イベントに参加___と思っています。 | イベントに参加 と思っています。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/question-3.mp3 |
| HN4-007 question:4 | 案内を送___と思っています。 | 案内を奏なちと思っています。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/question-4.mp3 |
| HN4-007 question:5 | '행사에 참가하려고 생각하고 있습니다'를 배열하세요. | 弊社に参加しようと 考えていますを 手配ください | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/question-5.mp3 |
| HN4-008 script:0 | 返事が遅れてすみません。 | 半時が遅れてすみません。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/script-line-0.mp3 |
| HN4-008 script:2 | 会議が長かったのです。 | 会議が長かった | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/script-line-2.mp3 |
| HN4-008 question:1 | 理由의 뜻은? | ディユーイェスン | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/question-1.mp3 |
| HN4-008 question:2 | 返事의 뜻은? | ファンシー | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/question-2.mp3 |
| HN4-008 question:3 | 会議が長かった___。 (회의가 길었던 거예요.) | 会議がなかった フェイが消ろとんごよ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/question-3.mp3 |
| HN4-008 question:4 | 理由があった___か。 (이유가 있었던 건가요?) | 理由があった。なーなか。理由があったんがよ？ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/question-4.mp3 |
| HN4-008 question:5 | '회의가 길었던 거예요'를 배열하세요. | フェイが長かったんですよを配列세요。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/question-5.mp3 |
| HN4-009 question:1 | 面接의 뜻은? | 面接 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/question-1.mp3 |
| HN4-009 question:2 | 準備의 뜻은? | 準備役員 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/question-2.mp3 |
| HN4-009 question:3 | 面接___、練習しています。 (면접을 위해 연습하고 있습니다.) | 面接、アクタ、練習しています。 面接、ウィヘ、練習、ハコイスミダ。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/question-3.mp3 |
| HN4-009 question:4 | 就職する___、準備します。 (취직하기 위해 준비합니다.) | 給食する 準備します | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/question-4.mp3 |
| HN4-009 question:5 | '면접을 위해 준비하고 있습니다'를 배열하세요. | 面接のために準備していますを配列 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/question-5.mp3 |
| HN4-010 script:2 | はい。自然な結果を言うときに使います。 | はい、自然な結果を言う時に使います。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/script-line-2.mp3 |
| HN4-010 script:3 | 荷物が届くと、メールが来ます。 | 何か届くとメールが来ます。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/script-line-3.mp3 |
| HN4-010 question:1 | 信号의 뜻은? | 新興エコタウン | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/question-1.mp3 |
| HN4-010 question:2 | 届く의 뜻은? | 得てして | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/question-2.mp3 |
| HN4-010 question:3 | ボタンを押す___、画面が変わります。 | ボタンを押す 画面が変わります | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/question-3.mp3 |
| HN4-010 question:4 | 信号が青になる___、車が進みます。 | 信号が青になる 車が進みます | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/question-4.mp3 |
| HN4-010 question:5 | '버튼을 누르면 화면이 바뀝니다'를 배열하세요. | ボタンを押すと画面が変わります。る ベヨルハセヨ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/question-5.mp3 |
| HN4-011 script:0 | ノートを選ぶ前に、紙の厚さを比べています。 | ノートを選ぶ前に コムの厚さを比べています | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/script-line-0.mp3 |
| HN4-011 script:1 | 厚い紙と薄い紙がありますね。 | 石と薄い石があります。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/script-line-1.mp3 |
| HN4-011 script:2 | はい。この紙の柔らかさも確認します。 | はい、このシビの柔らかさも確認します。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/script-line-2.mp3 |
| HN4-011 script:3 | 厚さと柔らかさを比べて選びましょう。 | 硬さ、柔らかさを比べて選びましょう。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/script-line-3.mp3 |
| HN4-011 question:1 | 厚い의 뜻은? | ほ いえすん | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/question-1.mp3 |
| HN4-011 question:2 | 柔らかい의 뜻은? | やわらかい | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/question-2.mp3 |
| HN4-011 question:3 | 紙の厚___を比べます。 (종이의 두께를 비교합니다.) | カビの音 お比べます。 ジョンギエたける比較します。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/question-3.mp3 |
| HN4-011 question:4 | この紙の柔らか___を確認します。 (이 종이의 부드러운 정도를 확인합니다.) | この詩の柔らかを確認します。イ チョンゲ ブドロウン ジョンドゥルル ホギナムニダ。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/question-4.mp3 |

## Decision

REVIEW: inspect STT mismatches before recording final audio verdicts.
