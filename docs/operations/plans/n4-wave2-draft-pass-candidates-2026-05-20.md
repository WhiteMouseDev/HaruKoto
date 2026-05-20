# N4 Audio QA AI-Assisted PASS Candidates

> Status: PASS CANDIDATES - no verdicts applied
> Boundary: machine/STT-assisted triage only; does not approve rollout

ASSUMPTION: A candidate means the target is still `PENDING`, has machine
audio pass evidence, and has no parsed machine/STT review signal. It is
not a final human audio-quality verdict.

## Sources

- Packet: `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md`
- Quality signal report: `docs/operations/plans/n4-wave2-draft-tts-machine-report-2026-05-20.md`
- Quality signal report: `docs/operations/plans/n4-wave2-draft-tts-stt-assist-run-2026-05-20.md`

## Summary

| Metric | Count |
|---|---:|
| Total review items | 45 |
| Pending verdicts | 45 |
| AI-assisted PASS candidates | 16 |
| Held for listening/regeneration review | 29 |
| Machine-warning items | 1 |
| STT-mismatch signal items | 29 |

## Candidate Criteria

- Current verdict is `PENDING`.
- Priority is `P2 pending` in the review queue.
- No parsed `HIGH_SILENCE_RATIO`, `TRANSCRIPTION_TEXT_MISMATCH`, or other machine/STT review signal is attached.
- Candidate status only reduces review order; it does not replace listening.

## Candidate CSV Contract

The companion CSV leaves `new_verdict` and `new_notes` blank on purpose.
After listening, set `new_verdict=PASS` only for rows that are complete,
intelligible, and acceptable for learner playback. Keep uncertain rows
`PENDING`, or mark `FLAG` / `FAIL` in the source verdict workflow.

## Candidates

| Target | Japanese text | Korean/context | Audio | Candidate reason | Recommended action | Packet |
|---|---|---|---|---|---|---|
| HN4-012 script:0 | この授業は説明が丁寧だし、練習も多いです。 | 이 수업은 설명이 정중하고 연습도 많습니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/script-line-0.mp3) | machine pass + no parsed machine/STT review signal | listen once; if complete and intelligible, set new_verdict=PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-012 script:1 | 試験の前でも安心ですね。 | 시험 전에도 안심이네요. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/script-line-1.mp3) | machine pass + no parsed machine/STT review signal | listen once; if complete and intelligible, set new_verdict=PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-012 script:2 | はい。質問しやすいし、自信もつきます。 | 네. 질문하기도 쉽고 자신감도 생깁니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/script-line-2.mp3) | machine pass + no parsed machine/STT review signal | listen once; if complete and intelligible, set new_verdict=PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-012 script:3 | 理由を二つ言う時に、しを使えます。 | 이유를 두 가지 말할 때 し를 쓸 수 있습니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d4633ddc-7d4a-4c57-ab33-79dc472d9905/script-line-3.mp3) | machine pass + no parsed machine/STT review signal | listen once; if complete and intelligible, set new_verdict=PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-013 script:0 | 予約の時間を調べてみます。 | 예약 시간을 한번 찾아보겠습니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/script-line-0.mp3) | machine pass + no parsed machine/STT review signal | listen once; if complete and intelligible, set new_verdict=PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-013 script:3 | 大丈夫なら、申し込んでみます。 | 괜찮다면 한번 신청해 보겠습니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/script-line-3.mp3) | machine pass + no parsed machine/STT review signal | listen once; if complete and intelligible, set new_verdict=PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-014 script:0 | 会議の前に資料を準備しておきます。 | 회의 전에 자료를 준비해 두겠습니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/script-line-0.mp3) | machine pass + no parsed machine/STT review signal | listen once; if complete and intelligible, set new_verdict=PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-014 script:1 | 参加する人に連絡しておきます。 | 참가하는 사람에게 연락해 두겠습니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/script-line-1.mp3) | machine pass + no parsed machine/STT review signal | listen once; if complete and intelligible, set new_verdict=PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-014 script:2 | 部屋も片付けておきましょう。 | 방도 정리해 둡시다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/script-line-2.mp3) | machine pass + no parsed machine/STT review signal | listen once; if complete and intelligible, set new_verdict=PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-014 script:3 | 予約の時間を決めておくと安心です。 | 예약 시간을 정해 두면 안심입니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a31b14ac-7a53-4aa9-81e9-e6e0f56ed6bc/script-line-3.mp3) | machine pass + no parsed machine/STT review signal | listen once; if complete and intelligible, set new_verdict=PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-015 script:0 | うっかり予約を忘れてしまいました。 | 깜빡 예약을 잊어버렸습니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/script-line-0.mp3) | machine pass + no parsed machine/STT review signal | listen once; if complete and intelligible, set new_verdict=PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-015 script:2 | スマートフォンも落としてしまいました。 | 스마트폰도 떨어뜨려 버렸습니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/script-line-2.mp3) | machine pass + no parsed machine/STT review signal | listen once; if complete and intelligible, set new_verdict=PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-015 script:3 | 次からは予定を確認しておきましょう。 | 다음부터는 일정을 확인해 둡시다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/script-line-3.mp3) | machine pass + no parsed machine/STT review signal | listen once; if complete and intelligible, set new_verdict=PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-016 script:0 | 日本語の練習を毎日続けています。 | 일본어 연습을 매일 계속하고 있습니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/script-line-0.mp3) | machine pass + no parsed machine/STT review signal | listen once; if complete and intelligible, set new_verdict=PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-016 script:1 | 運動も少しずつ続けるつもりです。 | 운동도 조금씩 계속할 생각입니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/script-line-1.mp3) | machine pass + no parsed machine/STT review signal | listen once; if complete and intelligible, set new_verdict=PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-016 script:2 | 将来のために、研究も続けたいです。 | 장래를 위해 연구도 계속하고 싶습니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ca89a60e-8cbf-41f4-8345-87cc0ac763ef/script-line-2.mp3) | machine pass + no parsed machine/STT review signal | listen once; if complete and intelligible, set new_verdict=PASS | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |

## Held Items

P0 machine-warning and P1 STT-mismatch rows stay out of the candidate CSV.
They should be listened to before waiver or regenerated if the signal is
confirmed as a content, clipping, pacing, pronunciation, or prompt-shape issue.

## Decision

Use this file to batch the safest listen-once checks first. Broad/full N4
rollout remains blocked until packet verdicts contain no `PENDING`,
`FLAG`, `FAIL`, or invalid values.
