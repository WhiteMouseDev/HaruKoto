# N4 Post-Regeneration Audio Audit

> Status: PASS
> Scope: regenerated audio URLs from the supplied post-regeneration review CSV
> Boundary: delegated AI/STT audio QA only; not native-speaker review

ASSUMPTION: The project owner delegated this post-regeneration review because no human/native-speaker reviewer is currently available.

## Command

```bash
uv run python scripts/audit_n4_flag_post_regeneration_audio.py --review-csv ../../docs/operations/plans/n4-wave2-draft-flag-source-rewrite-final-post-regeneration-review-2026-05-20.csv --regeneration-results-csv ../../docs/operations/plans/n4-wave2-draft-flag-source-rewrite-final-current-db-results-2026-05-20.csv --transcribe --csv-output ../../docs/operations/plans/n4-wave2-draft-flag-source-rewrite-final-audit-recommendations-2026-05-20.csv --markdown-output ../../docs/operations/plans/n4-wave2-draft-flag-source-rewrite-final-post-regeneration-audit-2026-05-20.md
```

## Inputs

- Review CSV: `docs/operations/plans/n4-wave2-draft-flag-source-rewrite-final-post-regeneration-review-2026-05-20.csv`
- Regeneration results CSV: `docs/operations/plans/n4-wave2-draft-flag-source-rewrite-final-current-db-results-2026-05-20.csv`

## Summary

| Metric | Result |
|---|---:|
| Total targets | 3 |
| Machine pass | 3 |
| Blocked targets | 0 |
| Warning count | 0 |
| Transcribed targets | 3 |
| STT exact matches | 3 |
| STT mismatches | 0 |
| STT errors | 0 |
| Recommended PASS | 3 |
| Recommended FLAG | 0 |
| Unresolved/no recommendation | 0 |

## Recommendations

| Target | Japanese text | STT transcript | Signals | Recommendation | Audio |
|---|---|---|---|---|---|
| HN4-013 script:1 | わからなければ、人に聞いてみましょう。 | わからなければ人に聞いてみましょう。 | none | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/script-line-1-regen-20260520T062700Z.mp3) |
| HN4-013 script:2 | 案内を読んでみましょう。 | 案内を読んでみましょう | none | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/script-line-2-regen-20260520T062500Z.mp3) |
| HN4-015 script:1 | 大変です。 | 大変です。 | none | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/script-line-1-regen-20260520T062000Z.mp3) |

## Decision

PASS: all regenerated rows have clean machine probe evidence and exact STT/source matches.
