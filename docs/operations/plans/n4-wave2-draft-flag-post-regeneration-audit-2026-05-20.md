# N4 Post-Regeneration Audio Audit

> Status: REVIEW
> Scope: regenerated audio URLs from the supplied post-regeneration review CSV
> Boundary: delegated AI/STT audio QA only; not native-speaker review

ASSUMPTION: The project owner delegated this post-regeneration review because no human/native-speaker reviewer is currently available.

## Command

```bash
uv run python scripts/audit_n4_flag_post_regeneration_audio.py --review-csv ../../docs/operations/plans/n4-wave2-draft-flag-post-regeneration-review-2026-05-20.csv --regeneration-results-csv ../../docs/operations/plans/n4-wave2-draft-flag-current-db-results-2026-05-20.csv --transcribe --current-verdict FLAG --csv-output ../../docs/operations/plans/n4-wave2-draft-flag-post-regeneration-recommendations-2026-05-20.csv --markdown-output ../../docs/operations/plans/n4-wave2-draft-flag-post-regeneration-audit-2026-05-20.md
```

## Inputs

- Review CSV: `docs/operations/plans/n4-wave2-draft-flag-post-regeneration-review-2026-05-20.csv`
- Regeneration results CSV: `docs/operations/plans/n4-wave2-draft-flag-current-db-results-2026-05-20.csv`

## Summary

| Metric | Result |
|---|---:|
| Total targets | 3 |
| Machine pass | 3 |
| Blocked targets | 0 |
| Warning count | 3 |
| Transcribed targets | 3 |
| STT exact matches | 0 |
| STT mismatches | 3 |
| STT errors | 0 |
| Recommended PASS | 0 |
| Recommended FLAG | 3 |
| Unresolved/no recommendation | 0 |

## Recommendations

| Target | Japanese text | STT transcript | Signals | Recommendation | Audio |
|---|---|---|---|---|---|
| HN4-013 script:1 | 分からなければ、受付で聞いてみましょう。 | 分からなければ 手ホクで聞いてみましょう。 | TRANSCRIPTION_TEXT_MISMATCH:分からなければ 手ホクで聞いてみましょう。 | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/script-line-1-regen-20260520T104500Z.mp3) |
| HN4-013 script:2 | 案内の紙も読んでみます。 | 案内の下を読んでみます。 | TRANSCRIPTION_TEXT_MISMATCH:案内の下を読んでみます。 | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/script-line-2-regen-20260520T104500Z.mp3) |
| HN4-015 script:1 | それは心配ですね。 | それは心配です | TRANSCRIPTION_TEXT_MISMATCH:それは心配です | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/script-line-1-regen-20260520T104500Z.mp3) |

## Decision

REVIEW: keep unresolved regenerated rows as `FLAG` until the remaining signals are resolved by another regeneration or direct listening review.
