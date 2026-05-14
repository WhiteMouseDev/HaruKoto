# N4 Audio QA Bucket Review Batch

> Status: FOCUSED REVIEW BATCH - no verdicts applied
> Boundary: listening/inspection aid only; does not replace native-speaker review

ASSUMPTION: This batch narrows the next review pass to the selected STT
reconciliation bucket(s). It does not set `PASS`, `FLAG`, `FAIL`, or
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
| Selected review items | 40 |
| Selected buckets | MIXED_PROMPT_STT_UNRELIABLE |

## Selected Bucket Counts

| Bucket | Count |
|---|---:|
| MIXED_PROMPT_STT_UNRELIABLE | 40 |

## CSV Apply Boundary

The companion CSV leaves `new_verdict` and `new_notes` blank. Fill those
columns only after direct listening or an explicitly delegated review step.
Blank rows are ignored by `scripts/apply_n4_audio_qa_verdicts.py`.

## Review Items

| Bucket | Target | Source text | STT transcript | Similarity | Recommended action | Audio | Packet |
|---|---|---|---|---:|---|---|---|
| MIXED_PROMPT_STT_UNRELIABLE | HN4-001 question:1 | 規則의 뜻은? | 機序、イエッスン | 0.000 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/question-1.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-001 question:2 | 注意의 뜻은? | ジュリー、イェー | 0.000 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/question-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-001 question:4 | 規則を確認___. (규칙을 확인하세요.) | 基礎を確認 キジクルファキナセヨ | 0.214 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/question-4.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-001 question:5 | '이름을 쓰세요'를 올바른 순서로 배열하세요. | 名前を쓰세요を正しい順序で配列してください。 | 0.154 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/question-5.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-002 question:1 | 心配의 뜻은? | しんぺいげんつ | 0.000 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/question-1.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-002 question:2 | 相談의 뜻은? | シャンダンエー | 0.000 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/question-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-002 question:3 | 早く寝___。 (일찍 자는 편이 좋습니다.) | たやこ へん あら イルチッ ジャヌン ピョニ チョッスムニダ | 0.000 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/question-3.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-003 question:1 | 台風의 뜻은? | タイフン | 0.000 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/question-1.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-003 question:2 | 間に合う의 뜻은? | カニアウエイト | 0.286 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/question-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-004 question:1 | 足りる의 뜻은? | たりとえぬ | 0.182 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/question-1.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-004 question:2 | 予定의 뜻은? | ゆでやしん | 0.000 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/question-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-004 question:3 | 走る___。 (달릴 수밖에 없습니다.) | 走るかい タリル スバッケ オプスムニダ | 0.143 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/question-3.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-004 question:5 | '역까지 달릴 수밖에 없습니다'를 배열하세요. | よっかぢ たっりるしゅばっけ おぷすんにだ を はいれつはぜよ | 0.000 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/question-5.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-005 question:1 | 翻訳의 뜻은? | ファンヤクエトス | 0.000 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/question-1.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-005 question:2 | 申し込む의 뜻은? | 申し込む | 0.727 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/question-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-005 question:3 | 漢字を調べ___。 (한자를 찾아볼 수 있습니다.) | 漢字を調べ、赤字ら、한자를 찾아볼 수 있습니다。 | 0.914 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/question-3.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-006 question:1 | 深い의 뜻은? | カメヤギ | 0.000 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/question-1.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-006 question:2 | 正しい의 뜻은? | 正しい | 0.667 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/question-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-006 question:3 | 湖の深___を確認します。 (호수의 깊이를 확인합니다.) | 国の金を確認します。法成企ビルを確認します。 | 0.350 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/question-3.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-006 question:5 | '호수의 깊이를 확인했습니다'를 배열하세요. | ホスエエギピルル確認しましたを配列はせよ | 0.000 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/question-5.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-007 question:1 | 参加する의 뜻은? | ジャンカするエポ | 0.267 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/question-1.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-007 question:2 | 集める의 뜻은? | カツメルシン | 0.333 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/question-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-007 question:3 | イベントに参加___と思っています。 | イベントに参加 と思っています。 | 1.000 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/question-3.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-007 question:4 | 案内を送___と思っています。 | 案内を奏なちと思っています。 | 0.833 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/question-4.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-007 question:5 | '행사에 참가하려고 생각하고 있습니다'를 배열하세요. | 弊社に参加しようと 考えていますを 手配ください | 0.000 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/question-5.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-008 question:1 | 理由의 뜻은? | ディユーイェスン | 0.000 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/question-1.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-008 question:2 | 返事의 뜻은? | ファンシー | 0.000 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/question-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-008 question:4 | 理由があった___か。 (이유가 있었던 건가요?) | 理由があった。なーなか。理由があったんがよ？ | 0.400 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/question-4.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-008 question:5 | '회의가 길었던 거예요'를 배열하세요. | フェイが長かったんですよを配列세요。 | 0.125 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/question-5.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-009 question:1 | 面接의 뜻은? | 面接 | 0.571 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/question-1.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-009 question:2 | 準備의 뜻은? | 準備役員 | 0.444 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/question-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-009 question:3 | 面接___、練習しています。 (면접을 위해 연습하고 있습니다.) | 面接、アクタ、練習しています。 面接、ウィヘ、練習、ハコイスミダ。 | 0.383 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/question-3.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-009 question:5 | '면접을 위해 준비하고 있습니다'를 배열하세요. | 面接のために準備していますを配列 | 0.000 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/question-5.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-010 question:1 | 信号의 뜻은? | 新興エコタウン | 0.000 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/question-1.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-010 question:2 | 届く의 뜻은? | 得てして | 0.000 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/question-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-010 question:3 | ボタンを押す___、画面が変わります。 | ボタンを押す 画面が変わります | 1.000 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/question-3.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-010 question:5 | '버튼을 누르면 화면이 바뀝니다'를 배열하세요. | ボタンを押すと画面が変わります。る ベヨルハセヨ | 0.000 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/question-5.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-011 question:1 | 厚い의 뜻은? | ほ いえすん | 0.200 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/question-1.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch03-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-011 question:2 | 柔らかい의 뜻은? | やわらかい | 0.500 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/question-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch03-2026-05-13.md` |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-011 question:4 | この紙の柔らか___を確認します。 (이 종이의 부드러운 정도를 확인합니다.) | この詩の柔らかを確認します。イ チョンゲ ブドロウン ジョンドゥルル ホギナムニダ。 | 0.369 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/question-4.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch03-2026-05-13.md` |

## Decision

Use this focused batch before lower-risk STT lanes. Broad/full N4 rollout
remains blocked until packet verdicts contain no `PENDING`, `FLAG`, `FAIL`,
or invalid values.
