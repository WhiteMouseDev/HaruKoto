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
- `lesson-draft-blueprints.json`: draft lesson planning records for missing or
  partial topics. These are not seedable lessons.
- `lesson-seed-candidates.json`: seed-shaped lesson drafts that are validated
  against topics, examples, vocabulary, grammar, current question runtime types,
  and reading-script TTS fields before any promotion into `data/lessons/**`.
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
- Treat `packages/database/data/curriculum/topic-grammar-map.json`,
  `packages/database/data/curriculum/topic-vocabulary-map.json`,
  `packages/database/data/curriculum/tts-target-manifest.json`, and
  `packages/database/data/curriculum/tts-review-batches.json` as the source
  contracts. The API bundled copies are generated output for deployment
  packaging and must be refreshed with `curriculum:derive`.
- Keep scaffold candidates and topic anchor policies in `draft` until their
  review gates are resolved. They explain why a P0 topic is not yet seedable or
  which anchor decision produced a draft seed candidate.
- Keep contrast question policies in `draft` until runtime-safe question types,
  future contrast/listening question plans, and TTS targets are reviewed.
- Treat JSON as the source for Wave 0 validation only. Do not infer production
  DB migration approval from this directory.
