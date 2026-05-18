# N4 FLAG Post-Regeneration Audio Audit

> Status: REVIEW
> Scope: regenerated audio URLs from the supplied post-regeneration review CSV
> Boundary: delegated AI/STT audio QA only; not native-speaker review

ASSUMPTION: The project owner delegated this post-regeneration review because no human/native-speaker reviewer is currently available.

## Command

```bash
uv run python scripts/audit_n4_flag_post_regeneration_audio.py --review-csv ../../docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v3-post-regeneration-review-2026-05-18.csv --regeneration-results-csv ../../docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v3-regeneration-results-2026-05-18.csv --transcribe --csv-output ../../docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v3-post-regeneration-recommendations-2026-05-18.csv --markdown-output ../../docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v3-post-regeneration-audit-2026-05-18.md
```

## Inputs

- Review CSV: `docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v3-post-regeneration-review-2026-05-18.csv`
- Regeneration results CSV: `docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v3-regeneration-results-2026-05-18.csv`

## Summary

| Metric | Result |
|---|---:|
| Total targets | 1 |
| Machine pass | 1 |
| Blocked targets | 0 |
| Warning count | 1 |
| Transcribed targets | 1 |
| STT exact matches | 0 |
| STT mismatches | 1 |
| STT errors | 0 |
| Recommended PASS | 0 |
| Recommended FLAG | 1 |
| Unresolved/no recommendation | 0 |

## Recommendations

| Target | Japanese text | STT transcript | Signals | Recommendation | Audio |
|---|---|---|---|---|---|
| HN4-011 script:1 | ノートの厚さが違いますね。 | ノートの厚さが違います。 | TRANSCRIPTION_TEXT_MISMATCH:ノートの厚さが違います。 | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/script-line-1-regen-20260518T024500Z.mp3) |

## Decision

REVIEW: keep unresolved regenerated rows as `FLAG` until the remaining signals are resolved by another regeneration or direct listening review.
