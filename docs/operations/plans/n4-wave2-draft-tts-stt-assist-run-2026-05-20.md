# N4 TTS Audio QA Machine Report

> Status: REVIEW
> Scope: generated lesson script-line and question-prompt TTS targets
> Boundary: machine/STT evidence only; human audio verdicts remain required

## Command

```bash
uv run python scripts/audit_n4_pilot_tts_audio_quality.py --level N4 --include-unpublished --lesson-no 12 --lesson-no 13 --lesson-no 14 --lesson-no 15 --lesson-no 16 --transcribe --markdown-output ../../docs/operations/plans/n4-wave2-draft-tts-stt-assist-run-2026-05-20.md
```

## Summary

| Metric | Result |
|---|---:|
| Total targets | 45 |
| Machine pass | 45 |
| Blocked targets | 0 |
| Warning count | 30 |
| Transcribed targets | 45 |
| STT exact matches | 16 |
| STT mismatches | 29 |
| STT errors | 0 |
| Duration min | 1.489s |
| Duration max | 6.4s |
| Duration average | 3.439s |
| Total audio duration | 154.75s |

## Provider Models

- `elevenlabs/eleven_multilingual_v2`: 45

## Blockers

- None

## Review-Priority Warnings

- HN4-012 question:1: TRANSCRIPTION_TEXT_MISMATCH:丁珏孫
- HN4-012 question:2: TRANSCRIPTION_TEXT_MISMATCH:地震ゲイツン
- HN4-012 question:3: TRANSCRIPTION_TEXT_MISMATCH:THOUGHT: The user wants a precise Japanese transcription of the audio. I need to listen carefully and type out the word...
- HN4-012 question:4: TRANSCRIPTION_TEXT_MISMATCH:試験の前でもなわあじゅうです。
- HN4-012 question:5: TRANSCRIPTION_TEXT_MISMATCH:イスオプン ソルミョンイ チョンジュンハゴ アンシムイムニダルル ペヨルハセヨ
- HN4-013 script:1: TRANSCRIPTION_TEXT_MISMATCH:わからなければ、ふふで聞いてみましょう。
- HN4-013 script:2: TRANSCRIPTION_TEXT_MISMATCH:案内のおせも読んでみます。
- HN4-013 question:1: TRANSCRIPTION_TEXT_MISMATCH:ゆうやうへいとん
- HN4-013 question:2: TRANSCRIPTION_TEXT_MISMATCH:とうふワイン
- HN4-013 question:3: TRANSCRIPTION_TEXT_MISMATCH:予約の時間を調べて時間もにます。
- HN4-013 question:4: TRANSCRIPTION_TEXT_MISMATCH:大丈夫なら、見なざります
- HN4-013 question:5: TRANSCRIPTION_TEXT_MISMATCH:予約時間を一度探してみます。るを配列하세요。
- HN4-014 question:1: TRANSCRIPTION_TEXT_MISMATCH:準備万端
- HN4-014 question:2: TRANSCRIPTION_TEXT_MISMATCH:カラツケる
- HN4-014 question:3: TRANSCRIPTION_TEXT_MISMATCH:資料を準備して、しばたまあす。
- HN4-014 question:4: TRANSCRIPTION_TEXT_MISMATCH:予約の時間を手おくと安心です。
- HN4-014 question:5: TRANSCRIPTION_TEXT_MISMATCH:ホエーイジョンに準備しておきますを部屋はせよ
- HN4-015 script:1: TRANSCRIPTION_TEXT_MISMATCH:それは新米です。
- HN4-015 question:1: TRANSCRIPTION_TEXT_MISMATCH:おつかりえん
- HN4-015 question:2: TRANSCRIPTION_TEXT_MISMATCH:忘れルエ
- HN4-015 question:3: TRANSCRIPTION_TEXT_MISMATCH:予約を忘れてたまちました。
- HN4-015 question:4: HIGH_SILENCE_RATIO:0.4203, TRANSCRIPTION_TEXT_MISMATCH:スマートフォンをてしまいました
- HN4-015 question:5: TRANSCRIPTION_TEXT_MISMATCH:やあくを忘れましたを配列してください。
- HN4-016 script:3: TRANSCRIPTION_TEXT_MISMATCH:ひとりで難しい時はクラスに参加します。
- HN4-016 question:1: TRANSCRIPTION_TEXT_MISMATCH:ゾケルスン
- HN4-016 question:2: TRANSCRIPTION_TEXT_MISMATCH:レンシーエット
- HN4-016 question:3: TRANSCRIPTION_TEXT_MISMATCH:日本語の練習を毎日 もらっています。
- HN4-016 question:4: TRANSCRIPTION_TEXT_MISMATCH:運動も少しずつ続けるです。
- HN4-016 question:5: TRANSCRIPTION_TEXT_MISMATCH:「日本語の練習を続けています」を配列してください。

## STT Mismatches

| Target | Source text | STT transcript | Strict blocker mode | Audio |
|---|---|---|---|---|
| HN4-012 question:1 | 丁寧의 뜻은? | 丁珏孫 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/question-1.mp3 |
| HN4-012 question:2 | 自信의 뜻은? | 地震ゲイツン | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/question-2.mp3 |
| HN4-012 question:3 | 説明が丁寧だ___、練習も多いです。 | THOUGHT: The user wants a precise Japanese transcription of the audio. I need to listen carefully and type out the words as they are spoken. Audio: "説明が丁寧だ。あら、練習も多いです。" My task is straightforward: transcribe the spoken Japanese into text.説明が丁寧だ。あら、練習も多いです。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/question-3.mp3 |
| HN4-012 question:4 | 試験の前でも___ですね。 | 試験の前でもなわあじゅうです。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/question-4.mp3 |
| HN4-012 question:5 | '이 수업은 설명이 정중하고 안심입니다'를 배열하세요. | イスオプン ソルミョンイ チョンジュンハゴ アンシムイムニダルル ペヨルハセヨ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/question-5.mp3 |
| HN4-013 script:1 | 分からなければ、受付で聞いてみましょう。 | わからなければ、ふふで聞いてみましょう。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/script-line-1.mp3 |
| HN4-013 script:2 | 案内の紙も読んでみます。 | 案内のおせも読んでみます。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/script-line-2.mp3 |
| HN4-013 question:1 | 予約의 뜻은? | ゆうやうへいとん | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/question-1.mp3 |
| HN4-013 question:2 | 受付의 뜻은? | とうふワイン | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/question-2.mp3 |
| HN4-013 question:3 | 予約の時間を調べて___ます。 | 予約の時間を調べて時間もにます。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/question-3.mp3 |
| HN4-013 question:4 | 大丈夫なら、___みます。 | 大丈夫なら、見なざります | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/question-4.mp3 |
| HN4-013 question:5 | '예약 시간을 한번 찾아보겠습니다'를 배열하세요. | 予約時間を一度探してみます。るを配列하세요。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/question-5.mp3 |
| HN4-014 question:1 | 準備의 뜻은? | 準備万端 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/question-1.mp3 |
| HN4-014 question:2 | 片付ける의 뜻은? | カラツケる | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/question-2.mp3 |
| HN4-014 question:3 | 資料を準備して___ます。 | 資料を準備して、しばたまあす。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/question-3.mp3 |
| HN4-014 question:4 | 予約の時間を___ておくと安心です。 | 予約の時間を手おくと安心です。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/question-4.mp3 |
| HN4-014 question:5 | '회의 전에 준비해 두겠습니다'를 배열하세요. | ホエーイジョンに準備しておきますを部屋はせよ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/question-5.mp3 |
| HN4-015 script:1 | それは心配ですね。 | それは新米です。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/script-line-1.mp3 |
| HN4-015 question:1 | うっかり의 뜻은? | おつかりえん | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/question-1.mp3 |
| HN4-015 question:2 | 忘れる의 뜻은? | 忘れルエ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/question-2.mp3 |
| HN4-015 question:3 | 予約を忘れて___ました。 | 予約を忘れてたまちました。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/question-3.mp3 |
| HN4-015 question:4 | スマートフォンを___てしまいました。 | スマートフォンをてしまいました | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/question-4.mp3 |
| HN4-015 question:5 | '예약을 잊어버렸습니다'를 배열하세요. | やあくを忘れましたを配列してください。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/question-5.mp3 |
| HN4-016 script:3 | 一人で難しい時は、クラスに参加します。 | ひとりで難しい時はクラスに参加します。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/script-line-3.mp3 |
| HN4-016 question:1 | 続ける의 뜻은? | ゾケルスン | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/question-1.mp3 |
| HN4-016 question:2 | 練習의 뜻은? | レンシーエット | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/question-2.mp3 |
| HN4-016 question:3 | 日本語の練習を毎日___ています。 | 日本語の練習を毎日 もらっています。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/question-3.mp3 |
| HN4-016 question:4 | 運動も少しずつ続ける___です。 | 運動も少しずつ続けるです。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/question-4.mp3 |
| HN4-016 question:5 | '일본어 연습을 계속하고 있습니다'를 배열하세요. | 「日本語の練習を続けています」を配列してください。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/question-5.mp3 |

## Decision

REVIEW: inspect STT mismatches before recording final audio verdicts.
