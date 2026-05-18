# N4 Source-Rewrite Audio Runtime Application

> Status: PARTIAL PASS - rollout still HOLD
> Scope: six residual `FLAG` script lines rewritten in source and regenerated
> Boundary: delegated AI/STT audio QA only; not native-speaker review

ASSUMPTION: The project owner delegated post-regeneration audio review because
no human/native-speaker reviewer is currently available.

## Summary

| Metric | Result |
|---|---:|
| Source-rewritten targets regenerated | 6 |
| Regeneration failures | 0 |
| STT-assisted recommended PASS | 3 |
| STT-assisted recommended FLAG | 3 |
| Orthographic-only PASS override | 1 |
| Packet rows updated | 6 |
| Overall N4 PASS after application | 35 |
| Overall N4 PENDING after application | 62 |
| Overall N4 FLAG after application | 2 |

## Runtime Actions

1. Merged source rewrite PR `#141` into `main`.
2. Ran N4 lesson seed check; DB had 5 content mismatches for rewritten
   lessons.
3. Applied `uv run python -m app.seeds.lessons --level N4`.
4. Re-ran `uv run python -m app.seeds.lessons --check --level N4`; DB seed
   sync passed with 0 content and item-link mismatches.
5. Generated a current-DB regeneration manifest for the six rewritten
   script-line targets.
6. Regenerated all six TTS targets with run id `20260518T013503Z`.
7. Ran STT-assisted post-regeneration audit with `--transcribe`.
8. Applied recommendation CSV to the three N4 human-audio QA packet files.
9. Applied one canonical orthographic-only PASS override for `HN4-001 script:3`,
   matching the existing N4 audio QA treatment for kana/kanji-only STT drift.

## Result

| Target | Rewritten source | Recommendation | Notes |
|---|---|---|---|
| HN4-001 script:3 | 分かりました。注意して確認します。 | PASS | STT returned the same words in kana form; treated as a canonical orthographic-only mismatch, consistent with prior packet policy. |
| HN4-004 script:3 | まだ間に合います。急いで行きましょう。 | PASS | MP3 probe passed and STT matched source exactly. |
| HN4-006 script:0 | 水の深さを確認しました。 | FLAG | STT mismatch remained. |
| HN4-006 script:2 | はい。線の太さを確認できます。 | PASS | MP3 probe passed and STT matched source exactly. |
| HN4-010 script:3 | 商品が届くと、連絡が来ます。 | PASS | MP3 probe passed and STT matched source exactly. |
| HN4-011 script:1 | 厚さが違う紙がありますね。 | FLAG | STT mismatch remained. |

## Artifacts

- `docs/operations/plans/n4-human-audio-qa-source-rewrite-regeneration-plan-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-source-rewrite-regeneration-dry-run-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-source-rewrite-regeneration-results-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-source-rewrite-post-regeneration-review-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-source-rewrite-post-regeneration-recommendations-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-source-rewrite-orthographic-pass-override-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-source-rewrite-post-regeneration-audit-2026-05-18.md`

## Next

Broad N4 rollout remains on HOLD. Remaining blockers are 62 `PENDING` rows and
2 `FLAG` rows. The next useful slice is either direct listening/adjudication
for the 2 remaining `FLAG` rows or a focused pass over the 62 `PENDING` rows.
