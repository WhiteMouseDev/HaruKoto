# N4 FLAG Post-Regeneration Audio Audit

> Status: PASS
> Scope: regenerated audio URLs from the supplied post-regeneration review CSV
> Boundary: delegated AI/STT audio QA only; not native-speaker review

ASSUMPTION: The project owner delegated this post-regeneration review because no human/native-speaker reviewer is currently available.

## Command

```bash
uv run python scripts/audit_n4_flag_post_regeneration_audio.py --review-csv ../../docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v4-post-regeneration-review-2026-05-18.csv --regeneration-results-csv ../../docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v4-regeneration-results-2026-05-18.csv --transcribe --csv-output ../../docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v4-post-regeneration-recommendations-2026-05-18.csv --markdown-output ../../docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v4-post-regeneration-audit-2026-05-18.md
```

## Inputs

- Review CSV: `docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v4-post-regeneration-review-2026-05-18.csv`
- Regeneration results CSV: `docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v4-regeneration-results-2026-05-18.csv`

## Summary

| Metric | Result |
|---|---:|
| Total targets | 1 |
| Machine pass | 1 |
| Blocked targets | 0 |
| Warning count | 0 |
| Transcribed targets | 1 |
| STT exact matches | 1 |
| STT mismatches | 0 |
| STT errors | 0 |
| Recommended PASS | 1 |
| Recommended FLAG | 0 |
| Unresolved/no recommendation | 0 |

## Recommendations

| Target | Japanese text | STT transcript | Signals | Recommendation | Audio |
|---|---|---|---|---|---|
| HN4-011 script:1 | ノートの厚さが違います。 | ノートの厚さが違います。 | none | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/script-line-1-regen-20260518T025500Z.mp3) |

## Decision

PASS: all regenerated FLAG rows have clean machine probe evidence and exact STT/source matches.
