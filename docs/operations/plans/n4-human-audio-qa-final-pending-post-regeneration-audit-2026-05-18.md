# N4 Post-Regeneration Audio Audit

> Status: REVIEW
> Scope: regenerated audio URLs from the supplied post-regeneration review CSV
> Boundary: delegated AI/STT audio QA only; not native-speaker review

ASSUMPTION: The project owner delegated this post-regeneration review because no human/native-speaker reviewer is currently available.

## Command

```bash
uv run python scripts/audit_n4_flag_post_regeneration_audio.py --review-csv ../../docs/operations/plans/n4-human-audio-qa-final-pending-post-regeneration-review-2026-05-18.csv --regeneration-results-csv ../../docs/operations/plans/n4-human-audio-qa-final-pending-regeneration-results-2026-05-18.csv --transcribe --current-verdict PENDING --csv-output ../../docs/operations/plans/n4-human-audio-qa-final-pending-post-regeneration-recommendations-2026-05-18.csv --markdown-output ../../docs/operations/plans/n4-human-audio-qa-final-pending-post-regeneration-audit-2026-05-18.md
```

## Inputs

- Review CSV: `docs/operations/plans/n4-human-audio-qa-final-pending-post-regeneration-review-2026-05-18.csv`
- Regeneration results CSV: `docs/operations/plans/n4-human-audio-qa-final-pending-regeneration-results-2026-05-18.csv`

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
| HN4-003 question:4 | 間に合わない___。 (시간에 맞지 못할지도 모릅니다.) | 間に合わないよ。時間に間に合ってないのかもしれません。 | TRANSCRIPTION_TEXT_MISMATCH:間に合わないよ。時間に間に合ってないのかもしれません。 | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/question-4-regen-20260518T070000Z.mp3) |

## Decision

REVIEW: keep unresolved regenerated rows as `FLAG` until the remaining signals are resolved by another regeneration or direct listening review.
