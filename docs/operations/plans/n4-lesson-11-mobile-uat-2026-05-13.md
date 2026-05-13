# N4 Lesson 11 Mobile UAT Run

> Date: 2026-05-13
> Scope: HN4-011 learner-facing mobile lesson flow
> Status: PASS on iPhone 17 Pro Simulator

## Runtime

| Field | Value |
|---|---|
| App | `apps/mobile` Flutter debug run |
| Device | iPhone 17 Pro Simulator |
| OS | iOS 26.4 |
| API | `https://harukoto-api-842843944454.asia-northeast3.run.app` |
| Lesson | `HN4-011` / `03cfdb15-c916-450c-8168-9052f3e754aa` |
| Title | `종이의 두께를 비교해요` |
| Auth | Existing test learner session; raw auth material intentionally omitted |

ASSUMPTION: Simulator UAT is sufficient for the HN4-011 controlled-pilot
runtime gate because this check validates learner navigation, API integration,
TTS playback entry, answer submission, retry, and result handling. Physical
iPhone rerun remains useful before treating this as release-device smoke.

## Scenario Evidence

| Step | Result | Evidence |
|---|---|---|
| Lesson discovery | PASS | Home -> `학습` -> N4 -> Ch.3 exposed `HN4-011` and opened the lesson detail screen |
| Lesson start | PASS | `POST /api/v1/lessons/03cfdb15-c916-450c-8168-9052f3e754aa/start` returned `200` |
| Dialogue TTS entry | PASS | Dialogue speaker action called `POST /api/v1/lessons/03cfdb15-c916-450c-8168-9052f3e754aa/script-lines/0/tts` and returned `200` |
| Correct path submit | PASS | Completed vocab, grammar, dialogue, recognition, matching, and sentence-reorder steps; submit returned `200`, `scoreCorrect=5`, `scoreTotal=5`, `status=COMPLETED` |
| Wrong-answer retry path | PASS | From retry flow, intentionally submitted wrong recognition/cloze/reorder answers; submit returned `200`, `scoreCorrect=0`, `scoreTotal=5`, `status=COMPLETED` |
| Retry affordance | PASS | Result-screen retry action fired and returned to the HN4-011 lesson detail/start screen |

## Boundary

- This UAT used an existing learner account with prior HN4-011 progress, so
  repeated submits reported `srsItemsRegistered=0`. The temporary-user API write
  smoke already verified fresh-path SRS registration with 6 items per path.
- This UAT does not replace native-speaker curriculum review or human audio
  quality review.
- This UAT does not cover full question-prompt/batch TTS generation.

## Result

HN4-011 learner-facing mobile runtime UAT passes for the second controlled
limited-pilot wave. Broad/full N4 rollout remains on HOLD until pilot feedback,
native-speaker review when available, and full prompt/batch TTS audio QA are
complete.
