# N4 Full Coverage Plan

> Date: 2026-05-12
> Scope: N4 pilot aftercare and lesson 11+ promotion planning
> Status: lesson 11 closeout completed; broad/full N4 rollout remains HOLD

## Decision

Do not promote N4 as a complete course yet.

The current N4 learner exposure remains limited to the approved 10-lesson
pilot. The next automated workstream is not broad rollout. It is a coverage
planning and contract-sync wave that decides which missing or partial N4 topics
can become lesson 11+ candidates.

ASSUMPTION: The next unblocked task is coverage planning for N4 lesson 11+,
because mobile MY screen-level smoke still requires a human to read and
interact with the physical iPhone screen.

## Current Inventory

| Source | Current count | Notes |
|---|---:|---|
| N4 vocabulary rows | 944 | `packages/database/data/vocabulary/n4-words.json` |
| N4 grammar rows | 49 | `packages/database/data/grammar/n4-grammar.json` |
| N4 cloze rows | 60 | `packages/database/data/cloze/n4-cloze.json` |
| N4 sentence-arrange rows | 60 | `packages/database/data/sentence-arrange/n4-arrange.json` |
| Official N4 lesson chapters | 2 | `packages/database/data/lessons/n4/*.json` |
| Official N4 lessons | 10 | HN4-001 through HN4-010 |
| Official N4 script lines | 40 | 4 reading script lines per lesson |
| Official N4 lesson questions | 50 | 5 runtime-safe questions per lesson |
| Official N4 vocabulary links | 50 | 45 unique vocabulary orders |
| Official N4 grammar anchors | 10 | Orders 17, 40, 41, 42, 43, 44, 45, 46, 47, 48 |

## Topic Coverage Snapshot

| Contract | Count | Current meaning |
|---|---:|---|
| N4 curriculum topics | 39 | Topic inventory derived from reference coverage |
| Covered N4 topics | 28 | Pilot-covered topics are now reflected in the staging contract |
| Partial N4 topics | 7 | Remaining N4 foundation queue; needs split, contrast, or runtime-support decision |
| Missing N4 topics | 4 | 2 N4 foundation topics plus 2 later register/business topics |
| N4 foundation priorities | 9 | Remaining candidate queue for WAVE_2_N4_FOUNDATION |
| P1 N4 foundation priorities | 7 | Higher-risk partial topics, mostly runtime-support blockers |
| P2 N4 foundation priorities | 2 | Runtime-compatible missing topic plus one `きっと` blocker |

The staging coverage contract has now been synchronized to the approved pilot
runtime truth. HN4-001 through HN4-008 are marked as covered where the pilot
lesson fully represents the topic. HN4-009 and HN4-010 remain partial because
`ために` and `〜と` still need contrast/follow-up decisions beyond the current
pilot lesson.

This sync is not broad rollout approval. It only makes the planning contract
usable for selecting true lesson 11+ candidates.

## Coverage Contract Sync Result

| Area | Before sync | After sync |
|---|---:|---:|
| N4 covered topics | 20 | 28 |
| N4 partial topics | 8 | 7 |
| N4 missing topics | 11 | 4 |
| N4 foundation priority rows | 17 | 9 |
| N4 P1 priority rows | 8 | 7 |
| N4 P2 priority rows | 9 | 2 |

Pilot topics marked covered and removed from the lesson 11+ priority queue:

- `topic-nasai` -> HN4-001
- `topic-ta-hou-ga-ii` -> HN4-002
- `topic-kamoshirenai` -> HN4-003
- `topic-shika-nai` -> HN4-004
- `topic-potential-form` -> HN4-005
- `topic-adjective-sa` -> HN4-006
- `topic-volitional-form` -> HN4-007
- `topic-noda-ndesu` -> HN4-008

Pilot topics mapped to lessons but intentionally kept partial:

- `topic-tameni` -> HN4-009; N3 expansion and purpose/cause contrast remain.
- `topic-to-conditional` -> HN4-010; quotation/condition and N5 `と` contrast
  remain.

## Current Approved Pilot Lessons

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

These lessons may remain available only under the limited pilot decision in
`docs/operations/plans/n4-pilot-learner-rollout-decision-2026-05-12.md`.

## Lesson 11+ Candidate Buckets

### Bucket A. Contract Sync Before Expansion

Goal: make the staging coverage contracts reflect the official 10-lesson pilot.

Status: complete as of 2026-05-12.

Completed actions:

- Marked pilot-covered topic anchors as covered by HN4 lesson IDs where the topic
  is fully represented by the official seed.
- Kept ambiguous or contrast-sensitive topics as partial where a pilot lesson
  covers only one usage and the topic still needs split treatment.
- Kept promoted seed-candidate lesson draft blueprints only as lineage while
  excluding HN4-001 through HN4-008 from the lesson 11+ priority queue.
- Re-ran `pnpm --filter @harukoto/database curriculum:validate`.
- Re-ran `pnpm --filter @harukoto/database lessons:validate`.

Exit criteria:

- Coverage counts no longer imply that the 10 promoted N4 pilot topics are
  still entirely missing.
- The coverage-priority queue for lesson 11+ excludes topics already handled by
  HN4-001 through HN4-010 unless a deliberate contrast follow-up remains.

### Bucket B. Runtime-Compatible Missing Topics

Goal: create the next seed-candidate set without adding new mobile question
contracts.

Candidate class:

- Topics that need original examples, lesson slot, and human review.
- No immediate new runtime question type required, or the blocker is explicitly
  called out before selection.
- Suitable for the existing 5-question lesson shape:
  `VOCAB_MCQ`, `CONTEXT_CLOZE`, `SENTENCE_REORDER`.

Initial queue after contract sync:

- `topic-i-adjective-nominalization` - current best first lesson 11 candidate.
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
  targets for the current pilot.
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

- Select `topic-i-adjective-nominalization` as the first HN4-011 candidate.
- Keep `topic-kitto` deferred until adverb/discourse scope, TTS, and runtime
  question support are decided.
- Keep the seven partial N4 foundation rows out of automatic seed drafting until
  their split, contrast, or mobile-feature decisions are satisfied.
- Broad/full N4 rollout remains HOLD.

## Recommended Next Work Order

1. Draft one HN4-011 seed candidate for `topic-i-adjective-nominalization`.
2. Regenerate curriculum contracts and TTS target manifests.
3. Prepare and validate the N4 human-review packet.
4. Generate or verify TTS targets before DB seed.
5. Run configured DB seed check and API smoke.
6. Run mobile UAT and record a new rollout decision.
7. Return to the partial-topic queue only after the closeout decision for that
   topic is satisfied.

## Current Release Boundary

The N4 pilot remains a controlled learner-pilot, not a broad launch.
The app must not claim complete N4 coverage until the above gates pass for the
expanded batch and a fresh rollout decision explicitly approves broader
exposure.
