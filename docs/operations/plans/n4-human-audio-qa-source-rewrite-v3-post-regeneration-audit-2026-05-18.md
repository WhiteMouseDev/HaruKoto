# N4 Post-Regeneration Audio Audit

> Status: REVIEW
> Scope: regenerated audio URLs from the supplied post-regeneration review CSV
> Boundary: delegated AI/STT audio QA only; not native-speaker review

ASSUMPTION: The project owner delegated this post-regeneration review because no human/native-speaker reviewer is currently available.

## Command

```bash
uv run python scripts/audit_n4_flag_post_regeneration_audio.py --review-csv ../../docs/operations/plans/n4-human-audio-qa-source-rewrite-v3-post-regeneration-review-2026-05-18.csv --regeneration-results-csv ../../docs/operations/plans/n4-human-audio-qa-source-rewrite-v3-current-db-results-2026-05-18.csv --transcribe --current-verdict FLAG --csv-output ../../docs/operations/plans/n4-human-audio-qa-source-rewrite-v3-post-regeneration-recommendations-2026-05-18.csv --markdown-output ../../docs/operations/plans/n4-human-audio-qa-source-rewrite-v3-post-regeneration-audit-2026-05-18.md
```

## Inputs

- Review CSV: `docs/operations/plans/n4-human-audio-qa-source-rewrite-v3-post-regeneration-review-2026-05-18.csv`
- Regeneration results CSV: `docs/operations/plans/n4-human-audio-qa-source-rewrite-v3-current-db-results-2026-05-18.csv`

## Summary

| Metric | Result |
|---|---:|
| Total targets | 2 |
| Machine pass | 2 |
| Blocked targets | 0 |
| Warning count | 1 |
| Transcribed targets | 2 |
| STT exact matches | 1 |
| STT mismatches | 1 |
| STT errors | 0 |
| Recommended PASS | 1 |
| Recommended FLAG | 1 |
| Unresolved/no recommendation | 0 |

## Recommendations

| Target | Japanese text | STT transcript | Signals | Recommendation | Audio |
|---|---|---|---|---|---|
| HN4-006 script:1 | この川の浅さもわかります。 | この川の浅さも | TRANSCRIPTION_TEXT_MISMATCH:この川の浅さも | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/script-line-1-regen-20260518T080329Z.mp3) |
| HN4-011 script:3 | ノートの厚さと柔らかさを比べます。 | ノートの厚さと柔らかさを比べます | none | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/script-line-3-regen-20260518T080329Z.mp3) |

## Decision

REVIEW: keep unresolved regenerated rows as `FLAG` until the remaining signals are resolved by another regeneration or direct listening review.
