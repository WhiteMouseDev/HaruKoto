# N4 Full Coverage Plan

> Date: 2026-05-12
> Scope: N4 pilot aftercare and lesson 11+ promotion planning
> Status: planning gate opened; broad/full N4 rollout remains HOLD

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
| Covered N4 topics | 20 | Existing coverage in the staging contract |
| Partial N4 topics | 8 | Needs split, contrast, or runtime-support decision |
| Missing N4 topics | 11 | Needs authored examples and lesson slot |
| N4 foundation priorities | 17 | Candidate queue for WAVE_2_N4_FOUNDATION |
| P1 N4 foundation priorities | 8 | Higher-risk partial topics, mostly runtime-support blockers |
| P2 N4 foundation priorities | 9 | Runtime-compatible missing topics plus one `きっと` blocker |

Important: the staging coverage files still describe some promoted pilot topics
as `missing` or `partial`. For example, `topic-nasai`,
`topic-ta-hou-ga-ii`, `topic-kamoshirenai`, `topic-potential-form`,
`topic-adjective-sa`, `topic-volitional-form`, and `topic-noda-ndesu` now have
official lesson coverage through HN4-001 through HN4-008, but the staging
coverage contract has not been synchronized to that runtime truth.

This is not a learner-facing bug, but it is a planning-contract drift. It must
be resolved before using the coverage contract to select lesson 11+.

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

Required actions:

- Mark pilot-covered topic anchors as covered by HN4 lesson IDs where the topic
  is fully represented by the official seed.
- Keep ambiguous or contrast-sensitive topics as partial where a pilot lesson
  covers only one usage and the topic still needs split treatment.
- Re-run `pnpm --filter @harukoto/database curriculum:validate`.
- Re-run `pnpm --filter @harukoto/database lessons:validate`.

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
- No immediate new runtime question type required.
- Suitable for the existing 5-question lesson shape:
  `VOCAB_MCQ`, `CONTEXT_CLOZE`, `SENTENCE_REORDER`.

Initial queue after contract sync:

- `topic-i-adjective-nominalization`
- Any pilot topic that remains missing after deliberate review, not by drift.

Exit criteria:

- New candidates have HaruKoto-authored dialogue, examples, prompts, answer
  explanations, 4 reading script lines, and 5 runtime-safe questions.
- Each candidate has TTS target coverage before promotion.

### Bucket C. Partial And Contrast-Sensitive Topics

Goal: avoid papering over N4 topics that need distinction or runtime support.

Current P1 queue:

- `topic-prohibitive-na`
- `topic-shika-nai`
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

## Recommended Next Work Order

1. Sync the N4 staging coverage contracts with HN4-001 through HN4-010.
2. Recalculate the lesson 11+ queue from only true missing or partial topics.
3. Draft one small N4 expansion batch, preferably 1 chapter / 5 lessons.
4. Prepare and validate the human-review packet.
5. Generate or verify TTS targets before DB seed.
6. Run configured DB seed check and API smoke.
7. Run mobile UAT and record a new rollout decision.

## Current Release Boundary

The N4 pilot remains a controlled learner-pilot, not a broad launch.
The app must not claim complete N4 coverage until the above gates pass for the
expanded batch and a fresh rollout decision explicitly approves broader
exposure.
