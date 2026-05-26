# N4 Chapter 4 Mobile Target-Runtime UAT

> Date: 2026-05-26
> Scope: HN4-012 representative learner-facing flow from the N4 CH04 controlled
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
| Lesson | `HN4-012` / `d4633ddc-7d4a-4c57-ab33-79dc472d9905` |
| Title | `이유를 나란히 말해요` |
| Grammar | `し` / `〜し` |
| Auth | Existing logged-in learner session; raw auth material intentionally omitted |

ASSUMPTION: Simulator target-runtime UAT is sufficient for the controlled-pilot
mobile gate because this check validates learner navigation, API integration,
TTS entry, answer submit/result, retry, and return-to-learning behavior.
Physical iPhone rerun remains useful before treating this as release-device
smoke.

## Preflight / Launch

| Check | Result |
|---|---|
| iOS runtime | PASS: `iOS 26.5 (26.5 - 23F77)` installed |
| Flutter device detection | PASS: `iPhone 17 Pro` simulator detected on iOS 26.5 |
| First launch | WARN: the first `flutter run ... --route=/study` build completed, but attach failed with `Application launch ... did not return a process handle` |
| Relaunch | PASS: simulator reboot plus direct lesson route launch opened HN4-012 |

The first launch warning is treated as a local simulator pending-launch state,
not an app runtime failure, because the same build launched and completed the
UAT flow after the simulator reboot.

## Scenario Evidence

| Step | Result | Evidence |
|---|---|---|
| Login/session | PASS | User logged in and the app reached the Home surface; screenshot `/tmp/n4-ch04-uat-home-20260526.png` |
| N4 lesson list API | PASS | Runtime logs recorded `GET /api/v1/lessons/chapters?jlptLevel=N4` as `200`, with mobile telemetry reporting `chapterCount: 4` and `lessonCount: 16` |
| HN4-012 detail | PASS | Detail route showed lesson 12, `〜し`, 6 vocabulary items, and topic `수업을 고른 이유를 친구에게 설명함`; screenshot `/tmp/n4-ch04-uat-hn4-012-detail-20260526.png` |
| Lesson start | PASS | `학습 시작하기` opened the learner lesson flow |
| Vocabulary TTS entry | PASS | First vocabulary speaker action entered a loading/playback state with no visible error |
| Dialogue/TTS entry | PASS | Dialogue step showed four script lines; first script speaker action entered a loading/playback state with no visible error; screenshot `/tmp/n4-ch04-uat-hn4-012-dialogue-20260526.png` |
| Understanding checks | PASS | Vocab and grammar checks were answered correctly with immediate progression |
| Matching/reorder | PASS | Matching completed, then reorder selected `この授業は / 説明が / 丁寧だし / 安心です`; screenshot `/tmp/n4-ch04-uat-hn4-012-reorder-20260526.png` |
| Submit/result | PASS | Submit returned `200`; result screen showed `100%`, `5/5`, and `오늘 배운 4개를 복습 일정에 넣었어요`; screenshot `/tmp/n4-ch04-uat-hn4-012-result-20260526.png` |
| Retry | PASS | `다시 풀기` returned to the HN4-012 lesson detail/start surface; screenshot `/tmp/n4-ch04-uat-hn4-012-retry-return-20260526.png` |
| Return to learning | PASS | Closing the lesson returned to the N4 learning list without crash; screenshot `/tmp/n4-ch04-uat-return-learning-20260526.png` |

## Log Evidence

Runtime log stream evidence included:

- `GET /api/v1/lessons/review/summary?jlptLevel=N4` -> `200`.
- `GET /api/v1/lessons/chapters?jlptLevel=N4` -> `200`.
- `LessonPilotEvent(lesson_list_viewed, {jlptLevel: N4, ... chapterCount: 4, lessonCount: 16, ...})`.
- `POST /api/v1/lessons/d4633ddc-7d4a-4c57-ab33-79dc472d9905/submit` -> `200`.
- `LessonPilotEvent(lesson_submitted, {lessonId: d4633ddc-7d4a-4c57-ab33-79dc472d9905, outcome: success, answerCount: 5, status: COMPLETED, scoreCorrect: 5, scoreTotal: 5, srsItemsRegistered: 4})`.
- `LessonPilotEvent(lesson_completed, {lessonId: d4633ddc-7d4a-4c57-ab33-79dc472d9905, scoreCorrect: 5, scoreTotal: 5, srsItemsRegistered: 4})`.
- `LessonPilotEvent(lesson_retry_clicked, {lessonId: d4633ddc-7d4a-4c57-ab33-79dc472d9905})`.

Raw request auth material is intentionally omitted. The runtime DIO logs showed
`Authorization: <redacted>`, not raw bearer tokens.

## Boundaries

- This run covers one representative CH04 lesson, not all five CH04 lessons.
- Direct visual scroll to CH04 in the full lesson list was not completed during
  the run, but mobile telemetry confirmed the N4 list as 4 chapters / 16
  lessons and the mobile router/API loaded HN4-012 successfully.
- This run does not replace physical iPhone release smoke.
- This run does not replace native-speaker curriculum or audio review.

## Result

HN4-012 representative CH04 mobile target-runtime UAT passes for controlled
pilot exposure. Remaining gates are release-device smoke before any
physical-device claim, pilot monitoring, and native-speaker review before wider
quality claims.
