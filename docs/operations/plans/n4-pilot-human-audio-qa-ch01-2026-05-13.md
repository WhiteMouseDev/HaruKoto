# N4 Pilot Human Audio QA Packet - Chapter 1

> Date: 2026-05-13
> Scope: N4 chapter 1 `지시와 판단 표현`, HN4-001, HN4-002, HN4-003, HN4-004, HN4-005
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
| Generated at | `2026-05-13T05:41:37.178895+00:00` |
| Lessons | 5 |
| Script-line targets | 20 |
| Question-prompt targets | 25 |
| Total review targets | 45 |
| Missing audio URLs | 0 |
| Failed URL checks | 0 |

## Machine Preflight Context

Full N4 automated audio preflight passed 99 / 99 generated TTS targets with no
machine blockers. It found 11 non-blocking `HIGH_SILENCE_RATIO` warnings across
question prompts. Chapter 1 warning items to prioritize while listening:

- `HN4-001 question:3`
- `HN4-002 question:4`
- `HN4-003 question:3`
- `HN4-003 question:4`
- `HN4-004 question:4`
- `HN4-005 question:4`

## Review Items

### HN4-001 - 이름을 쓰세요

| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| script 0 | 先生 | 宿題を出す前に、名前を書きなさい。 | 숙제를 내기 전에 이름을 쓰세요. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/script-line-0.mp3) | PASS | Delegated AI-assisted PASS: machine pass + no parsed machine/STT review signal; not native-speaker review. |

| script 1 | 学生 | はい、ここに書けばいいですか。 | 네, 여기에 쓰면 되나요? | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/script-line-1.mp3) | PASS | Delegated AI-assisted PASS: machine pass + no parsed machine/STT review signal; not native-speaker review. |

| script 2 | 先生 | はい。それから、規則をもう一度確認しなさい。 | 네. 그리고 규칙을 한 번 더 확인하세요. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/script-line-2.mp3) | PASS | Delegated AI-assisted PASS: machine pass + no parsed machine/STT review signal; not native-speaker review. |

| script 3 | 学生 | 分かりました。注意して確認します。 | 알겠습니다. 주의해서 확인하겠습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/script-line-3-regen-20260518T013503Z.mp3) | PASS | Delegated AI-assisted PASS: canonical STT normalized match with kana/kanji orthographic-only mismatch; not native-speaker review. |

| question 1 |  | 規則의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/question-1.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 2 |  | 注意의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/question-2.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 3 |  | 名前を書き___. (이름을 쓰세요.) |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/question-3.mp3) | PENDING |  |

| question 4 |  | 規則を確認___. (규칙을 확인하세요.) |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/question-4.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 5 |  | '이름을 쓰세요'를 올바른 순서로 배열하세요. |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/question-5.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

### HN4-002 - 일찍 쉬는 편이 좋아요

| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| script 0 | キム | 少し頭が痛いです。 | 머리가 조금 아픕니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/script-line-0.mp3) | PENDING |  |

| script 1 | 佐藤 | 心配ですね。今日は早く寝たほうがいいです。 | 걱정이네요. 오늘은 일찍 자는 편이 좋습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/script-line-1.mp3) | PASS | Delegated AI-assisted PASS: canonical STT normalized match with orthographic-only mismatch; not native-speaker review. |

| script 2 | キム | 医者に相談したほうがいいですか。 | 의사와 상담하는 편이 좋을까요? | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/script-line-2.mp3) | PENDING |  |

| script 3 | 佐藤 | 熱があれば、医者に相談したほうが安心です。 | 열이 있으면 의사와 상담하는 편이 안심이 됩니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/script-line-3.mp3) | PASS | Delegated AI-assisted PASS: canonical STT normalized match with orthographic-only mismatch; not native-speaker review. |

| question 1 |  | 心配의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/question-1.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 2 |  | 相談의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/question-2.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 3 |  | 早く寝___。 (일찍 자는 편이 좋습니다.) |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/question-3.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 4 |  | 医者に相談___。 (의사와 상담하는 편이 좋습니다.) |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/question-4.mp3) | PENDING |  |

| question 5 |  | '오늘은 일찍 자는 편이 좋습니다'를 배열하세요. |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/question-5.mp3) | PASS | Delegated AI-assisted PASS: machine pass + no parsed machine/STT review signal; not native-speaker review. |

### HN4-003 - 늦을지도 몰라요

| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| script 0 | 佐藤 | 台風で電車が遅れるかもしれません。 | 태풍 때문에 전철이 늦을지도 모릅니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/script-line-0.mp3) | PASS | Delegated AI-assisted PASS: machine pass + no parsed machine/STT review signal; not native-speaker review. |

| script 1 | キム | じゃあ、会議に間に合わないかもしれませんね。 | 그럼 회의에 맞추지 못할지도 모르겠네요. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/script-line-1-regen-20260518T004000Z.mp3) | PASS | Delegated AI-assisted post-regeneration PASS: MP3 probe passed and STT matched source exactly; not native-speaker review. |

| script 2 | 佐藤 | 最近、天気がよく変わります。 | 최근 날씨가 자주 바뀝니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/script-line-2.mp3) | PASS | Delegated AI-assisted PASS: machine pass + no parsed machine/STT review signal; not native-speaker review. |

| script 3 | キム | 少し心配ですが、早めに出発します。 | 조금 걱정되지만 일찍 출발하겠습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/script-line-3.mp3) | PASS | Delegated AI-assisted PASS: machine pass + no parsed machine/STT review signal; not native-speaker review. |

| question 1 |  | 台風의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/question-1.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 2 |  | 間に合う의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/question-2.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 3 |  | 電車が遅れる___。 (전철이 늦을지도 모릅니다.) |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/question-3.mp3) | PENDING |  |

| question 4 |  | 間に合わない___。 (시간에 맞지 못할지도 모릅니다.) |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/question-4.mp3) | PENDING |  |

| question 5 |  | '전철이 늦을지도 모릅니다'를 배열하세요. |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/question-5.mp3) | PASS | Delegated AI-assisted PASS: machine pass + no parsed machine/STT review signal; not native-speaker review. |

### HN4-004 - 달릴 수밖에 없어요

| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| script 0 | キム | 時間が足りません。駅まで走るしかありません。 | 시간이 부족합니다. 역까지 달릴 수밖에 없습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/script-line-0.mp3) | PENDING |  |

| script 1 | 佐藤 | 次の予定がありますからね。 | 다음 일정이 있으니까요. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/script-line-1.mp3) | PENDING |  |

| script 2 | キム | タクシーは高いので、電車に乗るしかありません。 | 택시는 비싸서 전철을 탈 수밖에 없습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/script-line-2.mp3) | PASS | Delegated AI-assisted PASS: machine pass + no parsed machine/STT review signal; not native-speaker review. |

| script 3 | 佐藤 | まだ間に合います。急いで行きましょう。 | 아직 맞출 수 있습니다. 서둘러 갑시다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/script-line-3-regen-20260518T013503Z.mp3) | PASS | Delegated AI-assisted post-regeneration PASS: MP3 probe passed and STT matched source exactly; not native-speaker review. |

| question 1 |  | 足りる의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/question-1.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 2 |  | 予定의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/question-2.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 3 |  | 走る___。 (달릴 수밖에 없습니다.) |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/question-3.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 4 |  | 電車に乗る___。 (전철을 탈 수밖에 없습니다.) |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/question-4.mp3) | PENDING |  |

| question 5 |  | '역까지 달릴 수밖에 없습니다'를 배열하세요. |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/question-5.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

### HN4-005 - 한자를 찾아볼 수 있어요

| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| script 0 | 佐藤 | このアプリで漢字を調べられます。 | 이 앱으로 한자를 찾아볼 수 있습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/script-line-0.mp3) | PASS | Delegated AI-assisted PASS: machine pass + no parsed machine/STT review signal; not native-speaker review. |

| script 1 | キム | 文も翻訳できますか。 | 문장도 번역할 수 있나요? | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/script-line-1.mp3) | PENDING |  |

| script 2 | 佐藤 | はい。授業の予約にも申し込めます。 | 네. 수업 예약도 신청할 수 있습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/script-line-2.mp3) | PENDING |  |

| script 3 | キム | それなら自信を持って勉強できます。 | 그렇다면 자신감을 갖고 공부할 수 있습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/script-line-3.mp3) | PASS | Delegated AI-assisted PASS: machine pass + no parsed machine/STT review signal; not native-speaker review. |

| question 1 |  | 翻訳의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/question-1.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 2 |  | 申し込む의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/question-2.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 3 |  | 漢字を調べ___。 (한자를 찾아볼 수 있습니다.) |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/question-3.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 4 |  | 文を翻訳___。 (문장을 번역할 수 있습니다.) |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/question-4.mp3) | PENDING |  |

| question 5 |  | '이 앱으로 한자를 찾아볼 수 있습니다'를 배열하세요. |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/question-5.mp3) | PASS | Delegated AI-assisted PASS: machine pass + no parsed machine/STT review signal; not native-speaker review. |

## Result

Human verdict is pending. This packet closes only the preparation step for this
chapter's playback review.
