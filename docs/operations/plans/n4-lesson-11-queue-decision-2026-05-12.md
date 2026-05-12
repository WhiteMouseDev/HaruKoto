# N4 Lesson 11+ Queue Decision

> Date: 2026-05-12
> Scope: remaining N4 foundation priority queue after pilot coverage sync
> Decision: do not draft a 5-lesson N4 expansion batch yet

## Decision

The N4 lesson 11+ queue is not ready for a 1-chapter / 5-lesson expansion
batch.

After syncing HN4-001 through HN4-010 into the staging coverage contracts, the
remaining N4 foundation priority queue has 9 rows:

- 1 immediately usable foundation candidate class.
- 1 missing vocabulary/adverb candidate that still needs TTS and runtime-shape
  closeout.
- 7 partial/contrast-sensitive candidates that should not be promoted until the
  split or runtime-support decision is explicit.

The next safe content-generation slice is therefore a single-candidate lesson
11 preparation path for `topic-i-adjective-nominalization`, not a full 5-lesson
chapter.

ASSUMPTION: A production-quality N4 expansion batch should not pad the chapter
with unresolved contrast topics just to reach five lessons.

## Queue Snapshot

| Topic | Current status | Blueprint | Decision |
|---|---|---|---|
| `topic-i-adjective-nominalization` | missing / P2 | `ldb-i-adjective-nominalization` | SELECT as first lesson 11 candidate |
| `topic-kitto` | missing / P2 | `ldb-kitto` | HOLD until adverb scope, TTS decision, and runtime-safe question shape are closed |
| `topic-prohibitive-na` | partial / P1 | `ldb-prohibitive-na` | HOLD; requires register/prohibitive split decision |
| `topic-tameni` | partial / P1 | `ldb-tameni` | DEFER; HN4-009 already covers the pilot purpose-expression path |
| `topic-to-conditional` | partial / P1 | `ldb-to-conditional` | DEFER; HN4-010 already covers automatic-result `〜と` |
| `topic-to-quotation-or-condition` | partial / P1 | `ldb-to-quotation-or-condition` | SPLIT before promotion |
| `topic-souda-hearsay-appearance-a` | partial / P1 | `ldb-souda-hearsay-appearance-a` | SPLIT before promotion |
| `topic-souda-hearsay-appearance-b` | partial / P1 | `ldb-souda-hearsay-appearance-b` | SPLIT before promotion |
| `topic-mono-functions` | partial / P1 | `ldb-mono-functions` | SPLIT before promotion |

## Candidate Detail

### SELECT: `topic-i-adjective-nominalization`

Why it can move first:

- It is a true missing N4 foundation topic after pilot coverage sync.
- The draft blueprint uses existing mobile-supported question types:
  `VOCAB_MCQ`, `CONTEXT_CLOZE`, and `SENTENCE_REORDER`.
- It does not require a future contrast question type.

Blockers before seed promotion:

- Author HaruKoto-original examples and dialogue.
- Attach vocabulary and grammar references that do not overreach into N5
  adjective basics.
- Add TTS targets for reading script lines and question prompts.
- Run the normal lesson seed validation and human-review packet gates.

Recommended next artifact:

- One HN4-011 seed candidate focused on nominalizing い-adjective quality, not a
  full 5-lesson chapter.

### HOLD: `topic-kitto`

Why it stays out of lesson 11:

- It is a vocabulary/adverb/discourse item rather than a clear grammar anchor.
- The current blueprint has `LISTENING_MCQ` as a future draft question type.
- It carries `needs_tts_decision` and `needs_runtime_support`.

Closeout needed:

- Decide whether `きっと` belongs in a vocabulary review lesson, a discourse
  marker lesson, or a future listening/usage contrast lesson.
- Do not use it to pad the immediate N4 foundation chapter.

### HOLD: `topic-prohibitive-na`

Why it stays out:

- It overlaps visually with N5 `な` adjective material and command/register
  behavior.
- The current blueprint includes future `USAGE_CONTRAST`.
- It needs a register/prohibitive split before learner-facing promotion.

Closeout needed:

- Decide whether this belongs in a conversation/register mini-track or a later
  N4 command-form contrast lesson.

### DEFER: `topic-tameni`

Why it stays out:

- HN4-009 already gives the controlled pilot path for purpose `〜ために`.
- The remaining work is N3 expansion and purpose/cause contrast, not a new
  immediate N4 foundation lesson.

Closeout needed:

- Keep partial status until a contrast policy separates purpose from adjacent
  cause/reason usages.

### DEFER: `topic-to-conditional`

Why it stays out:

- HN4-010 already covers automatic-result conditional `〜と`.
- The remaining work is contrast against quotation/condition variants and N5
  `と`, not another immediate N4 foundation lesson.

Closeout needed:

- Keep partial status until the `と` family is split into teachable subtopics.

### SPLIT: `topic-to-quotation-or-condition`

Why it stays out:

- The topic is explicitly ambiguous: quotation, condition, or coordination
  could be intended.
- Promoting it without split risks duplicating HN4-010 or teaching the wrong
  `と` function.

Closeout needed:

- Split into an explicit quotation/condition subtopic before any seed
  candidate is promoted.

### SPLIT: `topic-souda-hearsay-appearance-a`

Why it stays out:

- `〜そうだ` must distinguish appearance/conjecture from hearsay.
- The current blueprint expects future `USAGE_CONTRAST`.

Closeout needed:

- Pick one usage as the primary lesson target and move the other into a separate
  contrast follow-up.

### SPLIT: `topic-souda-hearsay-appearance-b`

Why it stays out:

- It duplicates the same `〜そうだ` label and needs the same hearsay/appearance
  separation before learner-facing promotion.

Closeout needed:

- Merge with or split from `topic-souda-hearsay-appearance-a` before selecting
  either for a lesson.

### SPLIT: `topic-mono-functions`

Why it stays out:

- `もの` covers multiple functions: general norm `ものだ`, reason/emphasis,
  recollection, and contrastive `ものの`.
- The current grammar anchor only supports a subset.

Closeout needed:

- Keep `〜ものだ` as the primary teachable path and split the other functions
  into later topics.

## Expansion Rule

Do not create a 5-lesson N4 chapter until at least five candidates satisfy all
of the following:

- Uses only current mobile question types or has an approved mobile feature
  plan.
- Has HaruKoto-authored examples and dialogue.
- Has TTS target coverage.
- Has a clear single grammar/vocabulary teaching target.
- Has either native-speaker review or explicit delegated approval.

Until then, N4 expansion should proceed as a micro-batch.

## Next Work

1. Draft one HN4-011 candidate for `topic-i-adjective-nominalization`.
2. Add HaruKoto-authored examples and lesson seed content.
3. Extend TTS target coverage for HN4-011.
4. Run curriculum/lesson validation and prepare the review packet.
5. Decide whether to expose HN4-011 as a second limited pilot wave.

## Boundary

This decision does not approve broad/full N4 rollout. It narrows the next
content-generation step so HaruKoto does not inflate N4 coverage with unresolved
contrast topics.
