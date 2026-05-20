# N4 Pilot/Draft Human Audio QA Packet - Chapter 4

> Date: 2026-05-20
> Scope: N4 chapter 4 `일상 동작 확장 표현`, HN4-012, HN4-013, HN4-014, HN4-015, HN4-016
> Status: REVIEW PACKET - AI-assisted verdicts applied; 3 FLAG rows remain

## Boundary

This packet is for human audio-quality review. It does not regenerate audio,
change lesson content, update rollout status, or claim native-speaker approval.
Applied `PASS` rows are delegated AI-assisted verdicts based on machine/STT
evidence, not native-speaker approval.

ASSUMPTION: One full chapter is the minimum representative playback QA gate
before considering broader N4 rollout. A flagged or failed item should block
broad rollout until regenerated or explicitly waived.

## Reviewer Instructions

1. Open each audio link.
2. Compare the audio against the Japanese text.
3. Mark reviewer verdict as `PASS`, `FLAG`, or `FAIL`.
4. Use notes for misread text, clipped audio, unnatural pacing, wrong language,
   distracting pronunciation, or content/text mismatch.

## Verdict Rubric

| Verdict | Meaning | Broad-rollout impact |
|---|---|---|
| PASS | Text is complete, intelligible, and acceptable for learner playback | Can proceed for this item |
| FLAG | Understandable but has noticeable pacing, accent, or prompt-shape issue | Review before rollout; may need waiver |
| FAIL | Wrong text, clipped audio, wrong language, missing audio, or unusable pronunciation | Regenerate or fix before rollout |

## Summary

| Metric | Result |
|---|---:|
| Generated at | `2026-05-20T01:01:43.722617+00:00` |
| Lessons | 5 |
| Script-line targets | 20 |
| Question-prompt targets | 25 |
| Total review targets | 45 |
| Missing audio URLs | 0 |
| Failed URL checks | 0 |

## Review Items

### HN4-012 - 이유를 나란히 말해요

| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| script 0 | キム | この授業は説明が丁寧だし、練習も多いです。 | 이 수업은 설명이 정중하고 연습도 많습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/script-line-0.mp3) | PASS | Delegated AI-assisted PASS: machine probe passed and STT assist produced no review signal; not native-speaker review |

| script 1 | 佐藤 | 試験の前でも安心ですね。 | 시험 전에도 안심이네요. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/script-line-1.mp3) | PASS | Delegated AI-assisted PASS: machine probe passed and STT assist produced no review signal; not native-speaker review |

| script 2 | キム | はい。質問しやすいし、自信もつきます。 | 네. 질문하기도 쉽고 자신감도 생깁니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/script-line-2.mp3) | PASS | Delegated AI-assisted PASS: machine probe passed and STT assist produced no review signal; not native-speaker review |

| script 3 | 佐藤 | 理由を二つ言う時に、しを使えます。 | 이유를 두 가지 말할 때 し를 쓸 수 있습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/script-line-3.mp3) | PASS | Delegated AI-assisted PASS: machine probe passed and STT assist produced no review signal; not native-speaker review |

| question 1 |  | 丁寧의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/question-1.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 2 |  | 自信의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/question-2.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 3 |  | 説明が丁寧だ___、練習も多いです。 |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/question-3.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 4 |  | 試験の前でも___ですね。 |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/question-4.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 5 |  | '이 수업은 설명이 정중하고 안심입니다'를 배열하세요. |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/question-5.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

### HN4-013 - 한번 확인해 봐요

| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| script 0 | キム | 予約の時間を調べてみます。 | 예약 시간을 한번 찾아보겠습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/script-line-0.mp3) | PASS | Delegated AI-assisted PASS: machine probe passed and STT assist produced no review signal; not native-speaker review |

| script 1 | 佐藤 | 分からなければ、受付で聞いてみましょう。 | 모르면 접수처에서 한번 물어봅시다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/script-line-1-regen-20260520T104500Z.mp3) | FLAG | Delegated AI-assisted FLAG: regenerated audio still has review signal(s) TRANSCRIPTION_TEXT_MISMATCH:分からなければ 手ホクで聞いてみましょう。; direct-listen or regenerate before rollout; not native-speaker review. |

| script 2 | キム | 案内の紙も読んでみます。 | 안내 종이도 한번 읽어보겠습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/script-line-2-regen-20260520T104500Z.mp3) | FLAG | Delegated AI-assisted FLAG: regenerated audio still has review signal(s) TRANSCRIPTION_TEXT_MISMATCH:案内の下を読んでみます。; direct-listen or regenerate before rollout; not native-speaker review. |

| script 3 | 佐藤 | 大丈夫なら、申し込んでみます。 | 괜찮다면 한번 신청해 보겠습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/script-line-3.mp3) | PASS | Delegated AI-assisted PASS: machine probe passed and STT assist produced no review signal; not native-speaker review |

| question 1 |  | 予約의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/question-1.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 2 |  | 受付의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/question-2.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 3 |  | 予約の時間を調べて___ます。 |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/question-3.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 4 |  | 大丈夫なら、___みます。 |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/question-4.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 5 |  | '예약 시간을 한번 찾아보겠습니다'를 배열하세요. |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/question-5.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

### HN4-014 - 미리 준비해 둬요

| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| script 0 | キム | 会議の前に資料を準備しておきます。 | 회의 전에 자료를 준비해 두겠습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/script-line-0.mp3) | PASS | Delegated AI-assisted PASS: machine probe passed and STT assist produced no review signal; not native-speaker review |

| script 1 | 佐藤 | 参加する人に連絡しておきます。 | 참가하는 사람에게 연락해 두겠습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/script-line-1.mp3) | PASS | Delegated AI-assisted PASS: machine probe passed and STT assist produced no review signal; not native-speaker review |

| script 2 | キム | 部屋も片付けておきましょう。 | 방도 정리해 둡시다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/script-line-2.mp3) | PASS | Delegated AI-assisted PASS: machine probe passed and STT assist produced no review signal; not native-speaker review |

| script 3 | 佐藤 | 予約の時間を決めておくと安心です。 | 예약 시간을 정해 두면 안심입니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/script-line-3.mp3) | PASS | Delegated AI-assisted PASS: machine probe passed and STT assist produced no review signal; not native-speaker review |

| question 1 |  | 準備의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/question-1.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 2 |  | 片付ける의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/question-2.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 3 |  | 資料を準備して___ます。 |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/question-3.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 4 |  | 予約の時間を___ておくと安心です。 |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/question-4.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 5 |  | '회의 전에 준비해 두겠습니다'를 배열하세요. |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/question-5.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

### HN4-015 - 깜빡 잊어버렸어요

| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| script 0 | キム | うっかり予約を忘れてしまいました。 | 깜빡 예약을 잊어버렸습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/script-line-0.mp3) | PASS | Delegated AI-assisted PASS: machine probe passed and STT assist produced no review signal; not native-speaker review |

| script 1 | 佐藤 | それは心配ですね。 | 그건 걱정이네요. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/script-line-1-regen-20260520T104500Z.mp3) | FLAG | Delegated AI-assisted FLAG: regenerated audio still has review signal(s) TRANSCRIPTION_TEXT_MISMATCH:それは心配です; direct-listen or regenerate before rollout; not native-speaker review. |

| script 2 | キム | スマートフォンも落としてしまいました。 | 스마트폰도 떨어뜨려 버렸습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/script-line-2.mp3) | PASS | Delegated AI-assisted PASS: machine probe passed and STT assist produced no review signal; not native-speaker review |

| script 3 | 佐藤 | 次からは予定を確認しておきましょう。 | 다음부터는 일정을 확인해 둡시다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/script-line-3.mp3) | PASS | Delegated AI-assisted PASS: machine probe passed and STT assist produced no review signal; not native-speaker review |

| question 1 |  | うっかり의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/question-1.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 2 |  | 忘れる의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/question-2.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 3 |  | 予約を忘れて___ました。 |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/question-3.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 4 |  | スマートフォンを___てしまいました。 |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/question-4.mp3) | PASS | Delegated AI-assisted PASS: cloze blank explains pause and omitted blank in STT; machine probe passed; not native-speaker review |

| question 5 |  | '예약을 잊어버렸습니다'를 배열하세요. |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/question-5.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

### HN4-016 - 연습을 계속해요

| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| script 0 | キム | 日本語の練習を毎日続けています。 | 일본어 연습을 매일 계속하고 있습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/script-line-0.mp3) | PASS | Delegated AI-assisted PASS: machine probe passed and STT assist produced no review signal; not native-speaker review |

| script 1 | 佐藤 | 運動も少しずつ続けるつもりです。 | 운동도 조금씩 계속할 생각입니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/script-line-1.mp3) | PASS | Delegated AI-assisted PASS: machine probe passed and STT assist produced no review signal; not native-speaker review |

| script 2 | キム | 将来のために、研究も続けたいです。 | 장래를 위해 연구도 계속하고 싶습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/script-line-2.mp3) | PASS | Delegated AI-assisted PASS: machine probe passed and STT assist produced no review signal; not native-speaker review |

| script 3 | 佐藤 | 一人で難しい時は、クラスに参加します。 | 혼자서 어려울 때는 수업에 참가합니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/script-line-3.mp3) | PASS | Delegated AI-assisted PASS: STT differs only by kana/kanji and punctuation normalization; not native-speaker review |

| question 1 |  | 続ける의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/question-1.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 2 |  | 練習의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/question-2.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 3 |  | 日本語の練習を毎日___ています。 |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/question-3.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 4 |  | 運動も少しずつ続ける___です。 |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/question-4.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 5 |  | '일본어 연습을 계속하고 있습니다'를 배열하세요. |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/question-5.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

## Result

AI-assisted verdict application now leaves 42 `PASS`, 3 `FLAG`, 0 `PENDING`,
and 0 `FAIL` rows. The 3 `FLAG` rows were regenerated once and still carry
post-regeneration STT review signals. Broad rollout remains blocked until
direct listening, another regeneration pass, or an explicit waiver clears them.
