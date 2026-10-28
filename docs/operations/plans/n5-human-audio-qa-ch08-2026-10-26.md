# N5 Pilot Human Audio QA Packet - Chapter 8

> Historical snapshot (2026-10-26): URLs, lengths, hashes and PENDING verdicts below are preserved evidence, not current-file approval. HN5-004 dialogue files were replaced later; use the [current representative links](n5-audio-qa-current-state-2026-10-28.md) for that lesson. Do not transfer verdicts to replacement audio.

> Date: 2026-10-26
> Scope: N5 chapter 8 `생활 표현과 동사 기초`, HN5-036, HN5-037, HN5-038, HN5-039, HN5-040, HN5-041, HN5-042, HN5-043, HN5-044
> Status: REVIEW PACKET - human verdict pending

## Current snapshot and evidence

- Read-only published lesson/cache snapshot: `2026-10-26 06:59:53.922749+00:00`.
- Public audio GET and local metadata probe: `2026-10-26T07:07:23.865136+00:00` to `2026-10-26T07:08:17.245589+00:00`.
- This chapter's 81 runtime inputs exactly match stored TTS text; URLs returned HTTP 200.
- Machine PASS is file/text metadata only. All reviewer verdicts remain PENDING; no listening, STT, generation, seed or verdict application was performed.
- Script lines are available through the mobile dialogue speakers. Question audio is reviewed through packet links; the current mobile lesson question UI has no question-TTS button. Vocabulary TTS is a separate path.
- See [current index](n5-human-audio-qa-packets-2026-10-26.md) and [machine report](n5-tts-audio-quality-preflight-2026-10-26.md).

## Boundary

This packet is for human audio-quality review. It does not regenerate audio,
change lesson content, update rollout status, or claim native-speaker approval.

ASSUMPTION: One full chapter is the minimum representative playback QA gate
before considering broader N5 rollout. A flagged or failed item should block
broad rollout until regenerated or explicitly waived.

## Reviewer Instructions

1. Open each audio link.
2. Compare the audio against the Japanese text.
3. Mark reviewer verdict as `PASS`, `FLAG`, or `FAIL`.
4. Use notes for misread text, clipped audio, unnatural pacing, wrong language,
   distracting pronunciation, or content/text mismatch.

## Verdict Rubric

| Verdict | Meaning                                                                             | Broad-rollout impact                   |
| ------- | ----------------------------------------------------------------------------------- | -------------------------------------- |
| PASS    | Text is complete, intelligible, and acceptable for learner playback                 | Can proceed for this item              |
| FLAG    | Understandable but has noticeable pacing, accent, or prompt-shape issue             | Review before rollout; may need waiver |
| FAIL    | Wrong text, clipped audio, wrong language, missing audio, or unusable pronunciation | Regenerate or fix before rollout       |

## Summary

| Metric                  |                             Result |
| ----------------------- | ---------------------------------: |
| Generated at            | `2026-10-26 06:59:53.922749+00:00` |
| Lessons                 |                                  9 |
| Script-line targets     |                                 36 |
| Question-prompt targets |                                 45 |
| Total review targets    |                                 81 |
| Missing audio URLs      |                                  0 |
| Failed URL checks       |                                  0 |

## Review Items

### HN5-036 - 종이를 두 장 삽니다

| Target     | Speaker | Japanese text                                         | Korean/context                   | Provider/model                      | URL check | Audio                                                                                                                      | Reviewer verdict | Notes                                     |
| ---------- | ------- | ----------------------------------------------------- | -------------------------------- | ----------------------------------- | --------- | -------------------------------------------------------------------------------------------------------------------------- | ---------------- | ----------------------------------------- |
| script 0   | キム    | 紙を二枚買います。                                    | 종이를 두 장 삽니다.             | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/7b8dd3f4-9016-43ee-8d33-294047abfdb4/script-line-0.mp3) | PENDING          |                                           |
| script 1   | 店員    | ペンも一つ買いますか。                                | 펜도 하나 사십니까?              | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/7b8dd3f4-9016-43ee-8d33-294047abfdb4/script-line-1.mp3) | PENDING          |                                           |
| script 2   | キム    | いいえ、紙を三枚お願いします。                        | 아니요, 종이를 세 장 부탁합니다. | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/7b8dd3f4-9016-43ee-8d33-294047abfdb4/script-line-2.mp3) | PENDING          |                                           |
| script 3   | 店員    | はい、三枚ですね。                                    | 네, 세 장이군요.                 | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/7b8dd3f4-9016-43ee-8d33-294047abfdb4/script-line-3.mp3) | PENDING          |                                           |
| question 1 |         | 二つ의 뜻은?                                          |                                  | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/7b8dd3f4-9016-43ee-8d33-294047abfdb4/question-1.mp3)    | PENDING          |                                           |
| question 2 |         | -枚의 뜻은?                                           |                                  | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/7b8dd3f4-9016-43ee-8d33-294047abfdb4/question-2.mp3)    | PENDING          |                                           |
| question 3 |         | 紙を二\_\_\_買います。(종이를 두 장 삽니다.)          |                                  | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/7b8dd3f4-9016-43ee-8d33-294047abfdb4/question-3.mp3)    | PENDING          | Machine review: HIGH_SILENCE_RATIO:0.3693 |
| question 4 |         | ペンも一\_\_\_買いますか。(펜도 하나 사십니까?)       |                                  | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/7b8dd3f4-9016-43ee-8d33-294047abfdb4/question-4.mp3)    | PENDING          |                                           |
| question 5 |         | '종이를 세 장 부탁합니다'를 올바른 순서로 배열하세요. |                                  | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/7b8dd3f4-9016-43ee-8d33-294047abfdb4/question-5.mp3)    | PENDING          |                                           |

### HN5-037 - 수요일 세 시에 만납니다

| Target     | Speaker | Japanese text                                          | Korean/context               | Provider/model                      | URL check | Audio                                                                                                                      | Reviewer verdict | Notes |
| ---------- | ------- | ------------------------------------------------------ | ---------------------------- | ----------------------------------- | --------- | -------------------------------------------------------------------------------------------------------------------------- | ---------------- | ----- |
| script 0   | 佐藤    | 水曜日の三時に会いますか。                             | 수요일 세 시에 만납니까?     | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/533b8fd1-f83b-4bac-8d4f-6b25c8b09e30/script-line-0.mp3) | PENDING          |       |
| script 1   | キム    | はい、三時に会います。                                 | 네, 세 시에 만납니다.        | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/533b8fd1-f83b-4bac-8d4f-6b25c8b09e30/script-line-1.mp3) | PENDING          |       |
| script 2   | 佐藤    | 明日は十時半に会いますか。                             | 내일은 열 시 반에 만납니까?  | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/533b8fd1-f83b-4bac-8d4f-6b25c8b09e30/script-line-2.mp3) | PENDING          |       |
| script 3   | キム    | いいえ、今日は水曜日です。                             | 아니요, 오늘은 수요일입니다. | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/533b8fd1-f83b-4bac-8d4f-6b25c8b09e30/script-line-3.mp3) | PENDING          |       |
| question 1 |         | 水曜日의 뜻은?                                         |                              | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/533b8fd1-f83b-4bac-8d4f-6b25c8b09e30/question-1.mp3)    | PENDING          |       |
| question 2 |         | -時의 뜻은?                                            |                              | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/533b8fd1-f83b-4bac-8d4f-6b25c8b09e30/question-2.mp3)    | PENDING          |       |
| question 3 |         | 水曜日の三時\_\_\_会います。(수요일 세 시에 만납니다.) |                              | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/533b8fd1-f83b-4bac-8d4f-6b25c8b09e30/question-3.mp3)    | PENDING          |       |
| question 4 |         | 十時\_\_\_に会います。(열 시 반에 만납니다.)           |                              | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/533b8fd1-f83b-4bac-8d4f-6b25c8b09e30/question-4.mp3)    | PENDING          |       |
| question 5 |         | '수요일 세 시에 만납니다'를 올바른 순서로 배열하세요.  |                              | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/533b8fd1-f83b-4bac-8d4f-6b25c8b09e30/question-5.mp3)    | PENDING          |       |

### HN5-038 - 이 종이를 한 장 부탁합니다

| Target     | Speaker | Japanese text                                            | Korean/context                          | Provider/model                      | URL check | Audio                                                                                                                      | Reviewer verdict | Notes                                     |
| ---------- | ------- | -------------------------------------------------------- | --------------------------------------- | ----------------------------------- | --------- | -------------------------------------------------------------------------------------------------------------------------- | ---------------- | ----------------------------------------- |
| script 0   | キム    | すみません。この紙を一枚お願いします。                   | 실례합니다. 이 종이를 한 장 부탁합니다. | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a9b60440-7f52-4bda-b9d7-24a144751618/script-line-0.mp3) | PENDING          |                                           |
| script 1   | 受付    | はい、一枚ですね。                                       | 네, 한 장이군요.                        | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a9b60440-7f52-4bda-b9d7-24a144751618/script-line-1.mp3) | PENDING          | Machine review: HIGH_SILENCE_RATIO:0.3642 |
| script 2   | 受付    | ボールペンもお願いしますか。                             | 볼펜도 필요하십니까?                    | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a9b60440-7f52-4bda-b9d7-24a144751618/script-line-2.mp3) | PENDING          |                                           |
| script 3   | キム    | いいえ、紙だけお願いします。                             | 아니요, 종이만 부탁합니다.              | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a9b60440-7f52-4bda-b9d7-24a144751618/script-line-3.mp3) | PENDING          |                                           |
| question 1 |         | お願いします의 뜻은?                                     |                                         | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a9b60440-7f52-4bda-b9d7-24a144751618/question-1.mp3)    | PENDING          |                                           |
| question 2 |         | この의 뜻은?                                             |                                         | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a9b60440-7f52-4bda-b9d7-24a144751618/question-2.mp3)    | PENDING          |                                           |
| question 3 |         | この紙を一枚\_\_\_。(이 종이를 한 장 부탁합니다.)        |                                         | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a9b60440-7f52-4bda-b9d7-24a144751618/question-3.mp3)    | PENDING          |                                           |
| question 4 |         | 紙\_\_\_お願いします。(종이만 부탁합니다.)               |                                         | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a9b60440-7f52-4bda-b9d7-24a144751618/question-4.mp3)    | PENDING          |                                           |
| question 5 |         | '이 종이를 한 장 부탁합니다'를 올바른 순서로 배열하세요. |                                         | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a9b60440-7f52-4bda-b9d7-24a144751618/question-5.mp3)    | PENDING          |                                           |

### HN5-039 - 책상 위에 펜이 있습니다

| Target     | Speaker | Japanese text                                         | Korean/context           | Provider/model                      | URL check | Audio                                                                                                                      | Reviewer verdict | Notes |
| ---------- | ------- | ----------------------------------------------------- | ------------------------ | ----------------------------------- | --------- | -------------------------------------------------------------------------------------------------------------------------- | ---------------- | ----- |
| script 0   | キム    | 部屋に机があります。                                  | 방에 책상이 있습니다.    | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d7c82eb9-0c8e-4982-9d3d-93dac75491a9/script-line-0.mp3) | PENDING          |       |
| script 1   | 佐藤    | 机の上にペンがあります。                              | 책상 위에 펜이 있습니다. | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d7c82eb9-0c8e-4982-9d3d-93dac75491a9/script-line-1.mp3) | PENDING          |       |
| script 2   | キム    | 部屋に猫もいますか。                                  | 방에 고양이도 있습니까?  | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d7c82eb9-0c8e-4982-9d3d-93dac75491a9/script-line-2.mp3) | PENDING          |       |
| script 3   | 佐藤    | いいえ、犬がいます。                                  | 아니요, 개가 있습니다.   | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d7c82eb9-0c8e-4982-9d3d-93dac75491a9/script-line-3.mp3) | PENDING          |       |
| question 1 |         | ある의 뜻은?                                          |                          | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d7c82eb9-0c8e-4982-9d3d-93dac75491a9/question-1.mp3)    | PENDING          |       |
| question 2 |         | いる의 뜻은?                                          |                          | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d7c82eb9-0c8e-4982-9d3d-93dac75491a9/question-2.mp3)    | PENDING          |       |
| question 3 |         | 机の上にペンが\_\_\_。(책상 위에 펜이 있습니다.)      |                          | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d7c82eb9-0c8e-4982-9d3d-93dac75491a9/question-3.mp3)    | PENDING          |       |
| question 4 |         | 部屋に猫が\_\_\_。(방에 고양이가 있습니다.)           |                          | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d7c82eb9-0c8e-4982-9d3d-93dac75491a9/question-4.mp3)    | PENDING          |       |
| question 5 |         | '책상 위에 펜이 있습니다'를 올바른 순서로 배열하세요. |                          | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/d7c82eb9-0c8e-4982-9d3d-93dac75491a9/question-5.mp3)    | PENDING          |       |

### HN5-040 - 먹습니다, 마십니다

| Target     | Speaker | Japanese text                                    | Korean/context             | Provider/model                      | URL check | Audio                                                                                                                      | Reviewer verdict | Notes                                     |
| ---------- | ------- | ------------------------------------------------ | -------------------------- | ----------------------------------- | --------- | -------------------------------------------------------------------------------------------------------------------------- | ---------------- | ----------------------------------------- |
| script 0   | キム    | 私は朝、パンを食べます。                         | 저는 아침에 빵을 먹습니다. | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/74e48a81-5473-4847-b45b-c6cd1319d654/script-line-0.mp3) | PENDING          |                                           |
| script 1   | 佐藤    | 私は水を飲みます。                               | 저는 물을 마십니다.        | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/74e48a81-5473-4847-b45b-c6cd1319d654/script-line-1.mp3) | PENDING          |                                           |
| script 2   | キム    | 昼に図書館へ行きます。                           | 점심에 도서관에 갑니다.    | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/74e48a81-5473-4847-b45b-c6cd1319d654/script-line-2.mp3) | PENDING          |                                           |
| script 3   | 佐藤    | 図書館で勉強します。                             | 도서관에서 공부합니다.     | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/74e48a81-5473-4847-b45b-c6cd1319d654/script-line-3.mp3) | PENDING          |                                           |
| question 1 |         | 食べる의 뜻은?                                   |                            | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/74e48a81-5473-4847-b45b-c6cd1319d654/question-1.mp3)    | PENDING          |                                           |
| question 2 |         | 飲む의 뜻은?                                     |                            | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/74e48a81-5473-4847-b45b-c6cd1319d654/question-2.mp3)    | PENDING          |                                           |
| question 3 |         | パンを\_\_\_。(빵을 먹습니다.)                   |                            | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/74e48a81-5473-4847-b45b-c6cd1319d654/question-3.mp3)    | PENDING          | Machine review: HIGH_SILENCE_RATIO:0.4997 |
| question 4 |         | 図書館で勉強\_\_\_。(도서관에서 공부합니다.)     |                            | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/74e48a81-5473-4847-b45b-c6cd1319d654/question-4.mp3)    | PENDING          |                                           |
| question 5 |         | '저는 빵을 먹습니다'를 올바른 순서로 배열하세요. |                            | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/74e48a81-5473-4847-b45b-c6cd1319d654/question-5.mp3)    | PENDING          |                                           |

### HN5-041 - 도서관에 공부하러 갑시다

| Target     | Speaker | Japanese text                                          | Korean/context            | Provider/model                      | URL check | Audio                                                                                                                      | Reviewer verdict | Notes                                     |
| ---------- | ------- | ------------------------------------------------------ | ------------------------- | ----------------------------------- | --------- | -------------------------------------------------------------------------------------------------------------------------- | ---------------- | ----------------------------------------- |
| script 0   | 佐藤    | 昼に図書館へ行きましょう。                             | 점심에 도서관에 갑시다.   | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/2249b117-80eb-429b-9257-6cd2d318db05/script-line-0.mp3) | PENDING          |                                           |
| script 1   | キム    | いいですね。勉強しに行きましょう。                     | 좋네요. 공부하러 갑시다.  | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/2249b117-80eb-429b-9257-6cd2d318db05/script-line-1.mp3) | PENDING          |                                           |
| script 2   | 佐藤    | 一緒に日本語を勉強します。                             | 함께 일본어를 공부합니다. | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/2249b117-80eb-429b-9257-6cd2d318db05/script-line-2.mp3) | PENDING          |                                           |
| script 3   | キム    | はい、行きましょう。                                   | 네, 갑시다.               | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/2249b117-80eb-429b-9257-6cd2d318db05/script-line-3.mp3) | PENDING          | Machine review: HIGH_SILENCE_RATIO:0.4276 |
| question 1 |         | 図書館의 뜻은?                                         |                           | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/2249b117-80eb-429b-9257-6cd2d318db05/question-1.mp3)    | PENDING          |                                           |
| question 2 |         | 一緒に의 뜻은?                                         |                           | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/2249b117-80eb-429b-9257-6cd2d318db05/question-2.mp3)    | PENDING          |                                           |
| question 3 |         | 図書館へ行き\_\_\_。(도서관에 갑시다.)                 |                           | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/2249b117-80eb-429b-9257-6cd2d318db05/question-3.mp3)    | PENDING          | Machine review: HIGH_SILENCE_RATIO:0.4443 |
| question 4 |         | 勉強し\_\_\_行きます。(공부하러 갑니다.)               |                           | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/2249b117-80eb-429b-9257-6cd2d318db05/question-4.mp3)    | PENDING          |                                           |
| question 5 |         | '도서관에 공부하러 갑시다'를 올바른 순서로 배열하세요. |                           | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/2249b117-80eb-429b-9257-6cd2d318db05/question-5.mp3)    | PENDING          |                                           |

### HN5-042 - 영화를 보는 것을 좋아합니다

| Target     | Speaker | Japanese text                                              | Korean/context                    | Provider/model                      | URL check | Audio                                                                                                                      | Reviewer verdict | Notes |
| ---------- | ------- | ---------------------------------------------------------- | --------------------------------- | ----------------------------------- | --------- | -------------------------------------------------------------------------------------------------------------------------- | ---------------- | ----- |
| script 0   | キム    | 私は映画を見るのが好きです。                               | 저는 영화를 보는 것을 좋아합니다. | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/81ee5bca-c354-4376-9e7d-ed1a7a1747d0/script-line-0.mp3) | PENDING          |       |
| script 1   | 佐藤    | その本はキムさんの本ですか。                               | 그 책은 김 씨의 책입니까?         | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/81ee5bca-c354-4376-9e7d-ed1a7a1747d0/script-line-1.mp3) | PENDING          |       |
| script 2   | キム    | はい、私の本です。                                         | 네, 제 책입니다.                  | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/81ee5bca-c354-4376-9e7d-ed1a7a1747d0/script-line-2.mp3) | PENDING          |       |
| script 3   | 佐藤    | 読むのも好きですか。                                       | 읽는 것도 좋아합니까?             | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/81ee5bca-c354-4376-9e7d-ed1a7a1747d0/script-line-3.mp3) | PENDING          |       |
| question 1 |         | 映画의 뜻은?                                               |                                   | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/81ee5bca-c354-4376-9e7d-ed1a7a1747d0/question-1.mp3)    | PENDING          |       |
| question 2 |         | 好きです의 뜻은?                                           |                                   | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/81ee5bca-c354-4376-9e7d-ed1a7a1747d0/question-2.mp3)    | PENDING          |       |
| question 3 |         | 映画を見る\_\_\_が好きです。(영화를 보는 것을 좋아합니다.) |                                   | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/81ee5bca-c354-4376-9e7d-ed1a7a1747d0/question-3.mp3)    | PENDING          |       |
| question 4 |         | 私\_\_\_本です。(제 책입니다.)                             |                                   | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/81ee5bca-c354-4376-9e7d-ed1a7a1747d0/question-4.mp3)    | PENDING          |       |
| question 5 |         | '영화를 보는 것을 좋아합니다'를 올바른 순서로 배열하세요.  |                                   | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/81ee5bca-c354-4376-9e7d-ed1a7a1747d0/question-5.mp3)    | PENDING          |       |

### HN5-043 - 이름을 쓰고 기다립니다

| Target     | Speaker | Japanese text                                                    | Korean/context                     | Provider/model                      | URL check | Audio                                                                                                                      | Reviewer verdict | Notes                                     |
| ---------- | ------- | ---------------------------------------------------------------- | ---------------------------------- | ----------------------------------- | --------- | -------------------------------------------------------------------------------------------------------------------------- | ---------------- | ----------------------------------------- |
| script 0   | 受付    | ここに名前を書いてください。                                     | 여기에 이름을 써 주세요.           | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1a082e94-7316-4fb0-a0c4-19aa61540199/script-line-0.mp3) | PENDING          |                                           |
| script 1   | キム    | はい、名前を書いて、友だちを待ちます。                           | 네, 이름을 쓰고 친구를 기다립니다. | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1a082e94-7316-4fb0-a0c4-19aa61540199/script-line-1.mp3) | PENDING          |                                           |
| script 2   | 受付    | この本を読んでください。                                         | 이 책을 읽어 주세요.               | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1a082e94-7316-4fb0-a0c4-19aa61540199/script-line-2.mp3) | PENDING          |                                           |
| script 3   | キム    | 分かりました。                                                   | 알겠습니다.                        | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1a082e94-7316-4fb0-a0c4-19aa61540199/script-line-3.mp3) | PENDING          |                                           |
| question 1 |         | 書く의 뜻은?                                                     |                                    | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1a082e94-7316-4fb0-a0c4-19aa61540199/question-1.mp3)    | PENDING          |                                           |
| question 2 |         | 待つ의 뜻은?                                                     |                                    | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1a082e94-7316-4fb0-a0c4-19aa61540199/question-2.mp3)    | PENDING          |                                           |
| question 3 |         | 名前を\_\_\_、友だちを待ちます。(이름을 쓰고 친구를 기다립니다.) |                                    | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1a082e94-7316-4fb0-a0c4-19aa61540199/question-3.mp3)    | PENDING          |                                           |
| question 4 |         | この本を\_\_\_ください。(이 책을 읽어 주세요.)                   |                                    | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1a082e94-7316-4fb0-a0c4-19aa61540199/question-4.mp3)    | PENDING          | Machine review: HIGH_SILENCE_RATIO:0.4329 |
| question 5 |         | '이름을 쓰고 친구를 기다립니다'를 올바른 순서로 배열하세요.      |                                    | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1a082e94-7316-4fb0-a0c4-19aa61540199/question-5.mp3)    | PENDING          |                                           |

### HN5-044 - 지금 책을 읽고 있습니다

| Target     | Speaker | Japanese text                                         | Korean/context                     | Provider/model                      | URL check | Audio                                                                                                                      | Reviewer verdict | Notes |
| ---------- | ------- | ----------------------------------------------------- | ---------------------------------- | ----------------------------------- | --------- | -------------------------------------------------------------------------------------------------------------------------- | ---------------- | ----- |
| script 0   | 佐藤    | キムさんは今、何をしていますか。                      | 김 씨는 지금 무엇을 하고 있습니까? | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ed24201d-0ab9-4bf5-9f2d-5127cd2ffbb9/script-line-0.mp3) | PENDING          |       |
| script 1   | キム    | 本を読んでいます。                                    | 책을 읽고 있습니다.                | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ed24201d-0ab9-4bf5-9f2d-5127cd2ffbb9/script-line-1.mp3) | PENDING          |       |
| script 2   | 佐藤    | 私は映画を見ています。                                | 저는 영화를 보고 있습니다.         | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ed24201d-0ab9-4bf5-9f2d-5127cd2ffbb9/script-line-2.mp3) | PENDING          |       |
| script 3   | キム    | 友だちは寝ていますか。                                | 친구는 자고 있습니까?              | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ed24201d-0ab9-4bf5-9f2d-5127cd2ffbb9/script-line-3.mp3) | PENDING          |       |
| question 1 |         | 今의 뜻은?                                            |                                    | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ed24201d-0ab9-4bf5-9f2d-5127cd2ffbb9/question-1.mp3)    | PENDING          |       |
| question 2 |         | 読む의 뜻은?                                          |                                    | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ed24201d-0ab9-4bf5-9f2d-5127cd2ffbb9/question-2.mp3)    | PENDING          |       |
| question 3 |         | 本を読んで\_\_\_。(책을 읽고 있습니다.)               |                                    | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ed24201d-0ab9-4bf5-9f2d-5127cd2ffbb9/question-3.mp3)    | PENDING          |       |
| question 4 |         | 映画を\_\_\_います。(영화를 보고 있습니다.)           |                                    | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ed24201d-0ab9-4bf5-9f2d-5127cd2ffbb9/question-4.mp3)    | PENDING          |       |
| question 5 |         | '지금 책을 읽고 있습니다'를 올바른 순서로 배열하세요. |                                    | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ed24201d-0ab9-4bf5-9f2d-5127cd2ffbb9/question-5.mp3)    | PENDING          |       |

## Result

Human verdict is pending. This packet closes only the preparation step for
representative full-chapter playback review.
