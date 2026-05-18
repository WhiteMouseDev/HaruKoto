# N4 Pilot Human Audio QA Packet - Chapter 2

> Date: 2026-05-13
> Scope: N4 chapter 2 `이유・조건・의도 표현`, HN4-006, HN4-007, HN4-008, HN4-009, HN4-010
> Status: REVIEW PACKET - human verdict pending

## Boundary

This packet is for human audio-quality review. It does not regenerate audio,
change lesson content, update rollout status, or claim native-speaker approval.

ASSUMPTION: Chapter-level packets keep full N4 playback QA auditable. A flagged
or failed item should block broad rollout until regenerated or explicitly
waived.

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
| Generated at | `2026-05-13T05:50:32.669254+00:00` |
| Lessons | 5 |
| Script-line targets | 20 |
| Question-prompt targets | 25 |
| Total review targets | 45 |
| Missing audio URLs | 0 |
| Failed URL checks | 0 |

## Machine Preflight Context

Full N4 automated audio preflight passed 99 / 99 generated TTS targets with no
machine blockers. It found 11 non-blocking `HIGH_SILENCE_RATIO` warnings across
question prompts. Chapter 2 warning items to prioritize while listening:

- `HN4-006 question:4`
- `HN4-008 question:3`
- `HN4-009 question:4`
- `HN4-010 question:4`

## Review Items

### HN4-006 - 강의 깊이를 말해요

| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| script 0 | キム | この川の深さを確認しました。 | 이 강의 깊이를 확인했습니다. | gemini / gemini-2.5-flash-preview-tts | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/script-line-0-regen-20260518T023000Z.mp3) | PASS | Delegated AI-assisted post-regeneration PASS: MP3 probe passed and STT matched source exactly; not native-speaker review. |

| script 1 | 佐藤 | この川の浅さも分かりますか。 | 이 강의 얕은 정도도 알 수 있나요? | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/script-line-1-regen-20260518T030500Z.mp3) | FLAG | Delegated AI-assisted FLAG: regenerated audio still has review signal(s) TRANSCRIPTION_TEXT_MISMATCH:この川の浅さも分かります; direct-listen or regenerate before rollout; not native-speaker review. |

| script 2 | キム | はい。線の太さを確認できます。 | 네. 선의 굵기를 확인할 수 있습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/script-line-2-regen-20260518T013503Z.mp3) | PASS | Delegated AI-assisted post-regeneration PASS: MP3 probe passed and STT matched source exactly; not native-speaker review. |

| script 3 | 佐藤 | 情報の正しさも大切ですね。 | 정보의 정확성도 중요하네요. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/script-line-3.mp3) | PASS | Delegated AI-assisted PASS: machine pass + no parsed machine/STT review signal; not native-speaker review. |

| question 1 |  | 深い의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/question-1.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 2 |  | 正しい의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/question-2.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 3 |  | 川の深___を確認します。 (강의 깊이를 확인합니다.) |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/question-3-regen-20260518T021500Z.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 4 |  | 線の太___を見ます。 (선의 굵기를 봅니다.) |  | gemini / gemini-2.5-flash-preview-tts | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/question-4-regen-20260518T055500Z.mp3) | FLAG | Delegated AI-assisted FLAG: regenerated audio still has review signal(s) TRANSCRIPTION_TEXT_MISMATCH:線の太さを見ます。; direct-listen or regenerate before rollout; not native-speaker review. |

| question 5 |  | '강의 깊이를 확인했습니다'를 배열하세요. |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/question-5-regen-20260518T021500Z.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

### HN4-007 - 참가하려고 생각해요

| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| script 0 | 佐藤 | 週末のイベントに参加しようと思っています。 | 주말 이벤트에 참가하려고 생각하고 있습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/script-line-0.mp3) | PASS | Delegated AI-assisted PASS: machine pass + no parsed machine/STT review signal; not native-speaker review. |

| script 1 | キム | 私は友達に案内を送ろうと思っています。 | 저는 친구에게 안내를 보내려고 생각하고 있습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/script-line-1.mp3) | PASS | Delegated AI-assisted PASS: machine pass + no parsed machine/STT review signal; not native-speaker review. |

| script 2 | 佐藤 | 資料も集めようと思います。 | 자료도 모으려고 합니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/script-line-2.mp3) | PASS | Delegated AI-assisted PASS: machine pass + no parsed machine/STT review signal; not native-speaker review. |

| script 3 | キム | 新しい先生を紹介しようと思います。 | 새 선생님을 소개하려고 합니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/script-line-3.mp3) | PASS | Delegated AI-assisted PASS: machine pass + no parsed machine/STT review signal; not native-speaker review. |

| question 1 |  | 参加する의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/question-1.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 2 |  | 集める의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/question-2.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 3 |  | イベントに参加___と思っています。 |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/question-3.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 4 |  | 案内を送___と思っています。 |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/question-4.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 5 |  | '행사에 참가하려고 생각하고 있습니다'를 배열하세요. |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/question-5.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

### HN4-008 - 회의가 길었던 거예요

| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| script 0 | キム | 返事が遅れてすみません。 | 답장이 늦어서 죄송합니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/script-line-0-regen-20260514T083500Z.mp3) | PASS | Delegated AI-assisted post-regeneration PASS: MP3 probe passed and STT matched source exactly; not native-speaker review. |

| script 1 | 佐藤 | 何か理由があったんですか。 | 무슨 이유가 있었나요? | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/script-line-1.mp3) | PASS | Delegated AI-assisted PASS: machine pass + no parsed machine/STT review signal; not native-speaker review. |

| script 2 | キム | 会議が長かったのです。 | 회의가 길었던 거예요. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/script-line-2-regen-20260518T030500Z.mp3) | FLAG | Delegated AI-assisted FLAG: regenerated audio still has review signal(s) TRANSCRIPTION_TEXT_MISMATCH:会議が長かった; direct-listen or regenerate before rollout; not native-speaker review. |

| script 3 | 佐藤 | そうだったんですね。連絡ありがとうございます。 | 그랬군요. 연락 감사합니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/script-line-3.mp3) | PASS | Delegated AI-assisted PASS: machine pass + no parsed machine/STT review signal; not native-speaker review. |

| question 1 |  | 理由의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/question-1.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 2 |  | 返事의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/question-2.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 3 |  | 会議が長かった___。 (회의가 길었던 거예요.) |  | gemini / gemini-2.5-flash-preview-tts | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/question-3-regen-20260518T055500Z.mp3) | FLAG | Delegated AI-assisted FLAG: regenerated audio still has review signal(s) TRANSCRIPTION_TEXT_MISMATCH:会議が長かった; direct-listen or regenerate before rollout; not native-speaker review. |

| question 4 |  | 理由があった___か。 (이유가 있었던 건가요?) |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/question-4.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 5 |  | '회의가 길었던 거예요'를 배열하세요. |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/question-5.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

### HN4-009 - 면접을 위해 준비해요

| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| script 0 | キム | 面接のために、自己紹介を練習しています。 | 면접을 위해 자기소개를 연습하고 있습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/script-line-0.mp3) | PASS | Delegated AI-assisted PASS: machine pass + no parsed machine/STT review signal; not native-speaker review. |

| script 1 | 佐藤 | 就職するために、準備しているんですね。 | 취직하기 위해 준비하고 있군요. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/script-line-1.mp3) | PASS | Delegated AI-assisted PASS: machine pass + no parsed machine/STT review signal; not native-speaker review. |

| script 2 | キム | はい。新しい技術も勉強しています。 | 네. 새로운 기술도 공부하고 있습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/script-line-2.mp3) | PASS | Delegated AI-assisted PASS: machine pass + no parsed machine/STT review signal; not native-speaker review. |

| script 3 | 佐藤 | 教育のためにも役に立ちそうです。 | 교육을 위해서도 도움이 될 것 같습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/script-line-3.mp3) | PASS | Delegated AI-assisted PASS: machine pass + no parsed machine/STT review signal; not native-speaker review. |

| question 1 |  | 面接의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/question-1.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 2 |  | 準備의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/question-2.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 3 |  | 面接___、練習しています。 (면접을 위해 연습하고 있습니다.) |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/question-3.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 4 |  | 就職する___、準備します。 (취직하기 위해 준비합니다.) |  | gemini / gemini-2.5-flash-preview-tts | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/question-4-regen-20260518T055500Z.mp3) | FLAG | Delegated AI-assisted FLAG: regenerated audio still has review signal(s) TRANSCRIPTION_TEXT_MISMATCH:就職する準備; direct-listen or regenerate before rollout; not native-speaker review. |

| question 5 |  | '면접을 위해 준비하고 있습니다'를 배열하세요. |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/question-5.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

### HN4-010 - 누르면 바뀌어요

| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| script 0 | 佐藤 | このボタンを押すと、画面が変わります。 | 이 버튼을 누르면 화면이 바뀝니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/script-line-0.mp3) | PASS | Delegated AI-assisted PASS: machine pass + no parsed machine/STT review signal; not native-speaker review. |

| script 1 | キム | 信号が青になると、車が進みますね。 | 신호가 파란색이 되면 차가 나아가네요. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/script-line-1.mp3) | PASS | Delegated AI-assisted PASS: machine pass + no parsed machine/STT review signal; not native-speaker review. |

| script 2 | 佐藤 | はい。自然な結果を言うときに使います。 | 네. 자연스러운 결과를 말할 때 씁니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/script-line-2.mp3) | PASS | Delegated AI-assisted PASS: canonical STT normalized match with orthographic-only mismatch; not native-speaker review. |

| script 3 | キム | 商品が届くと、連絡が来ます。 | 상품이 도착하면 연락이 옵니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/script-line-3-regen-20260518T013503Z.mp3) | PASS | Delegated AI-assisted post-regeneration PASS: MP3 probe passed and STT matched source exactly; not native-speaker review. |

| question 1 |  | 信号의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/question-1.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 2 |  | 届く의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/question-2.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 3 |  | ボタンを押す___、画面が変わります。 |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/question-3.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 4 |  | 信号が青になる___、車が進みます。 |  | gemini / gemini-2.5-flash-preview-tts | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/question-4-regen-20260518T055500Z.mp3) | FLAG | Delegated AI-assisted FLAG: regenerated audio still has review signal(s) TRANSCRIPTION_TEXT_MISMATCH:信号が青になる。車が進む。; direct-listen or regenerate before rollout; not native-speaker review. |

| question 5 |  | '버튼을 누르면 화면이 바뀝니다'를 배열하세요. |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/question-5.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

## Result

Human verdict is pending. This packet closes only the preparation step for this
chapter's playback review.
