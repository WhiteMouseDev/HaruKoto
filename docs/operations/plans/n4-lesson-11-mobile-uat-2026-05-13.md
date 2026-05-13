# N4 Lesson 11 Mobile UAT Probe

> Date: 2026-05-13
> Scope: HN4-011 target mobile runtime probe
> Status: PARTIAL PASS for lesson entry and learning-step rendering; submit-path UAT still pending

## Boundary

This run verifies that HN4-011 is reachable in the iPhone 17 Pro Simulator and
that the learner flow can enter the published lesson content without crashing.

It does not close the full target mobile UAT gate. Correct-path submit and
wrong-answer retry evidence still need a clean end-to-end run from lesson start
through result/progress persistence.

ASSUMPTION: Simulator evidence is sufficient to record target-runtime rendering
coverage, but not sufficient to replace the requested full mobile UAT submit
paths.

## Environment

| Field | Value |
|---|---|
| Device | iPhone 17 Pro Simulator |
| OS | iOS 26.4 |
| Lesson | `HN4-011` |
| Title | `종이의 두께를 비교해요` |
| Backend target | local configured API used by the running mobile debug build |

## Evidence

Observed through `xcrun simctl io ... screenshot` and Simulator coordinate
automation:

| Step | Result | Evidence |
|---|---|---|
| Study tab route | PASS | N4 chapter list rendered and HN4-011 was reachable from the Study tab |
| Lesson detail | PASS | HN4-011 detail rendered with title, lesson 11 badge, duration, objective, vocabulary preview, grammar card, and `학습 시작하기` CTA |
| Word study continuation | PASS | Previously started HN4-011 state resumed on the word-study step and advanced with `다음 단어` |
| Dialogue reading | PASS | Dialogue/scene reading screen rendered with script lines and speaker controls |
| In-flow quiz cards | PASS | Vocabulary MCQ and grammar cloze cards rendered with HN4-011 content |
| Matching step | PASS | Word matching screen rendered and accepted correct pair selections |
| Sentence reorder step | PASS with caveat | Sentence reorder screen rendered for `종이의 두께를 비교합니다`; a coordinate-click mistake selected the wrong token during automation, so this does not count as clean correct-path submit evidence |

Captured screenshots were saved under `/tmp/hn4-*.png` during the probe. They
are local run artifacts, not committed release assets.

## Result

HN4-011 passes the mobile target-runtime rendering and navigation probe. The
lesson can be opened on the Simulator, shows the expected learner-facing content,
and reaches the exercise steps without a visible crash.

The remaining HN4-011 mobile UAT gate is still open:

1. Clean correct-path run through final result/progress persistence.
2. Wrong-answer retry path on the same target runtime.
