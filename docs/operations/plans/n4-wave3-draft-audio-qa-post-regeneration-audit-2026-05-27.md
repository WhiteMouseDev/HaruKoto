# N4 Post-Regeneration Audio Audit

> Status: PASS
> Scope: regenerated audio URLs from the supplied post-regeneration review CSV
> Boundary: delegated AI/STT audio QA only; not native-speaker review

ASSUMPTION: The project owner delegated this post-regeneration review because no human/native-speaker reviewer is currently available.

## Command

```bash
uv run python scripts/audit_n4_flag_post_regeneration_audio.py --review-csv ../../docs/operations/plans/n4-wave3-draft-audio-qa-post-regeneration-review-2026-05-27.csv --regeneration-results-csv ../../docs/operations/plans/n4-wave3-draft-audio-qa-current-db-regeneration-results-2026-05-27.csv --timeout-seconds 30.0 --transcribe --current-verdict PENDING --csv-output ../../docs/operations/plans/n4-wave3-draft-audio-qa-post-regeneration-recommendations-2026-05-27.csv --markdown-output ../../docs/operations/plans/n4-wave3-draft-audio-qa-post-regeneration-audit-2026-05-27.md
```

## Inputs

- Review CSV: `docs/operations/plans/n4-wave3-draft-audio-qa-post-regeneration-review-2026-05-27.csv`
- Regeneration results CSV: `docs/operations/plans/n4-wave3-draft-audio-qa-current-db-regeneration-results-2026-05-27.csv`

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
| HN4-018 script:3 | この操作は大変そうです。早めに相談しましょう。 | この操作は大変そうです。早めに相談しましょう。 | none | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/script-line-3-regen-n4ch05-cleanup-20260527.mp3) |

## Decision

PASS: all regenerated rows have clean machine probe evidence and exact STT/source matches.
