# N4 Full Coverage Plan

> Date: 2026-05-12
> Scope: N4 pilot aftercare and lesson 11+ promotion planning
> Status: HN4-011 promoted to limited PILOT; broad/full N4 rollout remains HOLD

## Decision

Do not promote N4 as a complete course yet.

The official N4 source set is now 11 lessons. HN4-001 through HN4-010 have the
earlier controlled-pilot mobile/rollout decision; HN4-011 has a second
limited-pilot publish-status decision, configured DB seed apply/check,
published list/detail plus start/submit API smoke, HN4-011 script-line and
question-prompt TTS audio QA, simulator mobile UAT, and a first aggregate
pilot-feedback baseline. The second pilot wave is
runtime-verified for controlled exposure, but broad/full N4 rollout remains on
HOLD. The next automated workstream is not broad rollout; it is closing the
remaining N4 foundation queue without padding a chapter with unresolved
contrast topics.

ASSUMPTION: The HN4-011 second limited pilot decision authorizes controlled
runtime exposure after configured DB seed apply, API smoke, HN4-011 lesson TTS
audio QA, simulator mobile UAT, and first aggregate feedback monitoring.
Physical-device smoke is still useful before release-artifact claims.

## Current Inventory

| Source | Current count | Notes |
|---|---:|---|
| N4 vocabulary rows | 944 | `packages/database/data/vocabulary/n4-words.json` |
| N4 grammar rows | 49 | `packages/database/data/grammar/n4-grammar.json` |
| N4 cloze rows | 60 | `packages/database/data/cloze/n4-cloze.json` |
| N4 sentence-arrange rows | 60 | `packages/database/data/sentence-arrange/n4-arrange.json` |
| Official N4 lesson chapters | 3 | `packages/database/data/lessons/n4/*.json`; all 3 chapters are `PILOT` |
| Official N4 lessons | 11 | HN4-001 through HN4-011; HN4-011 simulator UAT passed |
| Official N4 script lines | 44 | 4 reading script lines per lesson |
| Official N4 lesson questions | 55 | 5 runtime-safe questions per lesson |
| Official N4 vocabulary links | 55 | 50 unique vocabulary orders |
| Official N4 grammar links | 11 | 10 unique grammar orders; HN4-006 and HN4-011 both use order 45 `〜さ` |

## Topic Coverage Snapshot

| Contract | Count | Current meaning |
|---|---:|---|
| N4 curriculum topics | 39 | Topic inventory derived from reference coverage |
| Covered N4 topics | 29 | Pilot-covered topics are reflected in the staging contract through HN4-011 |
| Partial N4 topics | 7 | Remaining N4 foundation queue; needs split, contrast, or runtime-support decision |
| Missing N4 topics | 3 | 1 N4 foundation topic plus 2 later register/business topics |
| N4 foundation priorities | 8 | Remaining candidate queue for WAVE_2_N4_FOUNDATION |
| P1 N4 foundation priorities | 7 | Higher-risk partial topics, mostly runtime-support blockers |
| P2 N4 foundation priorities | 1 | `きっと` remains blocked on adverb scope, TTS, and runtime-safe question shape |

The staging coverage contract has now been synchronized to the approved pilot
runtime truth. HN4-001 through HN4-008 are marked as covered where the pilot
lesson fully represents the topic. HN4-011 now marks
`topic-i-adjective-nominalization` as covered. HN4-009 and HN4-010 remain
partial because `ために` and `〜と` still need contrast/follow-up decisions beyond
the current pilot lesson.

This sync is not broad rollout approval. It only makes the planning contract
usable for selecting true lesson 11+ candidates.

## Coverage Contract Sync Result

| Area | Before sync | After HN4-011 promotion |
|---|---:|---:|
| N4 covered topics | 20 | 29 |
| N4 partial topics | 8 | 7 |
| N4 missing topics | 11 | 3 |
| N4 foundation priority rows | 17 | 8 |
| N4 P1 priority rows | 8 | 7 |
| N4 P2 priority rows | 9 | 1 |

Topics marked covered and removed from the lesson 11+ priority queue:

- `topic-nasai` -> HN4-001
- `topic-ta-hou-ga-ii` -> HN4-002
- `topic-kamoshirenai` -> HN4-003
- `topic-shika-nai` -> HN4-004
- `topic-potential-form` -> HN4-005
- `topic-adjective-sa` -> HN4-006
- `topic-volitional-form` -> HN4-007
- `topic-noda-ndesu` -> HN4-008
- `topic-i-adjective-nominalization` -> HN4-011

Pilot topics mapped to lessons but intentionally kept partial:

- `topic-tameni` -> HN4-009; N3 expansion and purpose/cause contrast remain.
- `topic-to-conditional` -> HN4-010; quotation/condition and N5 `と` contrast
  remain.

## Current Official Lesson Set

| Lesson | Grammar order | Topic | Runtime status |
|---|---:|---|---|
| HN4-001 | 42 | `〜なさい` | Approved for limited pilot |
| HN4-002 | 43 | `〜たほうがいい` | Approved for limited pilot |
| HN4-003 | 41 | `〜かもしれない` | Approved for limited pilot |
| HN4-004 | 48 | `〜しかない` | Approved for limited pilot |
| HN4-005 | 44 | `可能形` | Approved for limited pilot |
| HN4-006 | 45 | `〜さ` | Approved for limited pilot |
| HN4-007 | 46 | `意向形` | Approved for limited pilot |
| HN4-008 | 47 | `〜のだ` | Approved for limited pilot |
| HN4-009 | 17 | `〜ために` | Approved for limited pilot |
| HN4-010 | 40 | `〜と` | Approved for limited pilot |
| HN4-011 | 45 | `〜さ` | Approved for second limited pilot; DB seed, list/detail/start-submit API smoke, lesson TTS audio QA, simulator mobile UAT, and first aggregate feedback baseline passed |

HN4-001 through HN4-010 remain governed by the limited pilot decision in
`docs/operations/plans/n4-pilot-learner-rollout-decision-2026-05-12.md`.
HN4-011 is governed by
`docs/operations/plans/n4-lesson-11-pilot-rollout-decision-2026-05-13.md`,
is runtime-verified for controlled simulator-backed pilot exposure, and has a
first aggregate feedback baseline in
`docs/operations/plans/n4-lesson-11-pilot-feedback-baseline-2026-05-13.md`.

## Lesson 11+ Candidate Buckets

### Bucket A. Contract Sync Before Expansion

Goal: make the staging coverage contracts reflect the official pilot lessons.

Status: complete as of 2026-05-12.

Completed actions:

- Marked pilot-covered topic anchors as covered by HN4 lesson IDs where the topic
  is fully represented by the official seed.
- Kept ambiguous or contrast-sensitive topics as partial where a pilot lesson
  covers only one usage and the topic still needs split treatment.
- Kept promoted seed-candidate lesson draft blueprints only as lineage while
  excluding HN4-001 through HN4-008 and HN4-011 from the lesson 11+ priority
  queue.
- Re-ran `pnpm --filter @harukoto/database curriculum:validate`.
- Re-ran `pnpm --filter @harukoto/database lessons:validate`.

Exit criteria:

- Coverage counts no longer imply that promoted N4 pilot topics are
  still entirely missing.
- The coverage-priority queue for lesson 11+ excludes topics already handled by
  HN4-001 through HN4-011 unless a deliberate contrast follow-up remains.

### Bucket B. Runtime-Compatible Missing Topics

Goal: create the next seed-candidate set without adding new mobile question
contracts.

Candidate class:

- Topics that need original examples, lesson slot, and human review.
- No immediate new runtime question type required, or the blocker is explicitly
  called out before selection.
- Suitable for the existing 5-question lesson shape:
  `VOCAB_MCQ`, `CONTEXT_CLOZE`, `SENTENCE_REORDER`.

Current queue after HN4-011 promotion:

- `topic-kitto` - keep in P2 queue, but do not select until adverb/discourse
  scope, TTS decision, and runtime-safe question shape are closed.

N4 missing topics excluded from the foundation lesson 11+ queue:

- `topic-imperative-form` - belongs to `CONVERSATION_REGISTER` /
  `WAVE_4_REGISTER_BUSINESS` because register/risk policy is required.
- `topic-keigo-sonkeigo-kenjougo` - belongs to `BUSINESS_KEIGO` /
  `WAVE_4_REGISTER_BUSINESS`, not the immediate foundation expansion.

Exit criteria:

- New candidates have HaruKoto-authored dialogue, examples, prompts, answer
  explanations, 4 reading script lines, and 5 runtime-safe questions.
- Each candidate has TTS target coverage before promotion.

### Bucket C. Partial And Contrast-Sensitive Topics

Goal: avoid papering over N4 topics that need distinction or runtime support.

Current P1 queue:

- `topic-prohibitive-na`
- `topic-tameni`
- `topic-to-conditional`
- `topic-to-quotation-or-condition`
- `topic-souda-hearsay-appearance-a`
- `topic-souda-hearsay-appearance-b`
- `topic-mono-functions`

Rules:

- Do not promote these automatically just because a grammar row exists.
- Decide whether the topic needs a contrast policy, a split topic, or only a
  conservative runtime-compatible lesson.
- Keep `needs_runtime_support` until the lesson can be taught using existing
  mobile question types or a separate mobile feature plan exists.

Exit criteria:

- Each partial topic has an explicit closeout decision:
  `split`, `runtime-compatible lesson`, `defer`, or `requires mobile feature`.

### Bucket D. TTS And Audio QA

Goal: prevent a text-only broad rollout.

Required actions before broad/full N4 rollout:

- Generate or verify all `lesson-seeds:HN4-*` script-line and question-prompt
  audio for the current pilot batch. The full published N4 pilot batch now has
  99/99 generated lesson TTS records, and all 99 generated URLs pass read-only
  HTTP validation; see
  `docs/operations/plans/n4-pilot-tts-coverage-audit-2026-05-13.md`.
- Extend the same manifest policy to lesson 11+ candidates.
- Run admin or API generation only through approved TTS surfaces.
- Perform audio playback QA on at least one full chapter before broad rollout.

Exit criteria:

- Current pilot TTS is not just target-covered; it has generated/audio-QA
  evidence.
- Lesson 11+ candidates cannot be promoted without TTS target coverage.

## Promotion Gates For Any New N4 Batch

Each lesson 11+ batch must pass the same gate stack as the pilot:

| Gate | Required before learner exposure |
|---|---|
| Data validation | `pnpm --filter @harukoto/database lessons:validate` |
| Quality heuristics | `pnpm --filter @harukoto/database lessons:quality -- --level N4` |
| Curriculum validation | `pnpm --filter @harukoto/database curriculum:validate` |
| Human-review packet | `pnpm --filter @harukoto/database lessons:review:prepare -- --level N4` |
| Review drift gate | `pnpm --filter @harukoto/database lessons:review:validate` |
| Review approval gate | `pnpm --filter @harukoto/database lessons:review:gate -- --level N4` |
| Configured DB seed check | `cd apps/api && uv run python -m app.seeds.lessons --check --level N4` |
| API smoke | Authenticated N4 list/detail/start/submit smoke |
| Mobile UAT | At least one happy path and one wrong-answer path in the new batch |
| Rollout decision | New limited/broad decision document |

## Stop Conditions

Stop expansion and keep broad/full rollout on HOLD if any of these occur:

- Coverage contracts disagree with official lesson JSON and the drift is not
  explicitly documented.
- A new N4 lesson needs a question type unsupported by current mobile runtime.
- `lessons:review:gate -- --level N4` fails.
- TTS target coverage is missing for a new lesson seed.
- A new lesson has ambiguous Korean explanation, impossible answer key, or a
  grammar usage that changes the taught meaning.
- No native-speaker or delegated explicit curriculum approval exists for the
  batch.

## Lesson 11+ Closeout Result

The lesson 11+ queue has been recalculated and partial-topic closeouts are now
recorded in
`docs/operations/plans/n4-lesson-11-queue-decision-2026-05-12.md`.

Result:

- Select `topic-i-adjective-nominalization` as the first HN4-011 candidate and
  promote it into official lesson JSON.
- Draft `lsc-n4-i-adjective-nominalization-001` as the HN4-011 seed candidate
  with HaruKoto-authored content and generated TTS targets.
- Create and approve
  `packages/database/data/curriculum/lesson-seed-candidate-review/n4-candidate-review.json`
  for delegated AI candidate review before official lesson JSON promotion.
  Operational record: `docs/operations/plans/n4-lesson-11-candidate-review-2026-05-13.md`.
- Promote HN4-011 into official lesson JSON and move it to second limited
  `PILOT` status.
  Operational record: `docs/operations/plans/n4-lesson-11-official-promotion-2026-05-13.md`.
- Keep `topic-kitto` deferred until adverb/discourse scope, TTS, and runtime
  question support are decided.
- Keep the seven partial N4 foundation rows out of automatic seed drafting until
  their split, contrast, or mobile-feature decisions are satisfied.
- Broad/full N4 rollout remains HOLD.

## Recommended Next Work Order

1. Continue monitoring HN4-011 controlled-pilot feedback and keep rollback
   triggers visible. First aggregate baseline is recorded in
   `docs/operations/plans/n4-lesson-11-pilot-feedback-baseline-2026-05-13.md`;
   the first refresh is recorded in
   `docs/operations/plans/n4-lesson-11-pilot-feedback-refresh-2026-05-13.md`.
2. Keep human audio-quality review as a broad-rollout blocker after generation
   evidence exists. The generation run is recorded in
   `docs/operations/plans/n4-pilot-batch-tts-generation-run-2026-05-13.md`.
   Machine preflight for all 99 generated targets passed with 0 blockers and 11
   silence-ratio warnings; see
   `docs/operations/plans/n4-pilot-tts-audio-quality-preflight-2026-05-13.md`.
   Human review packets for all 99 generated N4 pilot TTS targets are prepared;
   see
   `docs/operations/plans/n4-pilot-human-audio-qa-packets-2026-05-13.md`.
3. Re-run physical-device smoke before release-artifact claims if required.
4. Return to the partial-topic queue only after the closeout decision for that
   topic is satisfied.

## Current Release Boundary

The N4 pilot remains a controlled learner-pilot, not a broad launch.
The app must not claim complete N4 coverage until the above gates pass for the
expanded batch and a fresh rollout decision explicitly approves broader
exposure.
