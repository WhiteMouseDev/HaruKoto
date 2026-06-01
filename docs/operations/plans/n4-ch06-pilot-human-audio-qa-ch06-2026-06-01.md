# N4 Pilot Human Audio QA Packet - Chapter 6

> Date: 2026-06-01
> Scope: N4 chapter 6 `수혜와 대조, 수동 표현`, HN4-022, HN4-023, HN4-024, HN4-025, HN4-026
> Status: REVIEW PACKET - human verdict pending

## Boundary

This packet is for human audio-quality review. It does not regenerate audio,
change lesson content, update rollout status, or claim native-speaker approval.

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
| Generated at | `2026-06-01T06:16:31.008524+00:00` |
| Lessons | 5 |
| Script-line targets | 20 |
| Question-prompt targets | 25 |
| Total review targets | 45 |
| Missing audio URLs | 0 |
| Failed URL checks | 0 |

## Review Items

### HN4-022 - 후배에게 지도를 그려 줘요

| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| script 0 | キム | 後輩に地図を描いてあげました。 | 후배에게 지도를 그려 주었습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b9250446-d707-46d4-a461-66e273b8534e/script-line-0-regen-n4ch06-script-20260601.mp3) | PASS | Delegated AI/STT PASS: regenerated 2026-06-01; machine preflight passed; post-regeneration STT mismatch reviewed as non-blocking recognizer ambiguity; not native-speaker review. |

| script 1 | 佐藤 | 親切ですね。受付の場所も教えてあげましたか。 | 친절하네요. 접수처 위치도 알려 주었나요? | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b9250446-d707-46d4-a461-66e273b8534e/script-line-1-regen-n4ch06-script-20260601.mp3) | PASS | Delegated AI/STT PASS: regenerated 2026-06-01; machine preflight passed; post-regeneration STT mismatch reviewed as non-blocking recognizer ambiguity; not native-speaker review. |

| script 2 | キム | はい。困ったら話を聞いてあげます。 | 네. 곤란하면 이야기를 들어 줄 거예요. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b9250446-d707-46d4-a461-66e273b8534e/script-line-2.mp3) | PASS | Delegated AI/STT PASS: machine preflight passed and no review-priority signal remained; not native-speaker review. |

| script 3 | 佐藤 | 手伝ってあげる時は、相手の気持ちも大事ですね。 | 도와줄 때는 상대의 마음도 중요하네요. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b9250446-d707-46d4-a461-66e273b8534e/script-line-3-regen-n4ch06-script-20260601.mp3) | PASS | Delegated AI/STT PASS: regenerated 2026-06-01; machine preflight passed; post-regeneration STT mismatch reviewed as non-blocking recognizer ambiguity; not native-speaker review. |

| question 1 |  | 後輩의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b9250446-d707-46d4-a461-66e273b8534e/question-1.mp3) | PASS | Delegated AI/STT PASS: URL check and machine preflight passed; mixed Korean/Japanese prompt makes STT mismatch unreliable; not native-speaker review. |

| question 2 |  | 手伝う의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b9250446-d707-46d4-a461-66e273b8534e/question-2.mp3) | PASS | Delegated AI/STT PASS: URL check and machine preflight passed; mixed Korean/Japanese prompt makes STT mismatch unreliable; not native-speaker review. |

| question 3 |  | 後輩に地図を描いて___ました。 |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b9250446-d707-46d4-a461-66e273b8534e/question-3.mp3) | PASS | Delegated AI/STT PASS: CH06 URL check and machine preflight passed; high-silence/STT signal is review-priority only for this mixed cloze prompt; not native-speaker review. |

| question 4 |  | 문맥상 "위치를 알려 주다"에 맞는 표현은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b9250446-d707-46d4-a461-66e273b8534e/question-4.mp3) | PASS | Delegated AI/STT PASS: URL check and machine preflight passed; mixed Korean/Japanese prompt makes STT mismatch unreliable; not native-speaker review. |

| question 5 |  | '후배에게 지도를 그려 주었습니다'를 배열하세요. |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b9250446-d707-46d4-a461-66e273b8534e/question-5.mp3) | PASS | Delegated AI/STT PASS: URL check and machine preflight passed; mixed Korean/Japanese prompt makes STT mismatch unreliable; not native-speaker review. |

### HN4-023 - 선배가 안내해 줬어요

| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| script 0 | キム | 先輩が会場まで案内してくれました。 | 선배가 행사장까지 안내해 주었습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/45466832-238e-429a-af10-e9811dc360d3/script-line-0.mp3) | PASS | Delegated AI/STT PASS: machine preflight passed and no review-priority signal remained; not native-speaker review. |

| script 1 | 佐藤 | 受付の場所も説明してくれましたか。 | 접수처 위치도 설명해 주었나요? | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/45466832-238e-429a-af10-e9811dc360d3/script-line-1-regen-n4ch06-script-20260601.mp3) | PASS | Delegated AI/STT PASS: regenerated 2026-06-01; machine preflight passed; post-regeneration STT mismatch reviewed as non-blocking recognizer ambiguity; not native-speaker review. |

| script 2 | キム | はい。少し待ってくれたので、安心しました。 | 네. 조금 기다려 주어서 안심했습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/45466832-238e-429a-af10-e9811dc360d3/script-line-2.mp3) | PASS | Delegated AI/STT PASS: machine preflight passed and no review-priority signal remained; not native-speaker review. |

| script 3 | 佐藤 | 助けてもらった時の気持ちが伝わりますね。 | 도움을 받았을 때의 마음이 전해지네요. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/45466832-238e-429a-af10-e9811dc360d3/script-line-3.mp3) | PASS | Delegated AI/STT PASS: machine preflight passed and no review-priority signal remained; not native-speaker review. |

| question 1 |  | 先輩의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/45466832-238e-429a-af10-e9811dc360d3/question-1.mp3) | PASS | Delegated AI/STT PASS: URL check and machine preflight passed; mixed Korean/Japanese prompt makes STT mismatch unreliable; not native-speaker review. |

| question 2 |  | 会場의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/45466832-238e-429a-af10-e9811dc360d3/question-2.mp3) | PASS | Delegated AI/STT PASS: URL check and machine preflight passed; mixed Korean/Japanese prompt makes STT mismatch unreliable; not native-speaker review. |

| question 3 |  | 先輩が会場まで案内して___ました。 |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/45466832-238e-429a-af10-e9811dc360d3/question-3.mp3) | PASS | Delegated AI/STT PASS: URL check and machine preflight passed; mixed Korean/Japanese prompt makes STT mismatch unreliable; not native-speaker review. |

| question 4 |  | 受付の場所も___くれましたか。 |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/45466832-238e-429a-af10-e9811dc360d3/question-4.mp3) | PASS | Delegated AI/STT PASS: URL check and machine preflight passed; mixed Korean/Japanese prompt makes STT mismatch unreliable; not native-speaker review. |

| question 5 |  | '선배가 행사장까지 안내해 주었습니다'를 배열하세요. |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/45466832-238e-429a-af10-e9811dc360d3/question-5.mp3) | PASS | Delegated AI/STT PASS: URL check and machine preflight passed; mixed Korean/Japanese prompt makes STT mismatch unreliable; not native-speaker review. |

### HN4-024 - 주소를 확인해 달라고 했어요

| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| script 0 | キム | 受付の人に住所を確認してもらいました。 | 접수처 직원에게 주소를 확인해 달라고 했습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/35093fd4-0511-4bdc-bfe4-e4c25c269654/script-line-0-regen-n4ch06-script-20260601.mp3) | PASS | Delegated AI/STT PASS: regenerated 2026-06-01; machine preflight passed; post-regeneration STT mismatch reviewed as non-blocking recognizer ambiguity; not native-speaker review. |

| script 1 | 佐藤 | 予約の時間も教えてもらいましたか。 | 예약 시간도 알려 달라고 했나요? | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/35093fd4-0511-4bdc-bfe4-e4c25c269654/script-line-1.mp3) | PASS | Delegated AI/STT PASS: machine preflight passed and no review-priority signal remained; not native-speaker review. |

| script 2 | キム | はい。遠慮なく聞いてくださいと言われました。 | 네. 사양하지 말고 물어보라고 들었습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/35093fd4-0511-4bdc-bfe4-e4c25c269654/script-line-2.mp3) | PASS | Delegated AI/STT PASS: machine preflight passed and no review-priority signal remained; not native-speaker review. |

| script 3 | 佐藤 | 必要なことは受付の人にもう一度確認してもらいましょう。 | 필요한 것은 접수처 직원에게 한 번 더 확인해 달라고 합시다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/35093fd4-0511-4bdc-bfe4-e4c25c269654/script-line-3-regen-n4ch06-script-20260601.mp3) | PASS | Delegated AI/STT PASS: regenerated 2026-06-01; machine preflight passed; post-regeneration STT mismatch reviewed as non-blocking recognizer ambiguity; not native-speaker review. |

| question 1 |  | 受付의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/35093fd4-0511-4bdc-bfe4-e4c25c269654/question-1.mp3) | PASS | Delegated AI/STT PASS: URL check and machine preflight passed; mixed Korean/Japanese prompt makes STT mismatch unreliable; not native-speaker review. |

| question 2 |  | 住所의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/35093fd4-0511-4bdc-bfe4-e4c25c269654/question-2.mp3) | PASS | Delegated AI/STT PASS: URL check and machine preflight passed; mixed Korean/Japanese prompt makes STT mismatch unreliable; not native-speaker review. |

| question 3 |  | 受付の人に住所を確認して___ました。 |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/35093fd4-0511-4bdc-bfe4-e4c25c269654/question-3.mp3) | PASS | Delegated AI/STT PASS: CH06 URL check and machine preflight passed; high-silence/STT signal is review-priority only for this mixed cloze prompt; not native-speaker review. |

| question 4 |  | 予約の時間も___もらいましたか。 |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/35093fd4-0511-4bdc-bfe4-e4c25c269654/question-4.mp3) | PASS | Delegated AI/STT PASS: URL check and machine preflight passed; mixed Korean/Japanese prompt makes STT mismatch unreliable; not native-speaker review. |

| question 5 |  | '접수처 직원에게 주소를 확인해 달라고 했습니다'를 배열하세요. |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/35093fd4-0511-4bdc-bfe4-e4c25c269654/question-5.mp3) | PASS | Delegated AI/STT PASS: URL check and machine preflight passed; mixed Korean/Japanese prompt makes STT mismatch unreliable; not native-speaker review. |

### HN4-025 - 예약했는데 자리가 없어요

| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| script 0 | キム | 予約したのに、席がありませんでした。 | 예약했는데도 자리가 없었습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b8b159a7-b8d4-45b3-a8d7-a9d07837b991/script-line-0.mp3) | PASS | Delegated AI/STT PASS: machine preflight passed and supplemental STT retry exact matched; not native-speaker review. |

| script 1 | 佐藤 | それは残念ですね。受付に連絡しましたか。 | 그건 아쉽네요. 접수처에 연락했나요? | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b8b159a7-b8d4-45b3-a8d7-a9d07837b991/script-line-1-regen-n4ch06-script-20260601.mp3) | PASS | Delegated AI/STT PASS: regenerated 2026-06-01; machine preflight passed; post-regeneration STT mismatch reviewed as non-blocking recognizer ambiguity; not native-speaker review. |

| script 2 | キム | 時間に間に合ったのに、確認に時間がかかりました。 | 시간에 맞췄는데도 확인에 시간이 걸렸습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b8b159a7-b8d4-45b3-a8d7-a9d07837b991/script-line-2.mp3) | PASS | Delegated AI/STT PASS: machine preflight passed and no review-priority signal remained; not native-speaker review. |

| script 3 | 佐藤 | 期待と違う結果を話す時に、のにを使います。 | 기대와 다른 결과를 말할 때 のに를 씁니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b8b159a7-b8d4-45b3-a8d7-a9d07837b991/script-line-3.mp3) | PASS | Delegated AI/STT PASS: machine preflight passed and supplemental STT retry exact matched; not native-speaker review. |

| question 1 |  | 席의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b8b159a7-b8d4-45b3-a8d7-a9d07837b991/question-1.mp3) | PASS | Delegated AI/STT PASS: URL check and machine preflight passed; mixed Korean/Japanese prompt makes STT mismatch unreliable; not native-speaker review. |

| question 2 |  | 残念な의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b8b159a7-b8d4-45b3-a8d7-a9d07837b991/question-2.mp3) | PASS | Delegated AI/STT PASS: URL check and machine preflight passed; mixed Korean/Japanese prompt makes STT mismatch unreliable; not native-speaker review. |

| question 3 |  | 予約した___、席がありませんでした。 |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b8b159a7-b8d4-45b3-a8d7-a9d07837b991/question-3.mp3) | PASS | Delegated AI/STT PASS: URL check and machine preflight passed; mixed Korean/Japanese prompt makes STT mismatch unreliable; not native-speaker review. |

| question 4 |  | 時間に___のに、確認に時間がかかりました。 |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b8b159a7-b8d4-45b3-a8d7-a9d07837b991/question-4.mp3) | PASS | Delegated AI/STT PASS: URL check and machine preflight passed; mixed Korean/Japanese prompt makes STT mismatch unreliable; not native-speaker review. |

| question 5 |  | '예약했는데도 자리가 없었습니다'를 배열하세요. |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b8b159a7-b8d4-45b3-a8d7-a9d07837b991/question-5.mp3) | PASS | Delegated AI/STT PASS: URL check and machine preflight passed; mixed Korean/Japanese prompt makes STT mismatch unreliable; not native-speaker review. |

### HN4-026 - 자전거를 도난당했어요

| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| script 0 | キム | 駅の前で自転車を盗まれました。 | 역 앞에서 자전거를 도난당했습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ef3004f3-bca8-4621-b7aa-520cdde4e823/script-line-0-regen-n4ch06-script-20260601.mp3) | PASS | Delegated AI/STT PASS: regenerated 2026-06-01; machine preflight passed; post-regeneration STT mismatch reviewed as non-blocking recognizer ambiguity; not native-speaker review. |

| script 1 | 警察官 | 落とし物ではなく、盗まれたんですね。 | 분실물이 아니라 도난당한 거군요. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ef3004f3-bca8-4621-b7aa-520cdde4e823/script-line-1-regen-n4ch06-script-20260601.mp3) | PASS | Delegated AI/STT PASS: regenerated 2026-06-01; machine preflight passed and post-regeneration STT exact match; not native-speaker review. |

| script 2 | キム | はい。近くの人に声をかけられて、すぐ警察に来ました。 | 네. 근처 사람이 말을 걸어 와서 바로 경찰에 왔습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ef3004f3-bca8-4621-b7aa-520cdde4e823/script-line-2.mp3) | PASS | Delegated AI/STT PASS: machine preflight passed and no review-priority signal remained; not native-speaker review. |

| script 3 | 警察官 | 近くのカメラの映像がこれから確認されます。 | 근처 카메라 영상이 이제 확인될 것입니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ef3004f3-bca8-4621-b7aa-520cdde4e823/script-line-3-regen-n4ch06-script-20260601.mp3) | PASS | Delegated AI/STT PASS: regenerated 2026-06-01; machine preflight passed; post-regeneration STT mismatch reviewed as non-blocking recognizer ambiguity; not native-speaker review. |

| question 1 |  | 自転車의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ef3004f3-bca8-4621-b7aa-520cdde4e823/question-1.mp3) | PASS | Delegated AI/STT PASS: URL check and machine preflight passed; mixed Korean/Japanese prompt makes STT mismatch unreliable; not native-speaker review. |

| question 2 |  | 盗む의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ef3004f3-bca8-4621-b7aa-520cdde4e823/question-2.mp3) | PASS | Delegated AI/STT PASS: URL check and machine preflight passed; mixed Korean/Japanese prompt makes STT mismatch unreliable; not native-speaker review. |

| question 3 |  | 自転車を盗___ました。 |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ef3004f3-bca8-4621-b7aa-520cdde4e823/question-3.mp3) | PASS | Delegated AI/STT PASS: URL check and machine preflight passed; mixed Korean/Japanese prompt makes STT mismatch unreliable; not native-speaker review. |

| question 4 |  | 近くの人に声をかけ___て、すぐ警察に来ました。 |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ef3004f3-bca8-4621-b7aa-520cdde4e823/question-4.mp3) | PASS | Delegated AI/STT PASS: URL check and machine preflight passed; mixed Korean/Japanese prompt makes STT mismatch unreliable; not native-speaker review. |

| question 5 |  | '자전거를 도난당했습니다'를 배열하세요. |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ef3004f3-bca8-4621-b7aa-520cdde4e823/question-5.mp3) | PASS | Delegated AI/STT PASS: URL check and machine preflight passed; mixed Korean/Japanese prompt makes STT mismatch unreliable; not native-speaker review. |

## Result

Human verdict is pending. This packet closes only the preparation step for
representative full-chapter playback review.
