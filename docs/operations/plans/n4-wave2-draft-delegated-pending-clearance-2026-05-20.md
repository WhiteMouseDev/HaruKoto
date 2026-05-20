# N4 Audio QA Delegated Pending Clearance

> Status: MIXED-PROMPT PASS CSV GENERATED
> Boundary: delegated AI-assisted verdicts only; not native-speaker approval

ASSUMPTION: A `MIXED_PROMPT_STT_UNRELIABLE` row has Japanese/Korean,
cloze blanks, or Korean arrangement instructions that make single-language
STT mismatch weak evidence. Rows with `HIGH_SILENCE_RATIO` machine warnings
or script-line near matches are intentionally held.

## Sources

- Packet: `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md`
- Quality signal report: `docs/operations/plans/n4-wave2-draft-tts-machine-report-2026-05-20.md`
- Quality signal report: `docs/operations/plans/n4-wave2-draft-tts-stt-assist-run-2026-05-20.md`

## Summary

| Metric | Count |
|---|---:|
| Total review items | 45 |
| Pending review-signal items evaluated | 29 |
| Delegated PASS rows in CSV | 24 |
| Held rows left pending | 5 |

## Held Bucket Counts

| Bucket | Count |
|---|---:|
| LEXICAL_RISK | 1 |
| NEAR_JAPANESE_MATCH | 3 |
| P0_MACHINE_WARNING | 1 |

## CSV Apply Contract

The companion CSV is compatible with
`scripts/apply_n4_audio_qa_verdicts.py --csv-input`. Only rows that meet
the mixed-prompt criteria receive `new_verdict=PASS`; held rows keep blank
`new_verdict` and `new_notes` so the apply script ignores them.

## Delegated PASS Rows

| Target | Bucket | Source text | STT transcript | Similarity | Decision | Audio | Packet |
|---|---|---|---|---:|---|---|---|
| HN4-012 question:1 | MIXED_PROMPT_STT_UNRELIABLE | 丁寧의 뜻은? | 丁珏孫 | 0.250 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/question-1.mp3) | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-012 question:2 | MIXED_PROMPT_STT_UNRELIABLE | 自信의 뜻은? | 地震ゲイツン | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/question-2.mp3) | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-012 question:3 | MIXED_PROMPT_STT_UNRELIABLE | 説明が丁寧だ___、練習も多いです。 | [malformed STT response] 説明が丁寧だ。あら、練習も多いです。 | 0.542 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/question-3.mp3) | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-012 question:4 | MIXED_PROMPT_STT_UNRELIABLE | 試験の前でも___ですね。 | 試験の前でもなわあじゅうです。 | 0.696 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/question-4.mp3) | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-012 question:5 | MIXED_PROMPT_STT_UNRELIABLE | '이 수업은 설명이 정중하고 안심입니다'를 배열하세요. | イスオプン ソルミョンイ チョンジュンハゴ アンシムイムニダルル ペヨルハセヨ | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/question-5.mp3) | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-013 question:1 | MIXED_PROMPT_STT_UNRELIABLE | 予約의 뜻은? | ゆうやうへいとん | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/question-1.mp3) | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-013 question:2 | MIXED_PROMPT_STT_UNRELIABLE | 受付의 뜻은? | とうふワイン | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/question-2.mp3) | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-013 question:3 | MIXED_PROMPT_STT_UNRELIABLE | 予約の時間を調べて___ます。 | 予約の時間を調べて時間もにます。 | 0.828 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/question-3.mp3) | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-013 question:4 | MIXED_PROMPT_STT_UNRELIABLE | 大丈夫なら、___みます。 | 大丈夫なら、見なざります | 0.737 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/question-4.mp3) | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-013 question:5 | MIXED_PROMPT_STT_UNRELIABLE | '예약 시간을 한번 찾아보겠습니다'를 배열하세요. | 予約時間を一度探してみます。るを配列하세요。 | 0.146 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/question-5.mp3) | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-014 question:1 | MIXED_PROMPT_STT_UNRELIABLE | 準備의 뜻은? | 準備万端 | 0.444 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/question-1.mp3) | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-014 question:2 | MIXED_PROMPT_STT_UNRELIABLE | 片付ける의 뜻은? | カラツケる | 0.333 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/question-2.mp3) | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-014 question:3 | MIXED_PROMPT_STT_UNRELIABLE | 資料を準備して___ます。 | 資料を準備して、しばたまあす。 | 0.818 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/question-3.mp3) | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-014 question:4 | MIXED_PROMPT_STT_UNRELIABLE | 予約の時間を___ておくと安心です。 | 予約の時間を手おくと安心です。 | 0.933 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/question-4.mp3) | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-014 question:5 | MIXED_PROMPT_STT_UNRELIABLE | '회의 전에 준비해 두겠습니다'를 배열하세요. | ホエーイジョンに準備しておきますを部屋はせよ | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/question-5.mp3) | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-015 question:1 | MIXED_PROMPT_STT_UNRELIABLE | うっかり의 뜻은? | おつかりえん | 0.308 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/question-1.mp3) | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-015 question:2 | MIXED_PROMPT_STT_UNRELIABLE | 忘れる의 뜻은? | 忘れルエ | 0.600 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/question-2.mp3) | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-015 question:3 | MIXED_PROMPT_STT_UNRELIABLE | 予約を忘れて___ました。 | 予約を忘れてたまちました。 | 0.857 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/question-3.mp3) | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-015 question:5 | MIXED_PROMPT_STT_UNRELIABLE | '예약을 잊어버렸습니다'를 배열하세요. | やあくを忘れましたを配列してください。 | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/question-5.mp3) | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-016 question:1 | MIXED_PROMPT_STT_UNRELIABLE | 続ける의 뜻은? | ゾケルスン | 0.364 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/question-1.mp3) | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-016 question:2 | MIXED_PROMPT_STT_UNRELIABLE | 練習의 뜻은? | レンシーエット | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/question-2.mp3) | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-016 question:3 | MIXED_PROMPT_STT_UNRELIABLE | 日本語の練習を毎日___ています。 | 日本語の練習を毎日 もらっています。 | 0.897 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/question-3.mp3) | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-016 question:4 | MIXED_PROMPT_STT_UNRELIABLE | 運動も少しずつ続ける___です。 | 運動も少しずつ続けるです。 | 1.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/question-4.mp3) | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-016 question:5 | MIXED_PROMPT_STT_UNRELIABLE | '일본어 연습을 계속하고 있습니다'를 배열하세요. | 「日本語の練習を続けています」を配列してください。 | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/question-5.mp3) | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |

## Held Rows

These rows remain pending because they require listening or regeneration
judgment beyond the mixed-prompt STT false-positive rule.

| Target | Bucket | Source text | STT transcript | Similarity | Decision | Audio | Packet |
|---|---|---|---|---:|---|---|---|
| HN4-015 question:4 | P0_MACHINE_WARNING | スマートフォンを___てしまいました。 | スマートフォンをてしまいました | 1.000 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/question-4.mp3) | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-015 script:1 | LEXICAL_RISK | それは心配ですね。 | それは新米です。 | 0.667 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/script-line-1.mp3) | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-013 script:1 | NEAR_JAPANESE_MATCH | 分からなければ、受付で聞いてみましょう。 | わからなければ、ふふで聞いてみましょう。 | 0.833 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/script-line-1.mp3) | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-013 script:2 | NEAR_JAPANESE_MATCH | 案内の紙も読んでみます。 | 案内のおせも読んでみます。 | 0.870 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/script-line-2.mp3) | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-016 script:3 | NEAR_JAPANESE_MATCH | 一人で難しい時は、クラスに参加します。 | ひとりで難しい時はクラスに参加します。 | 0.865 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/script-line-3.mp3) | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |

## Decision

Apply the CSV to clear mixed-prompt STT false positives first.
Broad/full N4 rollout remains blocked until the held rows are reviewed or regenerated.
