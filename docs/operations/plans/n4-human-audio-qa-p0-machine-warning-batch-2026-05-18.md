# N4 Audio QA High-Risk Listening Batch

> Status: LISTENING BATCH - no verdicts applied
> Boundary: high-risk audio review surface only; does not approve rollout

ASSUMPTION: This batch only separates rows that should be listened to
first. It does not set `PASS`, `FLAG`, `FAIL`, or `WAIVED` on any packet
row, and it does not replace native-speaker review.

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
| Pending review-signal items | 11 |
| High-risk listening batch | 11 |
| P0 machine-warning rows | 11 |
| Lexical-risk rows | 0 |

## Review Sequence

1. Listen to `P0_MACHINE_WARNING` rows first. These rows include machine
   warnings such as silence-ratio signals, so pacing or truncation can hide
   behind an otherwise reachable audio URL.
2. Listen to `LEXICAL_RISK` rows next. These rows have Japanese source/STT
   divergence large enough that wrong-word audio is plausible.
3. Leave `new_verdict` and `new_notes` blank until direct listening or an
   explicitly delegated review step confirms the audio quality.

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

## CSV And HTML Use

The companion CSV is an input worksheet only. The HTML file is a static
listening surface with audio controls. Neither file applies verdicts.

## Decision

Broad/full N4 rollout remains blocked. This batch makes the first listening
slice explicit but does not lower the audio-quality verdict gate.
