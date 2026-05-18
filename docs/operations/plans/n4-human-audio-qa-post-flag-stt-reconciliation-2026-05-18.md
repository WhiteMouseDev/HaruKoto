# N4 Audio QA STT Reconciliation

> Status: TRIAGE ONLY - no verdicts applied
> Boundary: STT mismatch reconciliation only; does not replace listening or native-speaker review

ASSUMPTION: This report helps reduce review ambiguity while preserving
the current verdict gate. It does not set `PASS`, `FLAG`, `FAIL`, or
`WAIVED` on any packet row.

## Sources

- Packet: `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md`
- Packet: `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md`
- Packet: `docs/operations/plans/n4-pilot-human-audio-qa-ch03-2026-05-13.md`
- Quality signal report: `docs/operations/plans/n4-pilot-tts-machine-report-2026-05-14.md`
- Quality signal report: `docs/operations/plans/n4-pilot-tts-stt-assist-run-2026-05-14.md`

## Summary

| Metric | Count |
|---|---:|
| Total review items | 99 |
| Pending review-signal items | 62 |
| P0 machine-warning retained first | 11 |
| P1 STT-only items | 51 |
| Canonical text matches | 0 |
| Near Japanese matches | 11 |
| Mixed/Korean prompt STT-unreliable | 40 |
| Lexical-risk Japanese mismatches | 0 |
| Missing STT transcript | 0 |

## Review Order

1. Listen to `P0_MACHINE_WARNING` rows first because high silence ratio
   can hide pacing or truncation problems even when the audio file exists.
2. Review `LEXICAL_RISK` rows next because the transcript diverges from
   the source enough to suggest possible wrong-word audio.
3. Use `NEAR_JAPANESE_MATCH` and `CANONICAL_MATCH` rows as lower-risk
   candidates for delegated PASS after a spot listen.
4. Treat `MIXED_PROMPT_STT_UNRELIABLE` as a prompt-design/STT limitation;
   decide by direct playback rather than transcript mismatch alone.

## CSV Apply Boundary

The companion CSV leaves `new_verdict` and `new_notes` blank. Fill those
columns only after direct listening or an explicitly delegated review step.


## P0_MACHINE_WARNING

| Bucket | Target | Source text | STT transcript | Similarity | Signals | Recommended action | Audio |
|---|---|---|---|---:|---|---|---|
| P0_MACHINE_WARNING | HN4-001 question:3 | 名前を書き___. (이름을 쓰세요.) | 名前を書き イムルスセヨ | 0.455 | HIGH_SILENCE_RATIO:0.3863, TRANSCRIPTION_TEXT_MISMATCH:名前を書き イムルスセヨ | listen first; check silence/spacing, intelligibility, and text completeness before setting PASS/FLAG/FAIL | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/question-3.mp3) |
| P0_MACHINE_WARNING | HN4-002 question:4 | 医者に相談___。 (의사와 상담하는 편이 좋습니다.) | 医者に相談 医者と相談する方がいいです | 0.270 | HIGH_SILENCE_RATIO:0.3876, TRANSCRIPTION_TEXT_MISMATCH:医者に相談 医者と相談する方がいいです | listen first; check silence/spacing, intelligibility, and text completeness before setting PASS/FLAG/FAIL | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/question-4.mp3) |
| P0_MACHINE_WARNING | HN4-003 question:3 | 電車が遅れる___。 (전철이 늦을지도 모릅니다.) | 転写が遅れる ちょんちょり ぬじるちど もるにだ | 0.211 | HIGH_SILENCE_RATIO:0.3646, TRANSCRIPTION_TEXT_MISMATCH:転写が遅れる ちょんちょり ぬじるちど もるにだ | listen first; check silence/spacing, intelligibility, and text completeness before setting PASS/FLAG/FAIL | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/question-3.mp3) |
| P0_MACHINE_WARNING | HN4-003 question:4 | 間に合わない___。 (시간에 맞지 못할지도 모릅니다.) | 間に合わない。 時間に間に合わないかもしれません。 | 0.286 | HIGH_SILENCE_RATIO:0.4078, TRANSCRIPTION_TEXT_MISMATCH:間に合わない。 時間に間に合わないかもしれません。 | listen first; check silence/spacing, intelligibility, and text completeness before setting PASS/FLAG/FAIL | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/question-4.mp3) |
| P0_MACHINE_WARNING | HN4-004 question:4 | 電車に乗る___。 (전철을 탈 수밖에 없습니다.) | 電車に乗るは ちょんちょろをたるすわけありません。 | 0.256 | HIGH_SILENCE_RATIO:0.3813, TRANSCRIPTION_TEXT_MISMATCH:電車に乗るは ちょんちょろをたるすわけありません。 | listen first; check silence/spacing, intelligibility, and text completeness before setting PASS/FLAG/FAIL | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/question-4.mp3) |
| P0_MACHINE_WARNING | HN4-005 question:4 | 文を翻訳___。 (문장을 번역할 수 있습니다.) | 文語翻訳 文章を翻訳することができます | 0.242 | HIGH_SILENCE_RATIO:0.3968, TRANSCRIPTION_TEXT_MISMATCH:文語翻訳 文章を翻訳することができます | listen first; check silence/spacing, intelligibility, and text completeness before setting PASS/FLAG/FAIL | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/question-4.mp3) |
| P0_MACHINE_WARNING | HN4-006 question:4 | 線の太___を見ます。 (선의 굵기를 봅니다.) | 洗脳体を見ます。そうね、クッキリを見ます。 | 0.242 | HIGH_SILENCE_RATIO:0.3523, TRANSCRIPTION_TEXT_MISMATCH:洗脳体を見ます。そうね、クッキリを見ます。 | listen first; check silence/spacing, intelligibility, and text completeness before setting PASS/FLAG/FAIL | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/question-4.mp3) |
| P0_MACHINE_WARNING | HN4-008 question:3 | 会議が長かった___。 (회의가 길었던 거예요.) | 会議がなかった フェイが消ろとんごよ | 0.364 | HIGH_SILENCE_RATIO:0.4026, TRANSCRIPTION_TEXT_MISMATCH:会議がなかった フェイが消ろとんごよ | listen first; check silence/spacing, intelligibility, and text completeness before setting PASS/FLAG/FAIL | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/question-3.mp3) |
| P0_MACHINE_WARNING | HN4-009 question:4 | 就職する___、準備します。 (취직하기 위해 준비합니다.) | 給食する 準備します | 0.483 | HIGH_SILENCE_RATIO:0.4041, TRANSCRIPTION_TEXT_MISMATCH:給食する 準備します | listen first; check silence/spacing, intelligibility, and text completeness before setting PASS/FLAG/FAIL | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/question-4.mp3) |
| P0_MACHINE_WARNING | HN4-010 question:4 | 信号が青になる___、車が進みます。 | 信号が青になる 車が進みます | 1.000 | HIGH_SILENCE_RATIO:0.3915, TRANSCRIPTION_TEXT_MISMATCH:信号が青になる 車が進みます | listen first; check silence/spacing, intelligibility, and text completeness before setting PASS/FLAG/FAIL | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/question-4.mp3) |
| P0_MACHINE_WARNING | HN4-011 question:3 | 紙の厚___を比べます。 (종이의 두께를 비교합니다.) | カビの音 お比べます。 ジョンギエたける比較します。 | 0.244 | HIGH_SILENCE_RATIO:0.359, TRANSCRIPTION_TEXT_MISMATCH:カビの音 お比べます。 ジョンギエたける比較します。 | listen first; check silence/spacing, intelligibility, and text completeness before setting PASS/FLAG/FAIL | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/question-3.mp3) |

## LEXICAL_RISK

- None

## NEAR_JAPANESE_MATCH

| Bucket | Target | Source text | STT transcript | Similarity | Signals | Recommended action | Audio |
|---|---|---|---|---:|---|---|---|
| NEAR_JAPANESE_MATCH | HN4-002 script:0 | 少し頭が痛いです。 | 少し頭が痛い | 0.857 | TRANSCRIPTION_TEXT_MISMATCH:少し頭が痛い | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/script-line-0.mp3) |
| NEAR_JAPANESE_MATCH | HN4-002 script:2 | 医者に相談したほうがいいですか。 | 医者に相談した方がいいです。 | 0.966 | TRANSCRIPTION_TEXT_MISMATCH:医者に相談した方がいいです。 | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/script-line-2.mp3) |
| NEAR_JAPANESE_MATCH | HN4-004 script:0 | 時間が足りません。駅まで走るしかありません。 | 時間が足りません。江木まで走るしかありません。 | 0.930 | TRANSCRIPTION_TEXT_MISMATCH:時間が足りません。江木まで走るしかありません。 | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/script-line-0.mp3) |
| NEAR_JAPANESE_MATCH | HN4-004 script:1 | 次の予定がありますからね。 | 次の予定がありますから | 0.957 | TRANSCRIPTION_TEXT_MISMATCH:次の予定がありますから | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/script-line-1.mp3) |
| NEAR_JAPANESE_MATCH | HN4-005 script:1 | 文も翻訳できますか。 | 文も翻訳できます。 | 0.941 | TRANSCRIPTION_TEXT_MISMATCH:文も翻訳できます。 | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/script-line-1.mp3) |
| NEAR_JAPANESE_MATCH | HN4-005 script:2 | はい。授業の予約にも申し込めます。 | はい、授業の予約にも申し込みます。 | 0.933 | TRANSCRIPTION_TEXT_MISMATCH:はい、授業の予約にも申し込みます。 | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/script-line-2.mp3) |
| NEAR_JAPANESE_MATCH | HN4-006 script:1 | この川の浅さも分かりますか。 | この歯の舞さも分かりますか | 0.846 | TRANSCRIPTION_TEXT_MISMATCH:この歯の舞さも分かりますか | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/script-line-1.mp3) |
| NEAR_JAPANESE_MATCH | HN4-008 script:2 | 会議が長かったのです。 | 会議が長かった | 0.824 | TRANSCRIPTION_TEXT_MISMATCH:会議が長かった | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/script-line-2.mp3) |
| NEAR_JAPANESE_MATCH | HN4-011 script:0 | ノートを選ぶ前に、紙の厚さを比べています。 | ノートを選ぶ前に コムの厚さを比べています | 0.923 | TRANSCRIPTION_TEXT_MISMATCH:ノートを選ぶ前に コムの厚さを比べています | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/script-line-0.mp3) |
| NEAR_JAPANESE_MATCH | HN4-011 script:2 | はい。この紙の柔らかさも確認します。 | はい、このシビの柔らかさも確認します。 | 0.909 | TRANSCRIPTION_TEXT_MISMATCH:はい、このシビの柔らかさも確認します。 | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/script-line-2.mp3) |
| NEAR_JAPANESE_MATCH | HN4-011 script:3 | 厚さと柔らかさを比べて選びましょう。 | 硬さ、柔らかさを比べて選びましょう。 | 0.909 | TRANSCRIPTION_TEXT_MISMATCH:硬さ、柔らかさを比べて選びましょう。 | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/script-line-3.mp3) |

## CANONICAL_MATCH

- None

## MIXED_PROMPT_STT_UNRELIABLE

| Bucket | Target | Source text | STT transcript | Similarity | Signals | Recommended action | Audio |
|---|---|---|---|---:|---|---|---|
| MIXED_PROMPT_STT_UNRELIABLE | HN4-001 question:1 | 規則의 뜻은? | 機序、イエッスン | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:機序、イエッスン | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/question-1.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-001 question:2 | 注意의 뜻은? | ジュリー、イェー | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:ジュリー、イェー | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/question-2.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-001 question:4 | 規則を確認___. (규칙을 확인하세요.) | 基礎を確認 キジクルファキナセヨ | 0.214 | TRANSCRIPTION_TEXT_MISMATCH:基礎を確認 キジクルファキナセヨ | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/question-4.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-001 question:5 | '이름을 쓰세요'를 올바른 순서로 배열하세요. | 名前を쓰세요を正しい順序で配列してください。 | 0.154 | TRANSCRIPTION_TEXT_MISMATCH:名前を쓰세요を正しい順序で配列してください。 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/question-5.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-002 question:1 | 心配의 뜻은? | しんぺいげんつ | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:しんぺいげんつ | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/question-1.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-002 question:2 | 相談의 뜻은? | シャンダンエー | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:シャンダンエー | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/question-2.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-002 question:3 | 早く寝___。 (일찍 자는 편이 좋습니다.) | たやこ へん あら イルチッ ジャヌン ピョニ チョッスムニダ | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:たやこ へん あら イルチッ ジャヌン ピョニ チョッスムニダ | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/question-3.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-003 question:1 | 台風의 뜻은? | タイフン | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:タイフン | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/question-1.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-003 question:2 | 間に合う의 뜻은? | カニアウエイト | 0.286 | TRANSCRIPTION_TEXT_MISMATCH:カニアウエイト | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/question-2.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-004 question:1 | 足りる의 뜻은? | たりとえぬ | 0.182 | TRANSCRIPTION_TEXT_MISMATCH:たりとえぬ | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/question-1.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-004 question:2 | 予定의 뜻은? | ゆでやしん | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:ゆでやしん | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/question-2.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-004 question:3 | 走る___。 (달릴 수밖에 없습니다.) | 走るかい タリル スバッケ オプスムニダ | 0.143 | TRANSCRIPTION_TEXT_MISMATCH:走るかい タリル スバッケ オプスムニダ | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/question-3.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-004 question:5 | '역까지 달릴 수밖에 없습니다'를 배열하세요. | よっかぢ たっりるしゅばっけ おぷすんにだ を はいれつはぜよ | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:よっかぢ たっりるしゅばっけ おぷすんにだ を はいれつはぜよ | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/question-5.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-005 question:1 | 翻訳의 뜻은? | ファンヤクエトス | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:ファンヤクエトス | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/question-1.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-005 question:2 | 申し込む의 뜻은? | 申し込む | 0.727 | TRANSCRIPTION_TEXT_MISMATCH:申し込む | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/question-2.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-005 question:3 | 漢字を調べ___。 (한자를 찾아볼 수 있습니다.) | 漢字を調べ、赤字ら、한자를 찾아볼 수 있습니다。 | 0.914 | TRANSCRIPTION_TEXT_MISMATCH:漢字を調べ、赤字ら、한자를 찾아볼 수 있습니다。 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/question-3.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-006 question:1 | 深い의 뜻은? | カメヤギ | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:カメヤギ | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/question-1.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-006 question:2 | 正しい의 뜻은? | 正しい | 0.667 | TRANSCRIPTION_TEXT_MISMATCH:正しい | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/question-2.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-006 question:3 | 川の深___を確認します。 (강의 깊이를 확인합니다.) | 国の金を確認します。法成企ビルを確認します。 | 0.359 | TRANSCRIPTION_TEXT_MISMATCH:国の金を確認します。法成企ビルを確認します。 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/question-3-regen-20260518T021500Z.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-006 question:5 | '강의 깊이를 확인했습니다'를 배열하세요. | ホスエエギピルル確認しましたを配列はせよ | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:ホスエエギピルル確認しましたを配列はせよ | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/question-5-regen-20260518T021500Z.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-007 question:1 | 参加する의 뜻은? | ジャンカするエポ | 0.267 | TRANSCRIPTION_TEXT_MISMATCH:ジャンカするエポ | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/question-1.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-007 question:2 | 集める의 뜻은? | カツメルシン | 0.333 | TRANSCRIPTION_TEXT_MISMATCH:カツメルシン | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/question-2.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-007 question:3 | イベントに参加___と思っています。 | イベントに参加 と思っています。 | 1.000 | TRANSCRIPTION_TEXT_MISMATCH:イベントに参加 と思っています。 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/question-3.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-007 question:4 | 案内を送___と思っています。 | 案内を奏なちと思っています。 | 0.833 | TRANSCRIPTION_TEXT_MISMATCH:案内を奏なちと思っています。 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/question-4.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-007 question:5 | '행사에 참가하려고 생각하고 있습니다'를 배열하세요. | 弊社に参加しようと 考えていますを 手配ください | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:弊社に参加しようと 考えていますを 手配ください | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/question-5.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-008 question:1 | 理由의 뜻은? | ディユーイェスン | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:ディユーイェスン | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/question-1.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-008 question:2 | 返事의 뜻은? | ファンシー | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:ファンシー | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/question-2.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-008 question:4 | 理由があった___か。 (이유가 있었던 건가요?) | 理由があった。なーなか。理由があったんがよ？ | 0.400 | TRANSCRIPTION_TEXT_MISMATCH:理由があった。なーなか。理由があったんがよ？ | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/question-4.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-008 question:5 | '회의가 길었던 거예요'를 배열하세요. | フェイが長かったんですよを配列세요。 | 0.125 | TRANSCRIPTION_TEXT_MISMATCH:フェイが長かったんですよを配列세요。 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/question-5.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-009 question:1 | 面接의 뜻은? | 面接 | 0.571 | TRANSCRIPTION_TEXT_MISMATCH:面接 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/question-1.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-009 question:2 | 準備의 뜻은? | 準備役員 | 0.444 | TRANSCRIPTION_TEXT_MISMATCH:準備役員 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/question-2.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-009 question:3 | 面接___、練習しています。 (면접을 위해 연습하고 있습니다.) | 面接、アクタ、練習しています。 面接、ウィヘ、練習、ハコイスミダ。 | 0.383 | TRANSCRIPTION_TEXT_MISMATCH:面接、アクタ、練習しています。 面接、ウィヘ、練習、ハコイスミダ。 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/question-3.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-009 question:5 | '면접을 위해 준비하고 있습니다'를 배열하세요. | 面接のために準備していますを配列 | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:面接のために準備していますを配列 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/question-5.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-010 question:1 | 信号의 뜻은? | 新興エコタウン | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:新興エコタウン | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/question-1.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-010 question:2 | 届く의 뜻은? | 得てして | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:得てして | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/question-2.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-010 question:3 | ボタンを押す___、画面が変わります。 | ボタンを押す 画面が変わります | 1.000 | TRANSCRIPTION_TEXT_MISMATCH:ボタンを押す 画面が変わります | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/question-3.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-010 question:5 | '버튼을 누르면 화면이 바뀝니다'를 배열하세요. | ボタンを押すと画面が変わります。る ベヨルハセヨ | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:ボタンを押すと画面が変わります。る ベヨルハセヨ | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/question-5.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-011 question:1 | 厚い의 뜻은? | ほ いえすん | 0.200 | TRANSCRIPTION_TEXT_MISMATCH:ほ いえすん | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/question-1.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-011 question:2 | 柔らかい의 뜻은? | やわらかい | 0.500 | TRANSCRIPTION_TEXT_MISMATCH:やわらかい | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/question-2.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-011 question:4 | この紙の柔らか___を確認します。 (이 종이의 부드러운 정도를 확인합니다.) | この詩の柔らかを確認します。イ チョンゲ ブドロウン ジョンドゥルル ホギナムニダ。 | 0.369 | TRANSCRIPTION_TEXT_MISMATCH:この詩の柔らかを確認します。イ チョンゲ ブドロウン ジョンドゥルル ホギナムニダ。 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/question-4.mp3) |

## NO_STT_TRANSCRIPT

- None

## Decision

Broad/full N4 rollout remains blocked. This triage only narrows the
remaining 62 pending review-signal audio QA rows
into review lanes and does not lower the verdict gate by itself.
