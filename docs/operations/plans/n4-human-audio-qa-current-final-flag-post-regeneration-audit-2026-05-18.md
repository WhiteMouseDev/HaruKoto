# N4 Post-Regeneration Audio Audit

> Status: REVIEW
> Scope: regenerated audio URLs from the supplied post-regeneration review CSV
> Boundary: delegated AI/STT audio QA only; not native-speaker review

ASSUMPTION: The project owner delegated this post-regeneration review because no human/native-speaker reviewer is currently available.

## Command

```bash
uv run python scripts/audit_n4_flag_post_regeneration_audio.py --review-csv ../../docs/operations/plans/n4-human-audio-qa-current-final-flag-post-regeneration-review-2026-05-18.csv --regeneration-results-csv ../../docs/operations/plans/n4-human-audio-qa-current-final-flag-regeneration-results-2026-05-18.csv --transcribe --current-verdict FLAG --csv-output ../../docs/operations/plans/n4-human-audio-qa-current-final-flag-post-regeneration-recommendations-2026-05-18.csv --markdown-output ../../docs/operations/plans/n4-human-audio-qa-current-final-flag-post-regeneration-audit-2026-05-18.md
```

## Inputs

- Review CSV: `docs/operations/plans/n4-human-audio-qa-current-final-flag-post-regeneration-review-2026-05-18.csv`
- Regeneration results CSV: `docs/operations/plans/n4-human-audio-qa-current-final-flag-regeneration-results-2026-05-18.csv`

## Summary

| Metric | Result |
|---|---:|
| Total targets | 5 |
| Machine pass | 5 |
| Blocked targets | 0 |
| Warning count | 5 |
| Transcribed targets | 5 |
| STT exact matches | 0 |
| STT mismatches | 5 |
| STT errors | 0 |
| Recommended PASS | 0 |
| Recommended FLAG | 5 |
| Unresolved/no recommendation | 0 |

## Recommendations

| Target | Japanese text | STT transcript | Signals | Recommendation | Audio |
|---|---|---|---|---|---|
| HN4-002 script:2 | 医者に相談したほうがいいですか。 | 医者に相談した方がいいですか？ | TRANSCRIPTION_TEXT_MISMATCH:医者に相談した方がいいですか？ | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/script-line-2-regen-20260518T074847Z.mp3) |
| HN4-005 script:2 | はい。授業の予約にも申し込めます。 | はい、授業の予約にも申し込みます。 | TRANSCRIPTION_TEXT_MISMATCH:はい、授業の予約にも申し込みます。 | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/script-line-2-regen-20260518T074847Z.mp3) |
| HN4-006 script:1 | この川の浅さも分かりますか。 | この川の浅さも分かります。 | TRANSCRIPTION_TEXT_MISMATCH:この川の浅さも分かります。 | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/script-line-1-regen-20260518T074847Z.mp3) |
| HN4-008 script:2 | 会議が長かったのです。 | 会議が長かった | TRANSCRIPTION_TEXT_MISMATCH:会議が長かった | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/script-line-2-regen-20260518T074847Z.mp3) |
| HN4-011 script:3 | 厚さと柔らかさを比べて選びましょう。 | 暑さと柔らかさを比べて選びましょう。 | TRANSCRIPTION_TEXT_MISMATCH:暑さと柔らかさを比べて選びましょう。 | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/script-line-3-regen-20260518T074847Z.mp3) |

## Decision

REVIEW: keep unresolved regenerated rows as `FLAG` until the remaining signals are resolved by another regeneration or direct listening review.
