# N4 Post-Regeneration Audio Audit

> Status: REVIEW
> Scope: regenerated audio URLs from the supplied post-regeneration review CSV
> Boundary: delegated AI/STT audio QA only; not native-speaker review

ASSUMPTION: The project owner delegated this post-regeneration review because no human/native-speaker reviewer is currently available.

## Command

```bash
uv run python scripts/audit_n4_flag_post_regeneration_audio.py --review-csv ../../docs/operations/plans/n4-wave3-draft-final-post-regeneration-review-2026-05-27.csv --regeneration-results-csv ../../docs/operations/plans/n4-wave3-draft-final-regeneration-results-2026-05-27.csv --timeout-seconds 30.0 --transcribe --current-verdict PENDING --csv-output ../../docs/operations/plans/n4-wave3-draft-final-post-regeneration-recommendations-2026-05-27.csv --markdown-output ../../docs/operations/plans/n4-wave3-draft-final-post-regeneration-audit-2026-05-27.md
```

## Inputs

- Review CSV: `docs/operations/plans/n4-wave3-draft-final-post-regeneration-review-2026-05-27.csv`
- Regeneration results CSV: `docs/operations/plans/n4-wave3-draft-final-regeneration-results-2026-05-27.csv`

## Summary

| Metric | Result |
|---|---:|
| Total targets | 5 |
| Machine pass | 5 |
| Blocked targets | 0 |
| Warning count | 4 |
| Transcribed targets | 5 |
| STT exact matches | 1 |
| STT mismatches | 4 |
| STT errors | 0 |
| Recommended PASS | 1 |
| Recommended FLAG | 4 |
| Unresolved/no recommendation | 0 |

## Recommendations

| Target | Japanese text | STT transcript | Signals | Recommendation | Audio |
|---|---|---|---|---|---|
| HN4-020 script:0 | 約束は守るものです。 | 約束は守るもの | TRANSCRIPTION_TEXT_MISMATCH:約束は守るもの | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/script-line-0-regen-n4ch05-final-20260527.mp3) |
| HN4-020 script:2 | 挨拶は普通、先にするものです。 | 挨拶は普通、善にするものです。 | TRANSCRIPTION_TEXT_MISMATCH:挨拶は普通、善にするものです。 | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/script-line-2-regen-n4ch05-final-20260527.mp3) |
| HN4-021 script:0 | 予約したので、席はあるはずです。 | 予約したので、昔はあるはずです。 | TRANSCRIPTION_TEXT_MISMATCH:予約したので、昔はあるはずです。 | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/script-line-0-regen-n4ch05-final-20260527.mp3) |
| HN4-021 script:2 | 会議の予定は午後に決まるはずです。 | 会議の予定は午後に決まるはずです。 | none | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/script-line-2-regen-n4ch05-final-20260527.mp3) |
| HN4-021 script:3 | 準備はできそうですね。 | 準備はできそうね。 | TRANSCRIPTION_TEXT_MISMATCH:準備はできそうね。 | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/script-line-3-regen-n4ch05-final-20260527.mp3) |

## Decision

REVIEW: keep unresolved regenerated rows as `FLAG` until the remaining signals are resolved by another regeneration or direct listening review.
