# N4 FLAG Post-Regeneration Audio Audit

> Status: REVIEW
> Scope: regenerated audio URLs from the supplied post-regeneration review CSV
> Boundary: delegated AI/STT audio QA only; not native-speaker review

ASSUMPTION: The project owner delegated this post-regeneration review because no human/native-speaker reviewer is currently available.

## Command

```bash
uv run python scripts/audit_n4_flag_post_regeneration_audio.py --review-csv docs/operations/plans/n4-human-audio-qa-source-rewrite-post-regeneration-review-2026-05-18.csv --regeneration-results-csv docs/operations/plans/n4-human-audio-qa-source-rewrite-regeneration-results-2026-05-18.csv --transcribe --csv-output docs/operations/plans/n4-human-audio-qa-source-rewrite-post-regeneration-recommendations-2026-05-18.csv --markdown-output docs/operations/plans/n4-human-audio-qa-source-rewrite-post-regeneration-audit-2026-05-18.md
```

## Inputs

- Review CSV: `docs/operations/plans/n4-human-audio-qa-source-rewrite-post-regeneration-review-2026-05-18.csv`
- Regeneration results CSV: `docs/operations/plans/n4-human-audio-qa-source-rewrite-regeneration-results-2026-05-18.csv`

## Summary

| Metric | Result |
|---|---:|
| Total targets | 6 |
| Machine pass | 6 |
| Blocked targets | 0 |
| Warning count | 3 |
| Transcribed targets | 6 |
| STT exact matches | 3 |
| STT mismatches | 3 |
| STT errors | 0 |
| Recommended PASS | 4 |
| Recommended FLAG | 2 |
| Unresolved/no recommendation | 0 |

## Manual Adjudication

- HN4-001 script:3 was corrected from generated `FLAG` to `PASS` because the
  transcript `わかりました。注意して確認します。` differs from
  `分かりました。注意して確認します。` only by kana/kanji orthography.

## Recommendations

| Target | Japanese text | STT transcript | Signals | Recommendation | Audio |
|---|---|---|---|---|---|
| HN4-001 script:3 | 分かりました。注意して確認します。 | わかりました。注意して確認します。 | ORTHOGRAPHIC_ONLY_MISMATCH:わかりました。注意して確認します。 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/script-line-3-regen-20260518T013503Z.mp3) |
| HN4-004 script:3 | まだ間に合います。急いで行きましょう。 | まだ間に合います。急いで行きましょう。 | none | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/script-line-3-regen-20260518T013503Z.mp3) |
| HN4-006 script:0 | 水の深さを確認しました。 | 指令の過疎を確認しました。 | TRANSCRIPTION_TEXT_MISMATCH:指令の過疎を確認しました。 | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/script-line-0-regen-20260518T013503Z.mp3) |
| HN4-006 script:2 | はい。線の太さを確認できます。 | はい、線の太さを確認できます。 | none | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/script-line-2-regen-20260518T013503Z.mp3) |
| HN4-010 script:3 | 商品が届くと、連絡が来ます。 | 商品が届くと連絡が来ます。 | none | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/script-line-3-regen-20260518T013503Z.mp3) |
| HN4-011 script:1 | 厚さが違う紙がありますね。 | とさかが違う子があります | TRANSCRIPTION_TEXT_MISMATCH:とさかが違う子があります | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/script-line-1-regen-20260518T013503Z.mp3) |

## Decision

REVIEW: clear four regenerated rows to `PASS`; keep the two unresolved
regenerated rows as `FLAG` until the remaining signals are resolved by another
regeneration or direct listening review.
