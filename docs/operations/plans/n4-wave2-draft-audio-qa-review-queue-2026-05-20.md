# N4 Audio QA Review Queue

> Status: REVIEW QUEUE - no remaining verdict blockers
> Boundary: prioritization artifact only; does not approve rollout

ASSUMPTION: This queue orders review work but does not replace listening,
native-speaker review, or explicit `PASS` / `FLAG` / `FAIL` verdicts.

## Sources

- Packet: `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md`
- Quality signal report: `docs/operations/plans/n4-wave2-draft-tts-machine-report-2026-05-20.md`
- Quality signal report: `docs/operations/plans/n4-wave2-draft-tts-stt-assist-run-2026-05-20.md`

## Summary

| Metric | Count |
|---|---:|
| Total review items | 45 |
| PENDING | 0 |
| PASS | 45 |
| FLAG | 0 |
| FAIL | 0 |
| WAIVED | 0 |
| Review-signal items | 29 |
| P0 machine-warning items | 1 |
| STT-mismatch signal items | 29 |

## P0 Review First

- None

## P1 STT Mismatch Review

- None

## P2 Remaining Pending

- None

## P3 Resolved Or Waived

| Priority | Target | Japanese text | Korean/context | Audio | Review signals | Verdict | Packet |
|---|---|---|---|---|---|---|---|
| P3 resolved | HN4-012 script:0 | この授業は説明が丁寧だし、練習も多いです。 | 이 수업은 설명이 정중하고 연습도 많습니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/script-line-0.mp3) | - | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-012 script:1 | 試験の前でも安心ですね。 | 시험 전에도 안심이네요. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/script-line-1.mp3) | - | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-012 script:2 | はい。質問しやすいし、自信もつきます。 | 네. 질문하기도 쉽고 자신감도 생깁니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/script-line-2.mp3) | - | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-012 script:3 | 理由を二つ言う時に、しを使えます。 | 이유를 두 가지 말할 때 し를 쓸 수 있습니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/script-line-3.mp3) | - | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-012 question:1 | 丁寧의 뜻은? |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/question-1.mp3) | TRANSCRIPTION_TEXT_MISMATCH:丁珏孫 | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-012 question:2 | 自信의 뜻은? |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/question-2.mp3) | TRANSCRIPTION_TEXT_MISMATCH:地震ゲイツン | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-012 question:3 | 説明が丁寧だ___、練習も多いです。 |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/question-3.mp3) | TRANSCRIPTION_TEXT_MISMATCH:[malformed STT response] 説明が丁寧だ。あら、練習も多いです。 | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-012 question:4 | 試験の前でも___ですね。 |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/question-4.mp3) | TRANSCRIPTION_TEXT_MISMATCH:試験の前でもなわあじゅうです。 | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-012 question:5 | '이 수업은 설명이 정중하고 안심입니다'를 배열하세요. |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/question-5.mp3) | TRANSCRIPTION_TEXT_MISMATCH:イスオプン ソルミョンイ チョンジュンハゴ アンシムイムニダルル ペヨルハセヨ | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-013 script:0 | 予約の時間を調べてみます。 | 예약 시간을 한번 찾아보겠습니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/script-line-0.mp3) | - | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-013 script:1 | わからなければ、人に聞いてみましょう。 | 모르면 다른 사람에게 한번 물어봅시다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/script-line-1-regen-20260520T062700Z.mp3) | TRANSCRIPTION_TEXT_MISMATCH:わからなければ、ふふで聞いてみましょう。 | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-013 script:2 | 案内を読んでみましょう。 | 안내를 한번 읽어 봅시다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/script-line-2-regen-20260520T062500Z.mp3) | TRANSCRIPTION_TEXT_MISMATCH:案内のおせも読んでみます。 | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-013 script:3 | 大丈夫なら、申し込んでみます。 | 괜찮다면 한번 신청해 보겠습니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/script-line-3.mp3) | - | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-013 question:1 | 予約의 뜻은? |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/question-1.mp3) | TRANSCRIPTION_TEXT_MISMATCH:ゆうやうへいとん | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-013 question:2 | 受付의 뜻은? |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/question-2.mp3) | TRANSCRIPTION_TEXT_MISMATCH:とうふワイン | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-013 question:3 | 予約の時間を調べて___ます。 |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/question-3.mp3) | TRANSCRIPTION_TEXT_MISMATCH:予約の時間を調べて時間もにます。 | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-013 question:4 | 大丈夫なら、___みます。 |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/question-4.mp3) | TRANSCRIPTION_TEXT_MISMATCH:大丈夫なら、見なざります | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-013 question:5 | '예약 시간을 한번 찾아보겠습니다'를 배열하세요. |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/question-5.mp3) | TRANSCRIPTION_TEXT_MISMATCH:予約時間を一度探してみます。るを配列하세요。 | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-014 script:0 | 会議の前に資料を準備しておきます。 | 회의 전에 자료를 준비해 두겠습니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/script-line-0.mp3) | - | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-014 script:1 | 参加する人に連絡しておきます。 | 참가하는 사람에게 연락해 두겠습니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/script-line-1.mp3) | - | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-014 script:2 | 部屋も片付けておきましょう。 | 방도 정리해 둡시다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/script-line-2.mp3) | - | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-014 script:3 | 予約の時間を決めておくと安心です。 | 예약 시간을 정해 두면 안심입니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/script-line-3.mp3) | - | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-014 question:1 | 準備의 뜻은? |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/question-1.mp3) | TRANSCRIPTION_TEXT_MISMATCH:準備万端 | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-014 question:2 | 片付ける의 뜻은? |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/question-2.mp3) | TRANSCRIPTION_TEXT_MISMATCH:カラツケる | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-014 question:3 | 資料を準備して___ます。 |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/question-3.mp3) | TRANSCRIPTION_TEXT_MISMATCH:資料を準備して、しばたまあす。 | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-014 question:4 | 予約の時間を___ておくと安心です。 |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/question-4.mp3) | TRANSCRIPTION_TEXT_MISMATCH:予約の時間を手おくと安心です。 | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-014 question:5 | '회의 전에 준비해 두겠습니다'를 배열하세요. |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/question-5.mp3) | TRANSCRIPTION_TEXT_MISMATCH:ホエーイジョンに準備しておきますを部屋はせよ | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-015 script:0 | うっかり予約を忘れてしまいました。 | 깜빡 예약을 잊어버렸습니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/script-line-0.mp3) | - | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-015 script:1 | 大変です。 | 큰일입니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/script-line-1-regen-20260520T062000Z.mp3) | TRANSCRIPTION_TEXT_MISMATCH:それは新米です。 | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-015 script:2 | スマートフォンも落としてしまいました。 | 스마트폰도 떨어뜨려 버렸습니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/script-line-2.mp3) | - | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-015 script:3 | 次からは予定を確認しておきましょう。 | 다음부터는 일정을 확인해 둡시다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/script-line-3.mp3) | - | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-015 question:1 | うっかり의 뜻은? |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/question-1.mp3) | TRANSCRIPTION_TEXT_MISMATCH:おつかりえん | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-015 question:2 | 忘れる의 뜻은? |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/question-2.mp3) | TRANSCRIPTION_TEXT_MISMATCH:忘れルエ | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-015 question:3 | 予約を忘れて___ました。 |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/question-3.mp3) | TRANSCRIPTION_TEXT_MISMATCH:予約を忘れてたまちました。 | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-015 question:4 | スマートフォンを___てしまいました。 |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/question-4.mp3) | HIGH_SILENCE_RATIO:0.4203, TRANSCRIPTION_TEXT_MISMATCH:スマートフォンをてしまいました | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-015 question:5 | '예약을 잊어버렸습니다'를 배열하세요. |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/question-5.mp3) | TRANSCRIPTION_TEXT_MISMATCH:やあくを忘れましたを配列してください。 | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-016 script:0 | 日本語の練習を毎日続けています。 | 일본어 연습을 매일 계속하고 있습니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/script-line-0.mp3) | - | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-016 script:1 | 運動も少しずつ続けるつもりです。 | 운동도 조금씩 계속할 생각입니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/script-line-1.mp3) | - | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-016 script:2 | 将来のために、研究も続けたいです。 | 장래를 위해 연구도 계속하고 싶습니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/script-line-2.mp3) | - | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-016 script:3 | 一人で難しい時は、クラスに参加します。 | 혼자서 어려울 때는 수업에 참가합니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/script-line-3.mp3) | TRANSCRIPTION_TEXT_MISMATCH:ひとりで難しい時はクラスに参加します。 | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-016 question:1 | 続ける의 뜻은? |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/question-1.mp3) | TRANSCRIPTION_TEXT_MISMATCH:ゾケルスン | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-016 question:2 | 練習의 뜻은? |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/question-2.mp3) | TRANSCRIPTION_TEXT_MISMATCH:レンシーエット | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-016 question:3 | 日本語の練習を毎日___ています。 |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/question-3.mp3) | TRANSCRIPTION_TEXT_MISMATCH:日本語の練習を毎日 もらっています。 | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-016 question:4 | 運動も少しずつ続ける___です。 |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/question-4.mp3) | TRANSCRIPTION_TEXT_MISMATCH:運動も少しずつ続けるです。 | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| P3 resolved | HN4-016 question:5 | '일본어 연습을 계속하고 있습니다'를 배열하세요. |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/question-5.mp3) | TRANSCRIPTION_TEXT_MISMATCH:「日本語の練習を続けています」を配列してください。 | PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |

## Decision

Use this queue to review P0 machine/verdict blocker rows first, then P1
STT mismatch rows, then remaining pending packet rows. STT mismatches are
review-priority signals, not automatic audio-fail verdicts. Broad/full N4
rollout remains blocked until the packet verdict tracker has no `PENDING`,
`FLAG`, `FAIL`, or invalid verdict values.
