# N4 FLAG Post-Regeneration Audio Audit

> Status: REVIEW
> Scope: regenerated audio URLs from the supplied second-pass review CSV
> Boundary: delegated AI/STT audio QA only; not native-speaker review

ASSUMPTION: The project owner delegated this post-regeneration review because no human/native-speaker reviewer is currently available.

## Command

```bash
uv run python scripts/audit_n4_flag_post_regeneration_audio.py --review-csv docs/operations/plans/n4-human-audio-qa-flag-second-pass-review-2026-05-18.csv --regeneration-results-csv docs/operations/plans/n4-human-audio-qa-flag-regeneration-second-pass-results-2026-05-18.csv --transcribe --csv-output docs/operations/plans/n4-human-audio-qa-flag-second-pass-recommendations-2026-05-18.csv --markdown-output docs/operations/plans/n4-human-audio-qa-flag-second-pass-audit-2026-05-18.md
```

## Inputs

- Review CSV: `docs/operations/plans/n4-human-audio-qa-flag-second-pass-review-2026-05-18.csv`
- Regeneration results CSV: `docs/operations/plans/n4-human-audio-qa-flag-regeneration-second-pass-results-2026-05-18.csv`

## Summary

| Metric | Result |
|---|---:|
| Total targets | 7 |
| Machine pass | 7 |
| Blocked targets | 0 |
| Warning count | 6 |
| Transcribed targets | 7 |
| STT exact matches | 1 |
| STT mismatches | 6 |
| STT errors | 0 |
| Recommended PASS | 1 |
| Recommended FLAG | 6 |
| Unresolved/no recommendation | 0 |

## Recommendations

| Target | Japanese text | STT transcript | Signals | Recommendation | Audio |
|---|---|---|---|---|---|
| HN4-001 script:3 | 分かりました。丁寧に確認します。 | わかりました。艇中に確認します。 | TRANSCRIPTION_TEXT_MISMATCH:わかりました。艇中に確認します。 | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/script-line-3-regen-20260518T004000Z.mp3) |
| HN4-003 script:1 | じゃあ、会議に間に合わないかもしれませんね。 | じゃあ、会議に間に合わないかもしれませんね。 | none | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/script-line-1-regen-20260518T004000Z.mp3) |
| HN4-004 script:3 | 諦めないで、急いで行きましょう。 | 責めないで築いでいきましょう | TRANSCRIPTION_TEXT_MISMATCH:責めないで築いでいきましょう | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/script-line-3-regen-20260518T004000Z.mp3) |
| HN4-006 script:0 | 湖の深さを地図で確認しました。 | 小野真央を実で確認しました。 | TRANSCRIPTION_TEXT_MISMATCH:小野真央を実で確認しました。 | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/script-line-0-regen-20260518T004000Z.mp3) |
| HN4-006 script:2 | はい。線の太さや細さも見られます。 | はい、洗脳邸さや石さもみられます。 | TRANSCRIPTION_TEXT_MISMATCH:はい、洗脳邸さや石さもみられます。 | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/script-line-2-regen-20260518T004000Z.mp3) |
| HN4-010 script:3 | 荷物が届くと、メールが来ます。 | 何もずが届くとミールが来ます。 | TRANSCRIPTION_TEXT_MISMATCH:何もずが届くとミールが来ます。 | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/script-line-3-regen-20260518T004000Z.mp3) |
| HN4-011 script:1 | 厚い紙と薄い紙がありますね。 | 小財地と薄石があります | TRANSCRIPTION_TEXT_MISMATCH:小財地と薄石があります | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/script-line-1-regen-20260518T004000Z.mp3) |

## Decision

REVIEW: keep unresolved regenerated rows as `FLAG` until the remaining signals are resolved by another regeneration or direct listening review.
