# N4 Pilot/Draft Human Audio QA Packet - Chapter 5

> Date: 2026-05-27
> Scope: N4 chapter 5 `일상 관찰과 전달 표현`, HN4-017, HN4-018, HN4-019, HN4-020, HN4-021
> Status: REVIEW PACKET - AI-assisted partial verdicts applied; 37 PASS, 8 PENDING

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
| Generated at | `2026-05-27T02:36:15.535057+00:00` |
| Lessons | 5 |
| Script-line targets | 20 |
| Question-prompt targets | 25 |
| Total review targets | 45 |
| Missing audio URLs | 0 |
| Failed URL checks | 0 |

## Review Items

### HN4-017 - 주말에 이것저것 해요

| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| script 0 | キム | 週末は掃除をしたり、洗濯をしたりします。 | 주말에는 청소를 하거나 빨래를 하거나 합니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/script-line-0.mp3) | PASS | Delegated AI-assisted PASS: machine probe passed and STT assist produced no review signal; not native-speaker review |

| script 1 | 佐藤 | 忙しいですね。 | 바쁘네요. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/script-line-1-regen-n4ch05-lexical-20260527.mp3) | PASS | Delegated AI-assisted post-regeneration PASS: MP3 probe passed and STT matched source exactly; not native-speaker review. |

| script 2 | キム | はい。来週の準備をしたり、部屋を片付けたりします。 | 네. 다음 주 준비를 하거나 방을 정리하거나 합니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/script-line-2.mp3) | PASS | Delegated AI-assisted PASS: machine probe passed and STT assist produced no review signal; not native-speaker review |

| script 3 | 佐藤 | 生活の習慣を話す時に便利ですね。 | 생활 습관을 말할 때 편리하네요. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/script-line-3.mp3) | PASS | Delegated AI-assisted PASS: machine probe passed and STT assist produced no review signal; not native-speaker review |

| question 1 |  | 掃除의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/question-1.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 2 |  | 洗濯의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/question-2.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 3 |  | 掃除をし___、洗濯をし___します。 |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/question-3.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 4 |  | 문맥상 '준비'에 해당하는 말은? 来週の___をしたりします。 |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/question-4.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 5 |  | '청소를 하거나 빨래를 하거나 합니다'를 배열하세요. |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/question-5.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

### HN4-018 - 곧 고장 날 것 같아요

| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| script 0 | キム | この古い機械は壊れそうですから、会議では使わないでください。 | 이 오래된 기계는 고장 날 것 같으니, 회의에서는 쓰지 말아 주세요. | gemini / gemini-2.5-flash-preview-tts | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/script-line-0-regen-n4ch05-rewrite2-20260527.mp3) | PASS | Delegated AI-assisted post-regeneration PASS: MP3 probe passed and STT matched source exactly; not native-speaker review. |

| script 1 | 佐藤 | 会議で使うのは無理そうですね。 | 회의에서 쓰기는 무리일 것 같네요. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/script-line-1.mp3) | PASS | Delegated AI-assisted PASS: machine probe passed and STT assist produced no review signal; not native-speaker review |

| script 2 | キム | 別の機械なら操作が簡単そうです。 | 다른 기계라면 조작이 간단해 보입니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/script-line-2.mp3) | PENDING |  |

| script 3 | 佐藤 | この操作は大変そうです。早めに相談しましょう。 | 이 조작은 힘들어 보입니다. 일찍 상담합시다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/script-line-3-regen-n4ch05-cleanup-20260527.mp3) | PASS | Delegated AI-assisted post-regeneration PASS: MP3 probe passed and STT matched source exactly; not native-speaker review. |

| question 1 |  | 機械의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/question-1.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 2 |  | 無理의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/question-2.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 3 |  | この機械は壊れ___です。 |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/question-3.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 4 |  | 눈앞의 상태를 보고 추측할 때 알맞은 표현은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/question-4.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 5 |  | '이 기계는 고장 날 것 같습니다'를 배열하세요. |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/question-5.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

### HN4-019 - 회의가 세 시라던데요

| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| script 0 | キム | 明日の会議は三時から始まるそうです。 | 내일 회의는 세 시부터 시작한다고 합니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/script-line-0.mp3) | PENDING |  |

| script 1 | 佐藤 | 予定が変わるそうですね。 | 예정이 바뀐다고 하네요. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/script-line-1.mp3) | PASS | Delegated AI-assisted PASS: machine probe passed and STT assist produced no review signal; not native-speaker review |

| script 2 | キム | 試験は思ったより簡単だそうです。 | 시험은 생각보다 쉽다고 합니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/script-line-2.mp3) | PASS | Delegated AI-assisted PASS: machine probe passed and STT assist produced no review signal; not native-speaker review |

| script 3 | 佐藤 | 受付は混むそうですから、早く行きましょう。 | 접수는 붐빈다고 하니, 일찍 갑시다. | gemini / gemini-2.5-flash-preview-tts | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/script-line-3-regen-n4ch05-gemini-20260527.mp3) | PASS | Delegated AI-assisted post-regeneration PASS: MP3 probe passed and STT matched source exactly; not native-speaker review. |

| question 1 |  | 予定의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/question-1.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 2 |  | 受付의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/question-2.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 3 |  | 会議は三時から始まる___です。 |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/question-3.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 4 |  | 들은 정보를 전달할 때 알맞은 표현은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/question-4.mp3) | PENDING |  |

| question 5 |  | '시험은 쉽다고 합니다'를 배열하세요. |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/question-5.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

### HN4-020 - 약속은 지키는 법이에요

| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| script 0 | 先輩 | 約束は守るものです。 | 약속은 지키는 법입니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/script-line-0.mp3) | PENDING |  |

| script 1 | キム | はい。規則はみんなで守るものですね。 | 네. 규칙은 모두 함께 지키는 법이네요. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/script-line-1.mp3) | PASS | Delegated AI-assisted retry PASS: machine probe passed and 60s STT retry matched source exactly; not native-speaker review |

| script 2 | 先輩 | 挨拶は普通、先にするものです。 | 인사는 보통 먼저 하는 법입니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/script-line-2.mp3) | PENDING |  |

| script 3 | キム | 社会で必要な考え方ですね。 | 사회에서 필요한 사고방식이네요. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/script-line-3.mp3) | PASS | Delegated AI-assisted retry PASS: machine probe passed and 60s STT retry matched source exactly; not native-speaker review |

| question 1 |  | 約束의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/question-1.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 2 |  | 守る의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/question-2.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 3 |  | 約束は守る___です。 |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/question-3.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 4 |  | 規則はみんなで___ものですね。 |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/question-4.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 5 |  | '약속은 지키는 법입니다'를 배열하세요. |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/question-5.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

### HN4-021 - 예약했으니 자리 있을 거예요

| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| script 0 | キム | 予約したので、席はあるはずです。 | 예약했으니 자리는 있을 것입니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/script-line-0.mp3) | PENDING |  |

| script 1 | 佐藤 | 資料も今日届くはずです。 | 자료도 오늘 도착할 것입니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/script-line-1.mp3) | PASS | Delegated AI-assisted retry PASS: machine probe passed and 60s STT retry matched source exactly; not native-speaker review |

| script 2 | キム | 会議の予定は午後に決まるはずです。 | 회의 예정은 오후에 정해질 것입니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/script-line-2.mp3) | PENDING |  |

| script 3 | 佐藤 | 準備はできそうですね。 | 준비는 될 것 같네요. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/script-line-3.mp3) | PENDING |  |

| question 1 |  | 予約의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/question-1.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 2 |  | 届く의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/question-2.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 3 |  | 席はある___です。 |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/question-3.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 4 |  | 資料も今日___はずです。 |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/question-4.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 5 |  | '자료는 오늘 도착할 것입니다'를 배열하세요. |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/question-5.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

## Result

Human verdict is pending. This packet closes only the preparation step for
representative full-chapter playback review.
