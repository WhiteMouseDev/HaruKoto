# N4 Audio QA STT Reconciliation

> Status: TRIAGE ONLY - no verdicts applied
> Boundary: STT mismatch reconciliation only; does not replace listening or native-speaker review

ASSUMPTION: This report helps reduce review ambiguity while preserving
the current verdict gate. It does not set `PASS`, `FLAG`, `FAIL`, or
`WAIVED` on any packet row.

## Sources

- Packet: `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md`
- Quality signal report: `docs/operations/plans/n4-wave2-draft-tts-machine-report-2026-05-20.md`
- Quality signal report: `docs/operations/plans/n4-wave2-draft-tts-stt-assist-run-2026-05-20.md`

## Summary

| Metric | Count |
|---|---:|
| Total review items | 45 |
| Pending review-signal items | 29 |
| P0 machine-warning retained first | 1 |
| P1 STT-only items | 28 |
| Canonical text matches | 0 |
| Near Japanese matches | 3 |
| Mixed/Korean prompt STT-unreliable | 24 |
| Lexical-risk Japanese mismatches | 1 |
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
| P0_MACHINE_WARNING | HN4-015 question:4 | スマートフォンを___てしまいました。 | スマートフォンをてしまいました | 1.000 | HIGH_SILENCE_RATIO:0.4203, TRANSCRIPTION_TEXT_MISMATCH:スマートフォンをてしまいました | listen first; check silence/spacing, intelligibility, and text completeness before setting PASS/FLAG/FAIL | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/question-4.mp3) |

## LEXICAL_RISK

| Bucket | Target | Source text | STT transcript | Similarity | Signals | Recommended action | Audio |
|---|---|---|---|---:|---|---|---|
| LEXICAL_RISK | HN4-015 script:1 | それは心配ですね。 | それは新米です。 | 0.667 | TRANSCRIPTION_TEXT_MISMATCH:それは新米です。 | listen carefully before PASS; prefer FLAG when the source text is not clearly spoken | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/script-line-1.mp3) |

## NEAR_JAPANESE_MATCH

| Bucket | Target | Source text | STT transcript | Similarity | Signals | Recommended action | Audio |
|---|---|---|---|---:|---|---|---|
| NEAR_JAPANESE_MATCH | HN4-013 script:1 | 分からなければ、受付で聞いてみましょう。 | わからなければ、ふふで聞いてみましょう。 | 0.833 | TRANSCRIPTION_TEXT_MISMATCH:わからなければ、ふふで聞いてみましょう。 | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/script-line-1.mp3) |
| NEAR_JAPANESE_MATCH | HN4-013 script:2 | 案内の紙も読んでみます。 | 案内のおせも読んでみます。 | 0.870 | TRANSCRIPTION_TEXT_MISMATCH:案内のおせも読んでみます。 | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/script-line-2.mp3) |
| NEAR_JAPANESE_MATCH | HN4-016 script:3 | 一人で難しい時は、クラスに参加します。 | ひとりで難しい時はクラスに参加します。 | 0.865 | TRANSCRIPTION_TEXT_MISMATCH:ひとりで難しい時はクラスに参加します。 | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/script-line-3.mp3) |

## CANONICAL_MATCH

- None

## MIXED_PROMPT_STT_UNRELIABLE

| Bucket | Target | Source text | STT transcript | Similarity | Signals | Recommended action | Audio |
|---|---|---|---|---:|---|---|---|
| MIXED_PROMPT_STT_UNRELIABLE | HN4-012 question:1 | 丁寧의 뜻은? | 丁珏孫 | 0.250 | TRANSCRIPTION_TEXT_MISMATCH:丁珏孫 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/question-1.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-012 question:2 | 自信의 뜻은? | 地震ゲイツン | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:地震ゲイツン | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/question-2.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-012 question:3 | 説明が丁寧だ___、練習も多いです。 | [malformed STT response] 説明が丁寧だ。あら、練習も多いです。 | 0.542 | TRANSCRIPTION_TEXT_MISMATCH:[malformed STT response] 説明が丁寧だ。あら、練習も多いです。 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/question-3.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-012 question:4 | 試験の前でも___ですね。 | 試験の前でもなわあじゅうです。 | 0.696 | TRANSCRIPTION_TEXT_MISMATCH:試験の前でもなわあじゅうです。 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/question-4.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-012 question:5 | '이 수업은 설명이 정중하고 안심입니다'를 배열하세요. | イスオプン ソルミョンイ チョンジュンハゴ アンシムイムニダルル ペヨルハセヨ | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:イスオプン ソルミョンイ チョンジュンハゴ アンシムイムニダルル ペヨルハセヨ | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/question-5.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-013 question:1 | 予約의 뜻은? | ゆうやうへいとん | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:ゆうやうへいとん | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/question-1.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-013 question:2 | 受付의 뜻은? | とうふワイン | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:とうふワイン | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/question-2.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-013 question:3 | 予約の時間を調べて___ます。 | 予約の時間を調べて時間もにます。 | 0.828 | TRANSCRIPTION_TEXT_MISMATCH:予約の時間を調べて時間もにます。 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/question-3.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-013 question:4 | 大丈夫なら、___みます。 | 大丈夫なら、見なざります | 0.737 | TRANSCRIPTION_TEXT_MISMATCH:大丈夫なら、見なざります | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/question-4.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-013 question:5 | '예약 시간을 한번 찾아보겠습니다'를 배열하세요. | 予約時間を一度探してみます。るを配列하세요。 | 0.146 | TRANSCRIPTION_TEXT_MISMATCH:予約時間を一度探してみます。るを配列하세요。 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/question-5.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-014 question:1 | 準備의 뜻은? | 準備万端 | 0.444 | TRANSCRIPTION_TEXT_MISMATCH:準備万端 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/question-1.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-014 question:2 | 片付ける의 뜻은? | カラツケる | 0.333 | TRANSCRIPTION_TEXT_MISMATCH:カラツケる | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/question-2.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-014 question:3 | 資料を準備して___ます。 | 資料を準備して、しばたまあす。 | 0.818 | TRANSCRIPTION_TEXT_MISMATCH:資料を準備して、しばたまあす。 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/question-3.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-014 question:4 | 予約の時間を___ておくと安心です。 | 予約の時間を手おくと安心です。 | 0.933 | TRANSCRIPTION_TEXT_MISMATCH:予約の時間を手おくと安心です。 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/question-4.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-014 question:5 | '회의 전에 준비해 두겠습니다'를 배열하세요. | ホエーイジョンに準備しておきますを部屋はせよ | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:ホエーイジョンに準備しておきますを部屋はせよ | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/question-5.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-015 question:1 | うっかり의 뜻은? | おつかりえん | 0.308 | TRANSCRIPTION_TEXT_MISMATCH:おつかりえん | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/question-1.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-015 question:2 | 忘れる의 뜻은? | 忘れルエ | 0.600 | TRANSCRIPTION_TEXT_MISMATCH:忘れルエ | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/question-2.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-015 question:3 | 予約を忘れて___ました。 | 予約を忘れてたまちました。 | 0.857 | TRANSCRIPTION_TEXT_MISMATCH:予約を忘れてたまちました。 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/question-3.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-015 question:5 | '예약을 잊어버렸습니다'를 배열하세요. | やあくを忘れましたを配列してください。 | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:やあくを忘れましたを配列してください。 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/question-5.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-016 question:1 | 続ける의 뜻은? | ゾケルスン | 0.364 | TRANSCRIPTION_TEXT_MISMATCH:ゾケルスン | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/question-1.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-016 question:2 | 練習의 뜻은? | レンシーエット | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:レンシーエット | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/question-2.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-016 question:3 | 日本語の練習を毎日___ています。 | 日本語の練習を毎日 もらっています。 | 0.897 | TRANSCRIPTION_TEXT_MISMATCH:日本語の練習を毎日 もらっています。 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/question-3.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-016 question:4 | 運動も少しずつ続ける___です。 | 運動も少しずつ続けるです。 | 1.000 | TRANSCRIPTION_TEXT_MISMATCH:運動も少しずつ続けるです。 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/question-4.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-016 question:5 | '일본어 연습을 계속하고 있습니다'를 배열하세요. | 「日本語の練習を続けています」を配列してください。 | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:「日本語の練習を続けています」を配列してください。 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/question-5.mp3) |

## NO_STT_TRANSCRIPT

- None

## Decision

Broad/full N4 rollout remains blocked. This triage only narrows the
remaining 29 pending review-signal audio QA rows
into review lanes and does not lower the verdict gate by itself.
