# N4 Residual FLAG Source Rewrites

> Status: SOURCE UPDATED - DB/TTS not regenerated in this slice
> Scope: six N4 script lines that remained `FLAG` after original, first-pass,
> and second-pass TTS/STT checks
> Boundary: this is curriculum source cleanup, not native-speaker review and
> not a runtime DB mutation

ASSUMPTION: Repeated STT mismatch across three audio versions is enough to
treat these source lines as TTS-fragile and rewrite the source before spending
another regeneration cycle.

## Summary

| Metric | Count |
|---|---:|
| Residual FLAG rows reviewed | 6 |
| Source lines rewritten | 6 |
| Official lesson files touched | 3 |
| Unique seed candidate rows synchronized | 5 |
| Packet verdicts changed | 0 |
| Runtime DB rows changed | 0 |
| New audio generated | 0 |

## Rewrite Decisions

| Target | Old source | New source | Reason |
|---|---|---|---|
| HN4-001 script:3 | 分かりました。丁寧に確認します。 | 分かりました。注意して確認します。 | `丁寧に` repeatedly produced unrelated STT. `注意して` keeps an HN4-001 vocabulary item and is clearer. |
| HN4-004 script:3 | 諦めないで、急いで行きましょう。 | まだ間に合います。急いで行きましょう。 | `諦めないで` repeatedly became `始めないで` or `責めないで`; the rewrite keeps the supportive dialogue function. |
| HN4-006 script:0 | 湖の深さを地図で確認しました。 | 水の深さを確認しました。 | Keeps the `さ` nominalization target while removing the fragile `湖の...地図で` compound. |
| HN4-006 script:2 | はい。線の太さや細さも見られます。 | はい。線の太さを確認できます。 | Keeps one clear `太さ` target instead of adjacent `太さや細さ` plus `見られます`. |
| HN4-010 script:3 | 荷物が届くと、メールが来ます。 | 商品が届くと、連絡が来ます。 | Keeps `届くと` while replacing `荷物` and `メール`, both repeatedly unstable in STT. |
| HN4-011 script:1 | 厚い紙と薄い紙がありますね。 | 厚さが違う紙がありますね。 | Keeps paper context and the `厚さ` nominalization target while avoiding repeated `紙` versus `石` confusion. |

## Files Updated

- `packages/database/data/lessons/n4/ch01-core-directions-and-judgment.json`
- `packages/database/data/lessons/n4/ch02-reasons-conditions-and-intent.json`
- `packages/database/data/lessons/n4/ch03-quality-and-degree.json`
- `packages/database/data/curriculum/lesson-seed-candidates.json`

Generated follow-up artifacts refreshed in this source-cleanup slice:

- `packages/database/data/curriculum/tts-target-manifest.json`
- `apps/api/app/data/curriculum/tts-target-manifest.json`
- `packages/database/data/curriculum/lesson-human-review/n4-pilot-review.json`
- `packages/database/data/curriculum/lesson-seed-candidate-review/n4-candidate-review.json`

## Runtime Follow-Up

The configured DB still has the previous lesson text and previous audio URLs
until an explicit seed/apply step runs. After this PR lands:

1. Seed or otherwise apply the revised N4 lesson source to the configured DB.
2. Regenerate TTS only for the six rewritten script-line targets.
3. Re-run STT-assisted audit on the six new audio URLs.
4. Update packet verdicts only after the regenerated source/audio passes review.

Broad N4 rollout remains on HOLD while `PENDING` and `FLAG` verdicts remain.
