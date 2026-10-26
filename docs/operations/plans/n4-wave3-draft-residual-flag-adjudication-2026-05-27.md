# N4 Residual FLAG Audio QA Adjudication

> Status: REVIEW SHEET - no packet verdicts applied
> Scope: second-pass regenerated N4 audio rows that still recommend `FLAG`
> Boundary: adjudication aid only; not native-speaker review and not a DB mutation

ASSUMPTION: Repeated STT mismatch across original, first-pass, and second-pass
audio is enough to justify a focused adjudication/rewrite decision before
spending another TTS regeneration cycle.

## Inputs

- Original FLAG manifest: `docs/operations/plans/n4-wave3-draft-lexical-risk-regeneration-plan-2026-05-27.csv`
- First regeneration results: `docs/operations/plans/n4-wave3-draft-lexical-risk-regeneration-results-2026-05-27.csv`
- First-pass recommendations: `docs/operations/plans/n4-wave3-draft-lexical-risk-post-regeneration-recommendations-2026-05-27.csv`
- Second regeneration results: `docs/operations/plans/n4-wave3-draft-lexical-risk-second-regeneration-results-2026-05-27.csv`
- Second-pass recommendations: `docs/operations/plans/n4-wave3-draft-lexical-risk-second-post-regeneration-recommendations-2026-05-27.csv`

## Summary

| Metric | Count |
|---|---:|
| Second-pass recommendation rows | 2 |
| Second-pass rows cleared to PASS | 0 |
| Residual FLAG rows selected | 2 |
| Rewrite candidates | 2 |

## CSV Boundary

The companion CSV keeps `new_verdict` and `new_notes` blank. Those columns
must stay blank until an adjudication decision is made. If a row is later
cleared on the current second-pass audio, the CSV can be used with
`scripts/apply_n4_audio_qa_verdicts.py` because it preserves the standard
`target_key`, `packet`, `audio_url`, `new_verdict`, and `new_notes` columns.

## Residual FLAG Items

| Target | Source text | Original STT | First-pass STT | Second-pass STT | Next step | Current audio |
|---|---|---|---|---|---|---|
| HN4-018 script:0 | この機械は壊れそうです。 | この議会は壊れそう。 | この機械は壊れそう | この機械は、壊れそう。 | Adjudicate HN4-018 script:0 across original/first/second audio before a third regeneration; if no version is clearly acceptable, rewrite the source sentence and regenerate from the rewritten source. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/script-line-0-regen-n4ch05-lexical2-20260527.mp3) |
| HN4-019 script:3 | 受付は混むそうですから、早く行きましょう。 | てくてはさおむそうですから早く行きましょう。 | 特例はかもじむそうですから、早く行きましょう。 | てこれまではタコむそうでしたから、早く行きましょう。 | Adjudicate HN4-019 script:3 across original/first/second audio before a third regeneration; if no version is clearly acceptable, rewrite the source sentence and regenerate from the rewritten source. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/script-line-3-regen-n4ch05-lexical2-20260527.mp3) |

## Decision

Keep these rows as `FLAG` in packet verdicts. Do not run a third regeneration
blindly; first choose whether any existing version is acceptable or whether
the source sentence should be rewritten for clearer TTS/STT behavior.
