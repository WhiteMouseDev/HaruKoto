# N4 Pilot Human Audio QA Packet - Chapter 3

> Date: 2026-05-13
> Scope: N4 chapter 3 `성질과 정도 표현`, HN4-011
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
| Generated at | `2026-05-13T05:50:30.393186+00:00` |
| Lessons | 1 |
| Script-line targets | 4 |
| Question-prompt targets | 5 |
| Total review targets | 9 |
| Missing audio URLs | 0 |
| Failed URL checks | 0 |

## Machine Preflight Context

Full N4 automated audio preflight passed 99 / 99 generated TTS targets with no
machine blockers. It found 11 non-blocking `HIGH_SILENCE_RATIO` warnings across
question prompts. Chapter 3 warning item to prioritize while listening:

- `HN4-011 question:3`

## Review Items

### HN4-011 - 종이의 두께를 비교해요

| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| script 0 | キム | ノートを選ぶ前に、紙の厚さを比べています。 | 노트를 고르기 전에 종이의 두께를 비교하고 있습니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/script-line-0.mp3) | PENDING |  |

| script 1 | 佐藤 | ノートの厚さが違います。 | 노트의 두께가 다릅니다. | gemini / gemini-2.5-flash-preview-tts | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/script-line-1-regen-20260518T025500Z.mp3) | PASS | Delegated AI-assisted post-regeneration PASS: MP3 probe passed and STT matched source exactly; not native-speaker review. |

| script 2 | キム | はい。この紙の柔らかさも確認します。 | 네. 이 종이의 부드러운 정도도 확인합니다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/script-line-2.mp3) | PENDING |  |

| script 3 | 佐藤 | 厚さと柔らかさを比べて選びましょう。 | 두께와 부드러운 정도를 비교해서 고릅시다. | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/script-line-3.mp3) | PENDING |  |

| question 1 |  | 厚い의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/question-1.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 2 |  | 柔らかい의 뜻은? |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/question-2.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 3 |  | 紙の厚___を比べます。 (종이의 두께를 비교합니다.) |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/question-3.mp3) | PENDING |  |

| question 4 |  | この紙の柔らか___を確認します。 (이 종이의 부드러운 정도를 확인합니다.) |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/question-4.mp3) | PASS | Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review. |

| question 5 |  | '종이의 두께를 비교합니다'를 배열하세요. |  | elevenlabs / eleven_multilingual_v2 | ok | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/question-5.mp3) | PASS | Delegated AI-assisted PASS: machine pass + no parsed machine/STT review signal; not native-speaker review. |

## Result

Human verdict is pending. This packet closes only the preparation step for this
chapter's playback review.
