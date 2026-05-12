# N4 Pilot Delegated Curriculum Review Handoff

> Date: 2026-05-12
> Scope: first N4 pilot batch, 2 chapters / 10 lessons
> Status: delegated AI curriculum review approved; target-runtime N4 mobile UAT
> passed; limited learner pilot approved

## Source of Truth

Curriculum reviewers should use the machine-readable packet as the edit source:

- `packages/database/data/curriculum/lesson-human-review/n4-pilot-review.json`

Because no human Japanese curriculum expert is currently available, the user
explicitly delegated this review to Codex on 2026-05-12. This document records
that delegated AI curriculum approval separately from native-speaker human
validation.

Supporting source files:

- `packages/database/data/lessons/n4/ch01-core-directions-and-judgment.json`
- `packages/database/data/lessons/n4/ch02-reasons-conditions-and-intent.json`
- `packages/database/data/curriculum/tts-target-manifest.json`

The packet is a review queue and approval record. Each `reviewRows[]` item
started as `PENDING`; the current N4 rows are `APPROVED` by the delegated AI
curriculum reviewer. Future reviewers should set `reviewerDecision` to one of:

- `APPROVED`: lesson can proceed to target-runtime mobile UAT.
- `NEEDS_EDIT`: lesson is close, but the reviewer found a concrete issue.
- `REJECTED`: lesson should not be used in this pilot batch.

For `NEEDS_EDIT` or `REJECTED`, `reviewerNotes` must include the reason and the
field or lesson area that needs correction.

## Review Standard

Approve only if all of the following are acceptable for Korean-speaking N4
learners:

- Grammar order and prerequisite knowledge fit an early N4 pilot.
- Japanese dialogue is natural and uses the target grammar in a clear context.
- Korean translation, explanation, and distractors are accurate.
- Question answers and explanations match prompt/options/token order.
- Vocabulary links are appropriate for the lesson context.
- TTS targets cover all script lines and question prompts.
- The content is HaruKoto-authored. Paid PDFs are only topic/order references.

Do not approve a lesson only because automated validation passes. Automated
validation proves shape and reference integrity, not pedagogy.

## Lesson Review Queue

| Lesson | Title | Grammar | Vocabulary | Coverage | Decision |
|---|---|---|---|---|---|
| HN4-001 | 이름을 쓰세요 | 42 `〜なさい` | 規則, 注意, 授業, 叱る, 丁寧 | 4 script / 5 questions / TTS 4+5 | APPROVED |
| HN4-002 | 일찍 쉬는 편이 좋아요 | 43 `〜たほうがいい` | 心配, 安心, 治る, 相談, 理由 | 4 script / 5 questions / TTS 4+5 | APPROVED |
| HN4-003 | 늦을지도 몰라요 | 41 `〜かもしれない` | 台風, 地震, 間に合う, 心配, 最近 | 4 script / 5 questions / TTS 4+5 | APPROVED |
| HN4-004 | 달릴 수밖에 없어요 | 48 `〜しかない` | 足りる, 諦める, 決める, 準備, 予定 | 4 script / 5 questions / TTS 4+5 | APPROVED |
| HN4-005 | 한자를 찾아볼 수 있어요 | 44 `可能形` | 運転, 翻訳, 調べる, 申し込む, 自信 | 4 script / 5 questions / TTS 4+5 | APPROVED |
| HN4-006 | 호수의 깊이를 말해요 | 45 `〜さ` | 正しい, 深い, 浅い, 太い, 細い | 4 script / 5 questions / TTS 4+5 | APPROVED |
| HN4-007 | 참가하려고 생각해요 | 46 `意向形` | 参加する, 送る, 集める, 紹介する, 決める | 4 script / 5 questions / TTS 4+5 | APPROVED |
| HN4-008 | 회의가 길었던 거예요 | 47 `〜のだ` | 理由, 原因, 返事, 連絡, 相談 | 4 script / 5 questions / TTS 4+5 | APPROVED |
| HN4-009 | 면접을 위해 준비해요 | 17 `〜ために` | 就職, 面接, 準備, 技術, 教育 | 4 script / 5 questions / TTS 4+5 | APPROVED |
| HN4-010 | 누르면 바뀌어요 | 40 `〜と (条件)` | 信号, 交差点, 壊れる, 届く, 乾く | 4 script / 5 questions / TTS 4+5 | APPROVED |

## Focus Questions

Review the full JSON packet for every lesson. These lesson-specific questions
were answered during delegated AI curriculum approval:

- HN4-001: Does `〜なさい` read as a teacher/classroom command without teaching
  it as generally "soft" Korean advice?
- HN4-002: Are the health-advice examples natural and not overstated?
- HN4-003: Does `〜かもしれない` consistently express uncertainty rather than a
  firm prediction?
- HN4-004: Does `〜しかない` clearly convey "no other practical option" without
  drifting into simple preference?
- HN4-005: Is the potential-form coverage sufficient for a first N4 pilot
  lesson even though it does not teach every conjugation class exhaustively?
- HN4-006: Are the `〜さ` examples natural for degree/measurement nouns?
- HN4-007: Does `意向形 + と思っています` fit the intended N4 introduction level?
- HN4-008: Does the `〜のだ / んです` explanation show reason-giving nuance
  clearly enough for Korean learners?
- HN4-009: `〜ために` can remain in lesson 9 as a purpose-expression bridge
  before conditional `〜と`; broader ordering refinements are accepted as a
  non-blocking P2 curriculum follow-up.
- HN4-010: Does every `〜と` example describe a natural/automatic result rather
  than a speaker's intentional next action?

HN4-010 was corrected before this handoff: `荷物が届くと、連絡します。` was replaced
with `荷物が届くと、メールが来ます。` so the example follows the automatic-result
constraint of `〜と`.

## Delegated AI Curriculum Review - 2026-05-12

Codex first performed an AI-assisted pre-review to reduce obvious reviewer
burden, then completed the curriculum decision after the user confirmed no
human expert was available and delegated the review to Codex. This is delegated
AI curriculum approval, not native-speaker human approval.

Review fixes applied before approval:

- HN4-001: changed `〜なさい` metadata from "부드러운 명령" to "직접적인
  지시" so learners do not read it as soft advice.
- HN4-002: replaced `病院に相談する` with `医者に相談する` in script/question
  surfaces for more natural advice language.
- HN4-006: corrected the `浅さ` Korean translation and replaced the awkward
  `道の太さ` context with `線の太さ`.
- HN4-008: changed the Korean rendering of `会議が長かったのです` from the
  overly literal "회의가 길었던 것입니다" to "회의가 길었던 거예요".

All 10 packet rows are now `APPROVED` for target-runtime N4 mobile UAT. HN4-009
sequencing is explicitly accepted as non-blocking for this pilot because the
lesson is internally coherent and introduces a useful purpose-expression bridge.
Target-runtime mobile happy-path and wrong-answer retry UAT passed after this
handoff. The learner rollout decision is LIMITED GO for controlled pilot
exposure only; broad/full N4 rollout remains HOLD. If a native-speaker
curriculum reviewer becomes available later, treat that review as a
higher-authority P1/P2 refinement source before broad rollout.

## Gate Commands

Run these after reviewer decisions are entered:

```bash
pnpm --filter @harukoto/database lessons:review:validate
pnpm --filter @harukoto/database lessons:review:gate -- --level N4
```

Expected current state:

- `lessons:review:validate` should pass with all rows `APPROVED`.
- `lessons:review:gate -- --level N4` should pass with 10 `APPROVED` rows and
  0 blockers.

## Closeout Rule

Delegated AI curriculum review is complete for the current no-human-expert path
because:

- all 10 rows are `APPROVED`,
- `lessons:review:gate -- --level N4` passes,
- operational review is updated with reviewer/date/evidence,
- accepted P2 curriculum concerns are explicitly listed,
- the approval record states that this is not native-speaker human approval.

Mobile N4 UAT has run from the approved packet, and the learner rollout decision
is recorded in `docs/operations/plans/n4-pilot-learner-rollout-decision-2026-05-12.md`.
Do not use this handoff alone to broaden N4 beyond controlled pilot exposure.
