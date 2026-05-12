# Curriculum Data Contracts

This directory holds draft curriculum mapping data before it is promoted to
database tables.

Wave 0 keeps these files as validated staging contracts:

- `pdf-topic-inventory.json`: extracted source-topic metadata from the paid PDF
  reference set. It must not store copied source explanations or examples.
- `curriculum-topics.json`: HaruKoto-owned learning topic records.
- `topic-grammar-map.json`: mappings from curriculum topics to existing grammar
  rows. The derive script also writes an identical runtime copy to
  `apps/api/app/data/curriculum/topic-grammar-map.json` for admin TTS
  generation dry-run planning.
- `topic-vocabulary-map.json`: mappings from curriculum topics to existing
  vocabulary rows. Only a single `exact` mapping is eligible for automatic
  execute preview; broad or related mappings remain manual review candidates.
  The derive script also writes an identical runtime copy to
  `apps/api/app/data/curriculum/topic-vocabulary-map.json`.
- `example-bank.json`: newly authored HaruKoto example sentences. Do not copy
  PDF examples into this file.
- `question-blueprints.json`: draft question generation policy per topic. Current
  runtime-safe lesson types stay limited to `VOCAB_MCQ`, `CONTEXT_CLOZE`, and
  `SENTENCE_REORDER`.
- `grammar-metadata-v2.json`: draft formation, nuance, Korean learner notes,
  and split N5/N4+ grammar metadata before DB or seed promotion.
- `tts-target-manifest.json`: draft audio target inventory for topic fields,
  examples, lesson seed reading script lines, and seed question prompts. This is
  not a direct write plan for the existing `tts_audio` table. The derive script
  also writes an identical runtime copy to
  `apps/api/app/data/curriculum/tts-target-manifest.json` for admin target
  detail review. Vocabulary topics with a single exact vocabulary mapping use
  item-level `vocabulary:<level>:<order>:<field>` sources so their target IDs
  point at a concrete content row before generation.
- `tts-review-batches.json`: admin review/export grouping for every TTS target.
  It separates targets covered by current admin TTS fields from targets that
  need admin/API surface expansion before generation.
  `scripts/derive-curriculum-topics.mjs` also writes an identical runtime copy
  to `apps/api/app/data/curriculum/tts-review-batches.json` so the API Docker
  image can serve the read-only admin endpoint without depending on repo-root
  package files.
- `tts-review-manual-mapping-overrides.json`: approved reviewer decisions that
  resolve manual TTS mapping rows to a concrete grammar or vocabulary level/order
  before admin execute preview, plus audit-only `reviewOutcomes` for unresolved
  rows that still need topic mapping, topic split, partial override review, or
  rejection handling. It is source-controlled and bundled to
  `apps/api/app/data/curriculum/tts-review-manual-mapping-overrides.json` by
  `scripts/derive-curriculum-topics.mjs`.
- `lesson-draft-blueprints.json`: draft lesson planning records for missing or
  partial topics. These are not seedable lessons.
- `lesson-seed-candidates.json`: seed-shaped lesson drafts that are validated
  against topics, examples, vocabulary, grammar, current question runtime types,
  and reading-script TTS fields before any promotion into `data/lessons/**`.
- `lesson-human-review/*.json`: reviewer-editable packets generated from
  official `data/lessons/**` files. They collect lesson metadata, reference
  vocabulary/grammar, script lines, questions, answer keys, explanations, and
  linked TTS targets so a human reviewer can inspect a level batch without
  manually joining source files.
- `scaffold-candidates.json`: kana/kanji scaffold drafts that do not require a
  grammar order but still validate topic, example, runtime question, and TTS
  readiness links.
- `topic-anchor-policies.json`: promotion policy for P0 topics that are not yet
  seed candidates because they need scaffold review, grammar metadata v2, or
  contrast question policy first. Once a contrast-ready draft seed candidate
  exists, the anchor remains as promotion lineage and must point to the same
  topic, lesson blueprint, and examples.
- `contrast-question-policies.json`: validated contrast policy for P0 topics
  whose seed candidates need vocabulary/skill or grammar usage separation before
  lesson promotion.
- `coverage-priorities.json`: priority and wave assignment for non-covered
  topics.
- `scripts/derive-curriculum-topics.mjs`: derives topic and grammar-map draft
  data from the inventory plus curated internal mappings.
- `scripts/prepare-lesson-human-review.mjs`: generates lesson human curriculum
  review packets from official lesson JSON, vocabulary/grammar references, and
  the TTS target manifest. Existing `reviewerDecision` and `reviewerNotes`
  values are preserved when the packet is regenerated.
- `scripts/validate-lesson-human-review.mjs`: validates source-controlled
  lesson human review packets against current lesson JSON, vocabulary/grammar
  references, and TTS targets while preserving reviewer decisions. It runs as
  part of `curriculum:validate`.
- `scripts/check-lesson-human-review-gate.mjs`: blocks level rollout until all
  rows in the requested lesson human review packet are `APPROVED`. The package
  alias `lessons:review:gate` runs packet validation first, then this approval
  gate.
- `scripts/prepare-tts-manual-mapping-review.mjs`: generates reviewer-editable
  TTS manual mapping rows from current review batches and topic maps.
- `scripts/prepare-tts-manual-mapping-followups.mjs`: groups unresolved TTS
  manual mapping rows into reviewer follow-up queues.
- `scripts/compile-tts-manual-mapping-overrides.mjs`: compiles approved TTS
  manual mapping rows into executable `decisions` and unresolved rows into
  audit-only `reviewOutcomes` in `tts-review-manual-mapping-overrides.json`.
- `scripts/validate-tts-manual-mapping-review.mjs`: validates source-controlled
  TTS review rows against current target, batch, topic map, vocabulary, and
  grammar contracts. It runs as part of `curriculum:validate`.

Rules:

- Store topic metadata, not copyrighted source text.
- Use PDF references only as internal coverage anchors.
- Keep examples, prompts, and explanations newly authored.
- Include audio policy metadata for any content that may become a TTS target.
- Use `generationStatus` for audio generation lifecycle. Keep content
  `reviewStatus` for moderation/review state only.
- Keep grammar metadata v2 in `draft` until contrast question policy, TTS
  readiness review, and human curriculum review are complete.
- Keep generated lesson blueprints in `draft` until API, mobile, and admin
  review surfaces can support publishing the resulting lesson JSON.
- Keep lesson seed candidates in `draft` and outside `data/lessons/**` until the
  candidate passes human review, TTS readiness review, and promotion planning.
- Keep `lesson-human-review/*.json` decisions as preparation state only. A
  reviewer may change `reviewerDecision` to `APPROVED`, `NEEDS_EDIT`, or
  `REJECTED`, but final curriculum approval still belongs in the operational
  review record.
- Keep `lesson-human-review/*.json` aligned with current lesson and TTS source
  data. Run `lessons:review:prepare` after lesson, vocabulary, grammar, or TTS
  target changes. `curriculum:validate` fails if packet structure drifts, if a
  decision is invalid, or if `NEEDS_EDIT`/`REJECTED` is missing
  `reviewerNotes`.
- Run `lessons:review:gate -- --level <JLPT>` before learner rollout. It is
  expected to fail while any row remains `PENDING`, `NEEDS_EDIT`, or
  `REJECTED`; use that failure as the reviewer closeout queue.
- Every lesson seed candidate must remain covered by `tts-target-manifest.json`
  before promotion: one target per reading script line and one target per
  question prompt.
- Keep vocabulary TTS targets topic-level only while the topic still needs
  manual mapping. Once a topic has a single exact vocabulary row, generate
  row-level targets such as `tts-vocabulary-n5-309-word` instead of broad
  topic-level targets.
- Use `tts-review-batches.json` before admin generation. Batches marked
  `admin_existing_tts` may map to current admin TTS fields; batches marked
  `admin_extension_required` must not be generated until the listed blocker has
  a matching review/export surface.
- Use `curriculum:tts-review:prepare` to create review rows. Rows with no
  current topic-map candidate stay `NEEDS_MAPPING`; rows with candidates stay
  `PENDING` only when a reviewer can approve a concrete candidate. Rows with
  multiple non-exact candidates stay `NEEDS_TOPIC_SPLIT`; rows with one
  non-exact candidate stay `NEEDS_PARTIAL_OVERRIDE` until a reviewer either
  improves the map or writes a partial override rationale.
- A reviewer marks a row `APPROVED` and selects either `selectedCandidateIndex`
  or a fully populated `selected` object before running
  `curriculum:tts-review:compile`.
- Approved decisions must preserve `sourceMatchType` and `resolutionType` in
  the compiled override file. Non-exact selections are target-level
  `partial_override` decisions; they do not make the parent topic map exact.
- Run `curriculum:tts-review:followups` after reviewer edits so
  `tts-manual-mapping-review/_followups.json` stays synchronized with the
  unresolved queue. Run `curriculum:tts-review:compile -- --replace` so
  `reviewOutcomes` stays synchronized with the unresolved queue.
  `curriculum:validate` fails if either artifact drifts.
- Mechanical triage may approve a row only when there is exactly one `exact`
  candidate. Rows with multiple non-exact candidates should stay
  `NEEDS_TOPIC_SPLIT`, and rows with a single non-exact candidate should stay
  `NEEDS_PARTIAL_OVERRIDE` until the topic is split, a stronger map is added,
  or a reviewer writes an explicit rationale for a partial override.
- Keep `tts-manual-mapping-review/*.json` aligned with current contracts. Run
  `curriculum:tts-review:prepare` after topic/TTS map changes, and
  `curriculum:validate` will fail if the review artifact becomes stale.
- Keep `tts-review-manual-mapping-overrides.json` in `draft` while decisions are
  used only to unblock generation dry-run and execute preview. Run
  `curriculum:derive` after compilation so the API bundled copy stays current.
- Treat `packages/database/data/curriculum/topic-grammar-map.json`,
  `packages/database/data/curriculum/topic-vocabulary-map.json`,
  `packages/database/data/curriculum/tts-target-manifest.json`, and
  `packages/database/data/curriculum/tts-review-batches.json`, and
  `packages/database/data/curriculum/tts-review-manual-mapping-overrides.json`
  as the source contracts. The API bundled copies are generated output for
  deployment packaging and must be refreshed with `curriculum:derive`.
- Keep scaffold candidates and topic anchor policies in `draft` until their
  review gates are resolved. They explain why a P0 topic is not yet seedable or
  which anchor decision produced a draft seed candidate.
- Keep contrast question policies in `draft` until runtime-safe question types,
  future contrast/listening question plans, and TTS targets are reviewed.
- Treat JSON as the source for Wave 0 validation only. Do not infer production
  DB migration approval from this directory.
