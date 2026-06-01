# N4 CH06 Mobile Target-Runtime UAT - 2026-06-01

## Result

Status: PASS for representative N4 CH06 mobile target-runtime happy path.

Scope: `N4-CH06` representative lesson `HN4-022`
(`b9250446-d707-46d4-a461-66e273b8534e`) on iPhone 17 Pro Simulator,
iOS 26.5.

ASSUMPTION: This is simulator target-runtime proof for the learner-facing
mobile flow. It is not physical-device proof, native-speaker approval, or
formal human curriculum approval.

## Runtime

- Device: iPhone 17 Pro Simulator, iOS 26.5
  (`26364A8F-FD6C-485C-B8FD-5FAB364BF965`)
- App bundle: `com.harukoto.app`
- Launch path:
  `flutter run -d 26364A8F-FD6C-485C-B8FD-5FAB364BF965 --dart-define-from-file=.env --route /study/lessons/b9250446-d707-46d4-a461-66e273b8534e`
- API base: `https://harukoto-api-842843944454.asia-northeast3.run.app`
- Auth: existing logged-in simulator session; secrets stayed in ignored local
  `.env` files and were not committed.

## Evidence

| Gate | Result | Evidence |
|---|---:|---|
| Lesson detail route | PASS | Direct route opened HN4-022 detail with title `후배에게 지도를 그려 줘요`, lesson 22, 12 minutes, vocab preview 5, grammar `〜てあげる`, and start CTA. |
| Lesson detail API | PASS | `GET /api/v1/lessons/b9250446-d707-46d4-a461-66e273b8534e` returned 200. |
| Start API | PASS | `POST /api/v1/lessons/b9250446-d707-46d4-a461-66e273b8534e/start` returned 200 and emitted `lesson_started` with recognition 4 and reorder 1. |
| Vocab TTS | PASS | Speaker control on the vocab card called `POST /api/v1/vocab/tts` and returned 200. |
| Grammar and dialogue | PASS | Vocab step, grammar step, and 4-line dialogue rendered correctly in the simulator. |
| Script-line TTS | PASS | Speaker control on dialogue line 0 called `POST /api/v1/lessons/b9250446-d707-46d4-a461-66e273b8534e/script-lines/0/tts` and returned 200. |
| Recognition questions | PASS | Four recognition/cloze questions accepted the expected answers and emitted `lesson_step_completed` for `recognition`. |
| Matching | PASS | Vocab matching completed and emitted `lesson_step_completed` for `matching`. |
| Sentence reorder | PASS | Reorder answer `後輩に` / `地図を` / `描いてあげました` completed and emitted `lesson_step_completed` for `sentenceReorder`. |
| Submit/result | PASS | `POST /api/v1/lessons/b9250446-d707-46d4-a461-66e273b8534e/submit` returned 200; result screen showed 100%, 5/5 correct, and 6 SRS items registered. |
| Retry | PASS | Result-screen `다시 풀기` emitted `lesson_retry_clicked` and returned to the HN4-022 lesson detail screen. |
| Return to learning | PASS | Closing the detail screen returned to the N4 learning list; `/lessons/chapters?jlptLevel=N4` returned 200 and telemetry reported 6 chapters / 26 lessons. |

## Screenshots

- Detail: `/tmp/n4-ch06-uat-hn4-022-detail-20260601.png`
- Dialogue: `/tmp/n4-ch06-uat-hn4-022-dialogue-20260601.png`
- Result: `/tmp/n4-ch06-uat-hn4-022-result-20260601.png`
- Retry return: `/tmp/n4-ch06-uat-hn4-022-retry-return-20260601.png`
- Learning list return: `/tmp/n4-ch06-uat-return-learning-20260601.png`

## Observed Log Excerpts

```text
GET /api/v1/lessons/b9250446-d707-46d4-a461-66e273b8534e -> 200
POST /api/v1/lessons/b9250446-d707-46d4-a461-66e273b8534e/start -> 200
POST /api/v1/vocab/tts -> 200
POST /api/v1/lessons/b9250446-d707-46d4-a461-66e273b8534e/script-lines/0/tts -> 200
POST /api/v1/lessons/b9250446-d707-46d4-a461-66e273b8534e/submit -> 200
LessonPilotEvent(lesson_submitted, scoreCorrect: 5, scoreTotal: 5, srsItemsRegistered: 6)
LessonPilotEvent(lesson_completed, scoreCorrect: 5, scoreTotal: 5, srsItemsRegistered: 6)
LessonPilotEvent(lesson_retry_clicked, lessonId: b9250446-d707-46d4-a461-66e273b8534e)
GET /api/v1/lessons/chapters?jlptLevel=N4 -> 200
LessonPilotEvent(lesson_list_viewed, chapterCount: 6, lessonCount: 26)
```

## Boundary

- This proves the representative CH06 learner-facing mobile path on simulator:
  detail, start, vocab TTS, dialogue TTS, quiz, matching, sentence reorder,
  submit/result, retry, and return-to-learning.
- This does not prove every CH06 lesson on mobile. The remote HTTP smoke already
  covers HN4-022 through HN4-026 list/detail shape; full per-lesson mobile UAT
  can be added if pilot feedback indicates lesson-specific issues.
- This does not replace native-speaker/formal human approval.

## Next Gates

1. DONE on 2026-06-01 for the first CH06 aggregate pilot-feedback baseline.
2. Continue CH06 pilot-feedback refreshes over time.
3. Keep native-speaker/human approval as a separate post-pilot quality gate.
