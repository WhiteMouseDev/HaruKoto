# N4 Audio QA Delegated Pending Clearance

> Status: MIXED-PROMPT PASS CSV GENERATED
> Boundary: delegated AI-assisted verdicts only; not native-speaker approval

ASSUMPTION: A `MIXED_PROMPT_STT_UNRELIABLE` row has Japanese/Korean,
cloze blanks, or Korean arrangement instructions that make single-language
STT mismatch weak evidence. Rows with `HIGH_SILENCE_RATIO` machine warnings
or script-line near matches are intentionally held.

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
| Pending review-signal items evaluated | 62 |
| Delegated PASS rows in CSV | 40 |
| Held rows left pending | 22 |

## Held Bucket Counts

| Bucket | Count |
|---|---:|
| NEAR_JAPANESE_MATCH | 11 |
| P0_MACHINE_WARNING | 11 |

## CSV Apply Contract

The companion CSV is compatible with
`scripts/apply_n4_audio_qa_verdicts.py --csv-input`. Only rows that meet
the mixed-prompt criteria receive `new_verdict=PASS`; held rows keep blank
`new_verdict` and `new_notes` so the apply script ignores them.

## Delegated PASS Rows

| Target | Bucket | Source text | STT transcript | Similarity | Decision | Audio | Packet |
|---|---|---|---|---:|---|---|---|
| HN4-001 question:1 | MIXED_PROMPT_STT_UNRELIABLE | 規則의 뜻은? | 機序、イエッスン | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/question-1.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| HN4-001 question:2 | MIXED_PROMPT_STT_UNRELIABLE | 注意의 뜻은? | ジュリー、イェー | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/question-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| HN4-001 question:4 | MIXED_PROMPT_STT_UNRELIABLE | 規則を確認___. (규칙을 확인하세요.) | 基礎を確認 キジクルファキナセヨ | 0.214 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/question-4.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| HN4-001 question:5 | MIXED_PROMPT_STT_UNRELIABLE | '이름을 쓰세요'를 올바른 순서로 배열하세요. | 名前を쓰세요を正しい順序で配列してください。 | 0.154 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/question-5.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| HN4-002 question:1 | MIXED_PROMPT_STT_UNRELIABLE | 心配의 뜻은? | しんぺいげんつ | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/question-1.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| HN4-002 question:2 | MIXED_PROMPT_STT_UNRELIABLE | 相談의 뜻은? | シャンダンエー | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/question-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| HN4-002 question:3 | MIXED_PROMPT_STT_UNRELIABLE | 早く寝___。 (일찍 자는 편이 좋습니다.) | たやこ へん あら イルチッ ジャヌン ピョニ チョッスムニダ | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/question-3.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| HN4-003 question:1 | MIXED_PROMPT_STT_UNRELIABLE | 台風의 뜻은? | タイフン | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/question-1.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| HN4-003 question:2 | MIXED_PROMPT_STT_UNRELIABLE | 間に合う의 뜻은? | カニアウエイト | 0.286 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/question-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| HN4-004 question:1 | MIXED_PROMPT_STT_UNRELIABLE | 足りる의 뜻은? | たりとえぬ | 0.182 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/question-1.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| HN4-004 question:2 | MIXED_PROMPT_STT_UNRELIABLE | 予定의 뜻은? | ゆでやしん | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/question-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| HN4-004 question:3 | MIXED_PROMPT_STT_UNRELIABLE | 走る___。 (달릴 수밖에 없습니다.) | 走るかい タリル スバッケ オプスムニダ | 0.143 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/question-3.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| HN4-004 question:5 | MIXED_PROMPT_STT_UNRELIABLE | '역까지 달릴 수밖에 없습니다'를 배열하세요. | よっかぢ たっりるしゅばっけ おぷすんにだ を はいれつはぜよ | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/question-5.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| HN4-005 question:1 | MIXED_PROMPT_STT_UNRELIABLE | 翻訳의 뜻은? | ファンヤクエトス | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/question-1.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| HN4-005 question:2 | MIXED_PROMPT_STT_UNRELIABLE | 申し込む의 뜻은? | 申し込む | 0.727 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/question-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| HN4-005 question:3 | MIXED_PROMPT_STT_UNRELIABLE | 漢字を調べ___。 (한자를 찾아볼 수 있습니다.) | 漢字を調べ、赤字ら、한자를 찾아볼 수 있습니다。 | 0.914 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/question-3.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| HN4-006 question:1 | MIXED_PROMPT_STT_UNRELIABLE | 深い의 뜻은? | カメヤギ | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/question-1.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-006 question:2 | MIXED_PROMPT_STT_UNRELIABLE | 正しい의 뜻은? | 正しい | 0.667 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/question-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-006 question:3 | MIXED_PROMPT_STT_UNRELIABLE | 川の深___を確認します。 (강의 깊이를 확인합니다.) | 国の金を確認します。法成企ビルを確認します。 | 0.359 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/question-3-regen-20260518T021500Z.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-006 question:5 | MIXED_PROMPT_STT_UNRELIABLE | '강의 깊이를 확인했습니다'를 배열하세요. | ホスエエギピルル確認しましたを配列はせよ | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/question-5-regen-20260518T021500Z.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-007 question:1 | MIXED_PROMPT_STT_UNRELIABLE | 参加する의 뜻은? | ジャンカするエポ | 0.267 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/question-1.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-007 question:2 | MIXED_PROMPT_STT_UNRELIABLE | 集める의 뜻은? | カツメルシン | 0.333 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/question-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-007 question:3 | MIXED_PROMPT_STT_UNRELIABLE | イベントに参加___と思っています。 | イベントに参加 と思っています。 | 1.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/question-3.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-007 question:4 | MIXED_PROMPT_STT_UNRELIABLE | 案内を送___と思っています。 | 案内を奏なちと思っています。 | 0.833 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/question-4.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-007 question:5 | MIXED_PROMPT_STT_UNRELIABLE | '행사에 참가하려고 생각하고 있습니다'를 배열하세요. | 弊社に参加しようと 考えていますを 手配ください | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/question-5.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-008 question:1 | MIXED_PROMPT_STT_UNRELIABLE | 理由의 뜻은? | ディユーイェスン | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/question-1.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-008 question:2 | MIXED_PROMPT_STT_UNRELIABLE | 返事의 뜻은? | ファンシー | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/question-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-008 question:4 | MIXED_PROMPT_STT_UNRELIABLE | 理由があった___か。 (이유가 있었던 건가요?) | 理由があった。なーなか。理由があったんがよ？ | 0.400 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/question-4.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-008 question:5 | MIXED_PROMPT_STT_UNRELIABLE | '회의가 길었던 거예요'를 배열하세요. | フェイが長かったんですよを配列세요。 | 0.125 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/question-5.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-009 question:1 | MIXED_PROMPT_STT_UNRELIABLE | 面接의 뜻은? | 面接 | 0.571 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/question-1.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-009 question:2 | MIXED_PROMPT_STT_UNRELIABLE | 準備의 뜻은? | 準備役員 | 0.444 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/question-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-009 question:3 | MIXED_PROMPT_STT_UNRELIABLE | 面接___、練習しています。 (면접을 위해 연습하고 있습니다.) | 面接、アクタ、練習しています。 面接、ウィヘ、練習、ハコイスミダ。 | 0.383 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/question-3.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-009 question:5 | MIXED_PROMPT_STT_UNRELIABLE | '면접을 위해 준비하고 있습니다'를 배열하세요. | 面接のために準備していますを配列 | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/question-5.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-010 question:1 | MIXED_PROMPT_STT_UNRELIABLE | 信号의 뜻은? | 新興エコタウン | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/question-1.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-010 question:2 | MIXED_PROMPT_STT_UNRELIABLE | 届く의 뜻은? | 得てして | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/question-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-010 question:3 | MIXED_PROMPT_STT_UNRELIABLE | ボタンを押す___、画面が変わります。 | ボタンを押す 画面が変わります | 1.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/question-3.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-010 question:5 | MIXED_PROMPT_STT_UNRELIABLE | '버튼을 누르면 화면이 바뀝니다'를 배열하세요. | ボタンを押すと画面が変わります。る ベヨルハセヨ | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/question-5.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-011 question:1 | MIXED_PROMPT_STT_UNRELIABLE | 厚い의 뜻은? | ほ いえすん | 0.200 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/question-1.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch03-2026-05-13.md` |
| HN4-011 question:2 | MIXED_PROMPT_STT_UNRELIABLE | 柔らかい의 뜻은? | やわらかい | 0.500 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/question-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch03-2026-05-13.md` |
| HN4-011 question:4 | MIXED_PROMPT_STT_UNRELIABLE | この紙の柔らか___を確認します。 (이 종이의 부드러운 정도를 확인합니다.) | この詩の柔らかを確認します。イ チョンゲ ブドロウン ジョンドゥルル ホギナムニダ。 | 0.369 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/question-4.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch03-2026-05-13.md` |

## Held Rows

These rows remain pending because they require listening or regeneration
judgment beyond the mixed-prompt STT false-positive rule.

| Target | Bucket | Source text | STT transcript | Similarity | Decision | Audio | Packet |
|---|---|---|---|---:|---|---|---|
| HN4-001 question:3 | P0_MACHINE_WARNING | 名前を書き___. (이름을 쓰세요.) | 名前を書き イムルスセヨ | 0.455 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/question-3.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| HN4-002 question:4 | P0_MACHINE_WARNING | 医者に相談___。 (의사와 상담하는 편이 좋습니다.) | 医者に相談 医者と相談する方がいいです | 0.270 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/question-4.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| HN4-003 question:3 | P0_MACHINE_WARNING | 電車が遅れる___。 (전철이 늦을지도 모릅니다.) | 転写が遅れる ちょんちょり ぬじるちど もるにだ | 0.211 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/question-3.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| HN4-003 question:4 | P0_MACHINE_WARNING | 間に合わない___。 (시간에 맞지 못할지도 모릅니다.) | 間に合わない。 時間に間に合わないかもしれません。 | 0.286 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/question-4.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| HN4-004 question:4 | P0_MACHINE_WARNING | 電車に乗る___。 (전철을 탈 수밖에 없습니다.) | 電車に乗るは ちょんちょろをたるすわけありません。 | 0.256 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/question-4.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| HN4-005 question:4 | P0_MACHINE_WARNING | 文を翻訳___。 (문장을 번역할 수 있습니다.) | 文語翻訳 文章を翻訳することができます | 0.242 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/question-4.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| HN4-006 question:4 | P0_MACHINE_WARNING | 線の太___を見ます。 (선의 굵기를 봅니다.) | 洗脳体を見ます。そうね、クッキリを見ます。 | 0.242 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/question-4.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-008 question:3 | P0_MACHINE_WARNING | 会議が長かった___。 (회의가 길었던 거예요.) | 会議がなかった フェイが消ろとんごよ | 0.364 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/question-3.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-009 question:4 | P0_MACHINE_WARNING | 就職する___、準備します。 (취직하기 위해 준비합니다.) | 給食する 準備します | 0.483 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/question-4.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-010 question:4 | P0_MACHINE_WARNING | 信号が青になる___、車が進みます。 | 信号が青になる 車が進みます | 1.000 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/question-4.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-011 question:3 | P0_MACHINE_WARNING | 紙の厚___を比べます。 (종이의 두께를 비교합니다.) | カビの音 お比べます。 ジョンギエたける比較します。 | 0.244 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/question-3.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch03-2026-05-13.md` |
| HN4-002 script:0 | NEAR_JAPANESE_MATCH | 少し頭が痛いです。 | 少し頭が痛い | 0.857 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/script-line-0.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| HN4-002 script:2 | NEAR_JAPANESE_MATCH | 医者に相談したほうがいいですか。 | 医者に相談した方がいいです。 | 0.966 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/script-line-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| HN4-004 script:0 | NEAR_JAPANESE_MATCH | 時間が足りません。駅まで走るしかありません。 | 時間が足りません。江木まで走るしかありません。 | 0.930 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/script-line-0.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| HN4-004 script:1 | NEAR_JAPANESE_MATCH | 次の予定がありますからね。 | 次の予定がありますから | 0.957 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/script-line-1.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| HN4-005 script:1 | NEAR_JAPANESE_MATCH | 文も翻訳できますか。 | 文も翻訳できます。 | 0.941 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/script-line-1.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| HN4-005 script:2 | NEAR_JAPANESE_MATCH | はい。授業の予約にも申し込めます。 | はい、授業の予約にも申し込みます。 | 0.933 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/script-line-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| HN4-006 script:1 | NEAR_JAPANESE_MATCH | この川の浅さも分かりますか。 | この歯の舞さも分かりますか | 0.846 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/script-line-1.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-008 script:2 | NEAR_JAPANESE_MATCH | 会議が長かったのです。 | 会議が長かった | 0.824 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/script-line-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-011 script:0 | NEAR_JAPANESE_MATCH | ノートを選ぶ前に、紙の厚さを比べています。 | ノートを選ぶ前に コムの厚さを比べています | 0.923 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/script-line-0.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch03-2026-05-13.md` |
| HN4-011 script:2 | NEAR_JAPANESE_MATCH | はい。この紙の柔らかさも確認します。 | はい、このシビの柔らかさも確認します。 | 0.909 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/script-line-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch03-2026-05-13.md` |
| HN4-011 script:3 | NEAR_JAPANESE_MATCH | 厚さと柔らかさを比べて選びましょう。 | 硬さ、柔らかさを比べて選びましょう。 | 0.909 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/script-line-3.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch03-2026-05-13.md` |

## Decision

Apply the CSV to clear mixed-prompt STT false positives first.
Broad/full N4 rollout remains blocked until the held rows are reviewed or regenerated.
