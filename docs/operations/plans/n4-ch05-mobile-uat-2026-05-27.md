# N4 Chapter 5 Mobile Target-Runtime UAT

> Date: 2026-05-27
> Scope: HN4-017 representative learner-facing flow from the N4 CH05 controlled
> pilot wave
> Status: PASS on iPhone 17 Pro Simulator, iOS 26.5
> Boundary: simulator target-runtime UAT; not physical-device release smoke and
> not native-speaker review

## Runtime

| Field | Value |
|---|---|
| App | `apps/mobile` Flutter debug run |
| Device | iPhone 17 Pro Simulator |
| OS | iOS 26.5 |
| API | `https://harukoto-api-842843944454.asia-northeast3.run.app` |
| Lesson | `HN4-017` / `c66e28bc-0e77-4989-83d4-148611906230` |
| Title | `주말에 이것저것 해요` |
| Grammar | `たり〜たりする` / `〜たり〜たりする` |
| Auth | Existing logged-in learner session; raw auth material intentionally omitted |

ASSUMPTION: Simulator target-runtime UAT is sufficient for the CH05
controlled-pilot mobile gate because this check validates learner navigation,
target API integration, TTS entry, answer submit/result, retry, and
return-to-learning behavior. Physical iPhone rerun remains useful before
treating this as release-device smoke.

## Preflight / Launch

| Check | Result |
|---|---|
| iOS runtime | PASS: `iPhone 17 Pro` simulator detected on iOS 26.5 |
| Flutter device detection | PASS: simulator device `26364A8F-FD6C-485C-B8FD-5FAB364BF965` detected and booted |
| Physical device visibility | INFO: `Kun Woo's iPhone` on iOS 26.5 was visible over wireless, but was not used for this simulator gate |
| Standalone remote API smoke script | WARN: `scripts/smoke_remote_lesson_api.py` was not usable in this shell because `HARUKOTO_SMOKE_EMAIL` and `HARUKOTO_SMOKE_PASSWORD` were absent |
| Mobile launch | PASS: direct route launch opened HN4-017 through the logged-in simulator session |

The standalone smoke-script warning is not treated as a mobile runtime failure:
the running app used the existing learner session and target API DIO logs
showed the HN4-017 detail, start, TTS, and submit calls returning `200`.

## Scenario Evidence

| Step | Result | Evidence |
|---|---|---|
| HN4-017 detail | PASS | Detail route showed lesson 17, `〜たり〜たりする`, 6 vocabulary items, and topic `주말 계획을 친구에게 설명함`; screenshot `/tmp/n4-ch05-uat-hn4-017-detail-20260527.png` |
| Lesson start | PASS | `학습 시작하기` opened the learner lesson flow and `POST /start` returned `200` |
| Vocabulary TTS entry | PASS | First vocabulary speaker action called `POST /api/v1/vocab/tts` and returned `200` with no visible error |
| Dialogue/TTS entry | PASS | Dialogue step showed script content; first script speaker action called `POST /script-lines/0/tts` and returned `200`; screenshot `/tmp/n4-ch05-uat-hn4-017-dialogue-20260527.png` |
| Understanding checks | PASS | Four recognition checks were answered correctly with immediate progression |
| Matching/reorder | PASS | Matching completed, then reorder selected `掃除をしたり` / `洗濯をしたり` / `します` |
| Submit/result | PASS | Submit returned `200`; result screen showed `100%`, `5/5`, and `오늘 배운 7개를 복습 일정에 넣었어요`; screenshot `/tmp/n4-ch05-uat-hn4-017-result-20260527.png` |
| Retry | PASS | `다시 풀기` returned to the HN4-017 lesson detail/start surface; screenshot `/tmp/n4-ch05-uat-hn4-017-retry-return-20260527.png` |
| Return to learning | PASS | Closing the lesson detail returned to the Learning tab without crash; screenshot `/tmp/n4-ch05-uat-return-learning-20260527.png` |

## Log Evidence

Runtime log stream evidence included:

- `GET /api/v1/lessons/c66e28bc-0e77-4989-83d4-148611906230` -> `200`.
- `POST /api/v1/lessons/c66e28bc-0e77-4989-83d4-148611906230/start` -> `200`.
- `POST /api/v1/vocab/tts` -> `200`.
- `POST /api/v1/lessons/c66e28bc-0e77-4989-83d4-148611906230/script-lines/0/tts` -> `200`.
- `LessonPilotEvent(lesson_step_completed, {lessonId: c66e28bc-0e77-4989-83d4-148611906230, step: contextPreview, skipped: false})`.
- `LessonPilotEvent(lesson_step_completed, {lessonId: c66e28bc-0e77-4989-83d4-148611906230, step: vocabLearning, skipped: false})`.
- `LessonPilotEvent(lesson_step_completed, {lessonId: c66e28bc-0e77-4989-83d4-148611906230, step: grammarLearning, skipped: false})`.
- `LessonPilotEvent(lesson_step_completed, {lessonId: c66e28bc-0e77-4989-83d4-148611906230, step: recognition, skipped: false})`.
- `LessonPilotEvent(lesson_step_completed, {lessonId: c66e28bc-0e77-4989-83d4-148611906230, step: matching, skipped: false})`.
- `LessonPilotEvent(lesson_step_completed, {lessonId: c66e28bc-0e77-4989-83d4-148611906230, step: sentenceReorder, skipped: false})`.
- `POST /api/v1/lessons/c66e28bc-0e77-4989-83d4-148611906230/submit` -> `200`.
- `LessonPilotEvent(lesson_submitted, {lessonId: c66e28bc-0e77-4989-83d4-148611906230, outcome: success, answerCount: 5, status: COMPLETED, scoreCorrect: 5, scoreTotal: 5, srsItemsRegistered: 7})`.
- `LessonPilotEvent(lesson_completed, {lessonId: c66e28bc-0e77-4989-83d4-148611906230, scoreCorrect: 5, scoreTotal: 5, srsItemsRegistered: 7})`.
- `LessonPilotEvent(lesson_retry_clicked, {lessonId: c66e28bc-0e77-4989-83d4-148611906230})`.

Raw request auth material is intentionally omitted. The runtime DIO logs showed
`Authorization: <redacted>`, not raw bearer tokens.

## Boundaries

- This run covers one representative CH05 lesson, not all five CH05 lessons.
- The standalone remote API smoke helper was not rerun in this shell because
  smoke-test learner credentials were not present, but the app runtime itself
  exercised the target API detail/start/TTS/submit endpoints for HN4-017.
- This run does not replace physical iPhone release smoke.
- This run does not replace native-speaker curriculum or audio review.

## Result

HN4-017 representative CH05 mobile target-runtime UAT passes for controlled
pilot exposure. Remaining gates are pilot-feedback monitoring and
native-speaker review before wider quality claims.
