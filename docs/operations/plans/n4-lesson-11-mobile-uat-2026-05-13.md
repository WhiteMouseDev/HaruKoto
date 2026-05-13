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
| Submit/result path | PASS | Completed vocab, grammar, dialogue, recognition, matching, and sentence-reorder steps; the first simulator submit reached the result screen with `80%` / `4/5 정답`, review cards, and a visible `다시 풀기` retry action |
| Retry affordance | PASS | Result-screen retry action returned to the HN4-011 lesson detail/start screen |
| Retry correct path submit | PASS | Retried the lesson from the detail screen and submitted the corrected recognition, cloze, matching, and sentence-reorder path; result screen showed `100%` / `5/5 정답` |
| Progress persistence | PASS | Returning from the result screen landed back on the learning surface without crash; the prior detail screen and final result screen both preserved the completed HN4-011 lesson state |

## Local Evidence Artifacts

- `/tmp/hn4-after-reorder-submit.png`: first simulator submit result screen,
  `80%` / `4/5 정답`, review cards, and `다시 풀기`.
- `/tmp/hn4-after-retry-click2.png`: retry action returned to the HN4-011
  lesson detail/start screen.
- `/tmp/hn4-retry-result-100.png`: retry submit result screen, `100%` /
  `5/5 정답`.
- `/tmp/hn4-after-close-detail.png`: return to the learning surface after the
  final result.

## Boundary

- This UAT used an existing learner account with prior HN4-011 progress, so
  repeated submits reported `srsItemsRegistered=0`. The temporary-user API write
  smoke already verified fresh-path SRS registration with 6 items per path.
- Simulator retry coverage in this run verifies user-visible retry behavior and
  successful retry submit. The deliberate all-wrong `0/5` path remains covered
  by the temporary-user API write smoke, not by this simulator run.
- This UAT does not replace native-speaker curriculum review or human audio
  quality review.
- This UAT does not cover full question-prompt/batch TTS generation.

## Result

HN4-011 learner-facing mobile runtime UAT passes for the second controlled
limited-pilot wave. Broad/full N4 rollout remains on HOLD until pilot feedback,
native-speaker review when available, and full prompt/batch TTS audio QA are
complete.
