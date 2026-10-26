# N5 Pilot Human Audio QA Packet - Chapter 1

> Date: 2026-10-26
> Scope: N5 chapter 1 `인사와 첫 만남`, HN5-001, HN5-002, HN5-003, HN5-004, HN5-005
> Status: REVIEW PACKET - human verdict pending

## Current snapshot and evidence

- Read-only published lesson/cache snapshot: `2026-10-26 06:59:53.922749+00:00`.
- Public audio GET and local metadata probe: `2026-10-26T07:07:23.865136+00:00` to `2026-10-26T07:08:17.245589+00:00`.
- This chapter's 45 runtime inputs exactly match stored TTS text; URLs returned HTTP 200.
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
| Lessons                 |                                  5 |
| Script-line targets     |                                 20 |
| Question-prompt targets |                                 25 |
| Total review targets    |                                 45 |
| Missing audio URLs      |                                  0 |
| Failed URL checks       |                                  0 |

## Review Items

### HN5-001 - 처음 만난 자리

| Target     | Speaker | Japanese text                                                | Korean/context                             | Provider/model                      | URL check | Audio                                                                                                                      | Reviewer verdict | Notes                                     |
| ---------- | ------- | ------------------------------------------------------------ | ------------------------------------------ | ----------------------------------- | --------- | -------------------------------------------------------------------------------------------------------------------------- | ---------------- | ----------------------------------------- |
| script 0   | 田中    | はじめまして。田中です。学生です。                           | 처음 뵙겠습니다. 다나카입니다. 학생입니다. | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a1946486-f789-4741-ab15-4f6c712f586b/script-line-0.mp3) | PENDING          |                                           |
| script 1   | キム    | はじめまして。私はキムです。                                 | 처음 뵙겠습니다. 저는 김입니다.            | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a1946486-f789-4741-ab15-4f6c712f586b/script-line-1.mp3) | PENDING          |                                           |
| script 2   | 田中    | キムさん、よろしくお願いします。                             | 김 씨, 잘 부탁드립니다.                    | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a1946486-f789-4741-ab15-4f6c712f586b/script-line-2.mp3) | PENDING          |                                           |
| script 3   | キム    | こちらこそ、よろしくお願いします。                           | 저야말로, 잘 부탁드립니다.                 | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a1946486-f789-4741-ab15-4f6c712f586b/script-line-3.mp3) | PENDING          |                                           |
| question 1 |         | はじめまして의 뜻은?                                         |                                            | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a1946486-f789-4741-ab15-4f6c712f586b/question-1.mp3)    | PENDING          |                                           |
| question 2 |         | '학생'의 일본어는?                                           |                                            | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a1946486-f789-4741-ab15-4f6c712f586b/question-2.mp3)    | PENDING          |                                           |
| question 3 |         | 私はキム\_\_\_\_。(저는 김입니다.)                           |                                            | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a1946486-f789-4741-ab15-4f6c712f586b/question-3.mp3)    | PENDING          |                                           |
| question 4 |         | はじめまして。田中\_\_\_\_。(처음 뵙겠습니다. 다나카입니다.) |                                            | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a1946486-f789-4741-ab15-4f6c712f586b/question-4.mp3)    | PENDING          | Machine review: HIGH_SILENCE_RATIO:0.4449 |
| question 5 |         | '저는 학생입니다'를 올바른 순서로 배열하세요.                |                                            | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/a1946486-f789-4741-ab15-4f6c712f586b/question-5.mp3)    | PENDING          |                                           |

### HN5-002 - 어디서 오셨나요?

| Target     | Speaker | Japanese text                                       | Korean/context                                  | Provider/model                      | URL check | Audio                                                                                                                      | Reviewer verdict | Notes |
| ---------- | ------- | --------------------------------------------------- | ----------------------------------------------- | ----------------------------------- | --------- | -------------------------------------------------------------------------------------------------------------------------- | ---------------- | ----- |
| script 0   | 鈴木    | キムさんは留学生ですか。                            | 김 씨는 유학생인가요?                           | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/22b9bfa8-9819-4afd-8e1d-969524adca1e/script-line-0.mp3) | PENDING          |       |
| script 1   | キム    | はい、留学生です。韓国から来ました。                | 네, 유학생입니다. 한국에서 왔습니다.            | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/22b9bfa8-9819-4afd-8e1d-969524adca1e/script-line-1.mp3) | PENDING          |       |
| script 2   | 鈴木    | そうですか。英語は分かりますか。                    | 그렇군요. 영어는 알아요?                        | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/22b9bfa8-9819-4afd-8e1d-969524adca1e/script-line-2.mp3) | PENDING          |       |
| script 3   | キム    | はい、少し分かります。鈴木さんの国はどこですか。    | 네, 조금 알아요. 스즈키 씨의 나라는 어디인가요? | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/22b9bfa8-9819-4afd-8e1d-969524adca1e/script-line-3.mp3) | PENDING          |       |
| question 1 |         | 留学生의 뜻은?                                      |                                                 | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/22b9bfa8-9819-4afd-8e1d-969524adca1e/question-1.mp3)    | PENDING          |       |
| question 2 |         | '어디'를 뜻하는 일본어는?                           |                                                 | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/22b9bfa8-9819-4afd-8e1d-969524adca1e/question-2.mp3)    | PENDING          |       |
| question 3 |         | 学生です\_\_\_\_。(학생인가요?)                     |                                                 | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/22b9bfa8-9819-4afd-8e1d-969524adca1e/question-3.mp3)    | PENDING          |       |
| question 4 |         | 国は どこ \_\_\_\_。(나라는 어디인가요?)            |                                                 | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/22b9bfa8-9819-4afd-8e1d-969524adca1e/question-4.mp3)    | PENDING          |       |
| question 5 |         | '김 씨는 유학생인가요?'를 올바른 순서로 배열하세요. |                                                 | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/22b9bfa8-9819-4afd-8e1d-969524adca1e/question-5.mp3)    | PENDING          |       |

### HN5-003 - 이야기 주제 세우기

| Target     | Speaker | Japanese text                                        | Korean/context                                  | Provider/model                      | URL check | Audio                                                                                                                      | Reviewer verdict | Notes                                     |
| ---------- | ------- | ---------------------------------------------------- | ----------------------------------------------- | ----------------------------------- | --------- | -------------------------------------------------------------------------------------------------------------------------- | ---------------- | ----------------------------------------- |
| script 0   | キム    | 鈴木さんの仕事は何ですか。                           | 스즈키 씨의 직업은 뭔가요?                      | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/21161f32-9b71-43e2-9c38-e0a8192bf076/script-line-0.mp3) | PENDING          |                                           |
| script 1   | 鈴木    | 私は医者です。キムさんは？                           | 저는 의사입니다. 김 씨는요?                     | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/21161f32-9b71-43e2-9c38-e0a8192bf076/script-line-1.mp3) | PENDING          |                                           |
| script 2   | キム    | 私は大学の学生です。友達は会社の人です。             | 저는 대학교 학생입니다. 친구는 회사 사람입니다. | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/21161f32-9b71-43e2-9c38-e0a8192bf076/script-line-2.mp3) | PENDING          |                                           |
| script 3   | 鈴木    | そうですか。大学は楽しいですか。                     | 그렇군요. 대학은 즐거운가요?                    | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/21161f32-9b71-43e2-9c38-e0a8192bf076/script-line-3.mp3) | PENDING          |                                           |
| question 1 |         | 仕事의 뜻은?                                         |                                                 | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/21161f32-9b71-43e2-9c38-e0a8192bf076/question-1.mp3)    | PENDING          |                                           |
| question 2 |         | '의사'를 뜻하는 일본어는?                            |                                                 | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/21161f32-9b71-43e2-9c38-e0a8192bf076/question-2.mp3)    | PENDING          |                                           |
| question 3 |         | 私\_\_\_\_学生です。(저는 학생입니다.)               |                                                 | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/21161f32-9b71-43e2-9c38-e0a8192bf076/question-3.mp3)    | PENDING          | Machine review: HIGH_SILENCE_RATIO:0.3751 |
| question 4 |         | 友達\_\_\_\_会社の人です。(친구는 회사 사람입니다.)  |                                                 | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/21161f32-9b71-43e2-9c38-e0a8192bf076/question-4.mp3)    | PENDING          |                                           |
| question 5 |         | '스즈키 씨는 의사입니다'를 올바른 순서로 배열하세요. |                                                 | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/21161f32-9b71-43e2-9c38-e0a8192bf076/question-5.mp3)    | PENDING          |                                           |

### HN5-004 - 공통점이 반가울 때

| Target     | Speaker | Japanese text                                                                   | Korean/context                           | Provider/model                      | URL check | Audio                                                                                                                      | Reviewer verdict | Notes |
| ---------- | ------- | ------------------------------------------------------------------------------- | ---------------------------------------- | ----------------------------------- | --------- | -------------------------------------------------------------------------------------------------------------------------- | ---------------- | ----- |
| script 0   | キム    | 私は映画が好きです。                                                            | 저는 영화를 좋아합니다.                  | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c2ed2932-ed5a-4dc8-92f3-db96516e6859/script-line-0.mp3) | PENDING          |       |
| script 1   | 田中    | 私も映画が好きです！音楽も好きです。                                            | 저도 영화를 좋아합니다! 음악도 좋아해요. | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c2ed2932-ed5a-4dc8-92f3-db96516e6859/script-line-1.mp3) | PENDING          |       |
| script 2   | キム    | 本当ですか。旅行も好きですか。                                                  | 정말이에요? 여행도 좋아하나요?           | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c2ed2932-ed5a-4dc8-92f3-db96516e6859/script-line-2.mp3) | PENDING          |       |
| script 3   | 田中    | はい、旅行も料理も好きです。                                                    | 네, 여행도 요리도 좋아합니다.            | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c2ed2932-ed5a-4dc8-92f3-db96516e6859/script-line-3.mp3) | PENDING          |       |
| question 1 |         | 映画의 뜻은?                                                                    |                                          | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c2ed2932-ed5a-4dc8-92f3-db96516e6859/question-1.mp3)    | PENDING          |       |
| question 2 |         | '요리'를 뜻하는 일본어는?                                                       |                                          | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c2ed2932-ed5a-4dc8-92f3-db96516e6859/question-2.mp3)    | PENDING          |       |
| question 3 |         | 「私は映画が好きです。」「私\_\_\_\_映画が好きです。」(저도 영화를 좋아합니다.) |                                          | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c2ed2932-ed5a-4dc8-92f3-db96516e6859/question-3.mp3)    | PENDING          |       |
| question 4 |         | 旅行\_\_\_\_料理\_\_\_\_好きです。(여행도 요리도 좋아합니다.)                   |                                          | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c2ed2932-ed5a-4dc8-92f3-db96516e6859/question-4.mp3)    | PENDING          |       |
| question 5 |         | '저도 음악을 좋아합니다'를 올바른 순서로 배열하세요.                            |                                          | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c2ed2932-ed5a-4dc8-92f3-db96516e6859/question-5.mp3)    | PENDING          |       |

### HN5-005 - 대화 분위기 맞추기

| Target     | Speaker | Japanese text                                                                    | Korean/context                                       | Provider/model                      | URL check | Audio                                                                                                                      | Reviewer verdict | Notes                                     |
| ---------- | ------- | -------------------------------------------------------------------------------- | ---------------------------------------------------- | ----------------------------------- | --------- | -------------------------------------------------------------------------------------------------------------------------- | ---------------- | ----------------------------------------- |
| script 0   | キム    | おはようございます。今日はいい天気ですね。                                       | 안녕하세요. 오늘은 좋은 날씨네요.                    | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/9555d852-d2a3-4d63-ac90-68e4f1ceee6d/script-line-0.mp3) | PENDING          |                                           |
| script 1   | 田中    | そうですね。キムさん、元気ですか。                                               | 그렇네요. 김 씨, 잘 지내요?                          | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/9555d852-d2a3-4d63-ac90-68e4f1ceee6d/script-line-1.mp3) | PENDING          |                                           |
| script 2   | キム    | はい、元気ですよ。田中さんも元気ですね。                                         | 네, 잘 지내요. 다나카 씨도 건강하시네요.             | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/9555d852-d2a3-4d63-ac90-68e4f1ceee6d/script-line-2.mp3) | PENDING          |                                           |
| script 3   | 田中    | ありがとうございます。あ、あの人は友達ですよ。いい人ですよ。                     | 감사합니다. 아, 저 사람은 친구예요. 좋은 사람이에요. | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/9555d852-d2a3-4d63-ac90-68e4f1ceee6d/script-line-3.mp3) | PENDING          |                                           |
| question 1 |         | 元気의 뜻은?                                                                     |                                                      | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/9555d852-d2a3-4d63-ac90-68e4f1ceee6d/question-1.mp3)    | PENDING          |                                           |
| question 2 |         | '감사합니다'를 뜻하는 일본어는?                                                  |                                                      | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/9555d852-d2a3-4d63-ac90-68e4f1ceee6d/question-2.mp3)    | PENDING          |                                           |
| question 3 |         | いい天気です\_\_\_\_。(좋은 날씨네요.) — 상대에게 동의를 구할 때                 |                                                      | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/9555d852-d2a3-4d63-ac90-68e4f1ceee6d/question-3.mp3)    | PENDING          | Machine review: HIGH_SILENCE_RATIO:0.4514 |
| question 4 |         | あの人は友達です\_\_\_\_。(저 사람은 친구예요.) — 상대가 모르는 정보를 알려줄 때 |                                                      | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/9555d852-d2a3-4d63-ac90-68e4f1ceee6d/question-4.mp3)    | PENDING          | Machine review: HIGH_SILENCE_RATIO:0.443  |
| question 5 |         | '오늘은 좋은 날씨네요'를 올바른 순서로 배열하세요.                               |                                                      | elevenlabs / eleven_multilingual_v2 | ok        | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/9555d852-d2a3-4d63-ac90-68e4f1ceee6d/question-5.mp3)    | PENDING          |                                           |

## Result

Human verdict is pending. This packet closes only the preparation step for
representative full-chapter playback review.
