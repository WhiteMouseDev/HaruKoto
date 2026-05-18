# N4 Residual FLAG Audio QA Adjudication

> Status: REVIEW SHEET - no packet verdicts applied
> Scope: second-pass regenerated N4 audio rows that still recommend `FLAG`
> Boundary: adjudication aid only; not native-speaker review and not a DB mutation

ASSUMPTION: Repeated STT mismatch across original, first-pass, and second-pass
audio is enough to justify a focused adjudication/rewrite decision before
spending another TTS regeneration cycle.

## Inputs

- Original FLAG manifest: `docs/operations/plans/n4-human-audio-qa-flag-regeneration-plan-2026-05-14.csv`
- First regeneration results: `docs/operations/plans/n4-human-audio-qa-flag-regeneration-results-2026-05-14.csv`
- First-pass recommendations: `docs/operations/plans/n4-human-audio-qa-flag-post-regeneration-recommendations-2026-05-18.csv`
- Second regeneration results: `docs/operations/plans/n4-human-audio-qa-flag-regeneration-second-pass-results-2026-05-18.csv`
- Second-pass recommendations: `docs/operations/plans/n4-human-audio-qa-flag-second-pass-recommendations-2026-05-18.csv`

## Summary

| Metric | Count |
|---|---:|
| Second-pass recommendation rows | 7 |
| Second-pass rows cleared to PASS | 1 |
| Residual FLAG rows selected | 6 |
| Rewrite candidates | 6 |

## CSV Boundary

The companion CSV keeps `new_verdict` and `new_notes` blank. Those columns
must stay blank until an adjudication decision is made. If a row is later
cleared on the current second-pass audio, the CSV can be used with
`scripts/apply_n4_audio_qa_verdicts.py` because it preserves the standard
`target_key`, `packet`, `audio_url`, `new_verdict`, and `new_notes` columns.

## Residual FLAG Items

| Target | Source text | Original STT | First-pass STT | Second-pass STT | Next step | Current audio |
|---|---|---|---|---|---|---|
| HN4-001 script:3 | 分かりました。丁寧に確認します。 | わかりました。定時に確認します。 | 分かりました。店主に確認します。 | わかりました。艇中に確認します。 | Adjudicate HN4-001 script:3 across original/first/second audio before a third regeneration; if no version is clearly acceptable, rewrite the source sentence and regenerate from the rewritten source. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/script-line-3-regen-20260518T004000Z.mp3) |
| HN4-004 script:3 | 諦めないで、急いで行きましょう。 | 始めないで競いに行きましょう | ひじめないで 清いでいきましょう | 責めないで築いでいきましょう | Adjudicate HN4-004 script:3 across original/first/second audio before a third regeneration; if no version is clearly acceptable, rewrite the source sentence and regenerate from the rewritten source. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/script-line-3-regen-20260518T004000Z.mp3) |
| HN4-006 script:0 | 湖の深さを地図で確認しました。 | 骨の傘を実で確認しました。 | このマーサを実で確認しました。 | 小野真央を実で確認しました。 | Adjudicate HN4-006 script:0 across original/first/second audio before a third regeneration; if no version is clearly acceptable, rewrite the source sentence and regenerate from the rewritten source. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/script-line-0-regen-20260518T004000Z.mp3) |
| HN4-006 script:2 | はい。線の太さや細さも見られます。 | はい。不当操作や操作もみられます。 | はい、線の太さや磯さも見られる。 | はい、洗脳邸さや石さもみられます。 | Adjudicate HN4-006 script:2 across original/first/second audio before a third regeneration; if no version is clearly acceptable, rewrite the source sentence and regenerate from the rewritten source. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/script-line-2-regen-20260518T004000Z.mp3) |
| HN4-010 script:3 | 荷物が届くと、メールが来ます。 | 何か届くとメールが来ます。 | 何もつか届くとミールが来ます | 何もずが届くとミールが来ます。 | Adjudicate HN4-010 script:3 across original/first/second audio before a third regeneration; if no version is clearly acceptable, rewrite the source sentence and regenerate from the rewritten source. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/script-line-3-regen-20260518T004000Z.mp3) |
| HN4-011 script:1 | 厚い紙と薄い紙がありますね。 | 石と薄い石があります。 | 藍石と薄石があります | 小財地と薄石があります | Adjudicate HN4-011 script:1 across original/first/second audio before a third regeneration; if no version is clearly acceptable, rewrite the source sentence and regenerate from the rewritten source. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/script-line-1-regen-20260518T004000Z.mp3) |

## Decision

Keep these rows as `FLAG` in packet verdicts. Do not run a third regeneration
blindly; first choose whether any existing version is acceptable or whether
the source sentence should be rewritten for clearer TTS/STT behavior.
