# N4 Post-Regeneration Audio Audit

> Status: REVIEW
> Scope: regenerated audio URLs from the supplied post-regeneration review CSV
> Boundary: delegated AI/STT audio QA only; not native-speaker review

ASSUMPTION: The project owner delegated this post-regeneration review because no human/native-speaker reviewer is currently available.

## Command

```bash
uv run python scripts/audit_n4_flag_post_regeneration_audio.py --review-csv ../../docs/operations/plans/n4-wave3-draft-lexical-risk-second-post-regeneration-review-2026-05-27.csv --regeneration-results-csv ../../docs/operations/plans/n4-wave3-draft-lexical-risk-second-current-db-regeneration-results-2026-05-27.csv --timeout-seconds 30.0 --transcribe --current-verdict FLAG --csv-output ../../docs/operations/plans/n4-wave3-draft-lexical-risk-second-post-regeneration-recommendations-2026-05-27.csv --markdown-output ../../docs/operations/plans/n4-wave3-draft-lexical-risk-second-post-regeneration-audit-2026-05-27.md
```

## Inputs

- Review CSV: `docs/operations/plans/n4-wave3-draft-lexical-risk-second-post-regeneration-review-2026-05-27.csv`
- Regeneration results CSV: `docs/operations/plans/n4-wave3-draft-lexical-risk-second-current-db-regeneration-results-2026-05-27.csv`

## Summary

| Metric | Result |
|---|---:|
| Total targets | 2 |
| Machine pass | 2 |
| Blocked targets | 0 |
| Warning count | 2 |
| Transcribed targets | 2 |
| STT exact matches | 0 |
| STT mismatches | 2 |
| STT errors | 0 |
| Recommended PASS | 0 |
| Recommended FLAG | 2 |
| Unresolved/no recommendation | 0 |

## Recommendations

| Target | Japanese text | STT transcript | Signals | Recommendation | Audio |
|---|---|---|---|---|---|
| HN4-018 script:0 | この機械は壊れそうです。 | この機械は、壊れそう。 | TRANSCRIPTION_TEXT_MISMATCH:この機械は、壊れそう。 | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/script-line-0-regen-n4ch05-lexical2-20260527.mp3) |
| HN4-019 script:3 | 受付は混むそうですから、早く行きましょう。 | てこれまではタコむそうでしたから、早く行きましょう。 | TRANSCRIPTION_TEXT_MISMATCH:てこれまではタコむそうでしたから、早く行きましょう。 | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/script-line-3-regen-n4ch05-lexical2-20260527.mp3) |

## Decision

REVIEW: keep unresolved regenerated rows as `FLAG` until the remaining signals are resolved by another regeneration or direct listening review.
