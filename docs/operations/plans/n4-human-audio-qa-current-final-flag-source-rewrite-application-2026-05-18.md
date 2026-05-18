# N4 Current Final FLAG Source Rewrite Application

> Status: SOURCE REWRITE APPLIED - audio QA gate clear
> Scope: the five N4 script-line rows that remained `FLAG` after the current
> final regeneration pass
> Boundary: delegated AI/STT audio QA only; not native-speaker review

ASSUMPTION: Repeated STT mismatch after multiple TTS regenerations is enough to
rewrite the source text for TTS stability, but any remaining STT divergence
must stay `FLAG` until direct listening review, waiver, or another rewrite.

## Summary

| Metric | Result |
|---|---:|
| Source-rewritten targets | 5 |
| Configured DB seed check before apply | 5 content mismatches |
| Configured DB seed apply | PASS |
| Configured DB seed check after apply | 0 mismatches |
| Regenerated source-rewrite targets | 8 total attempts |
| Machine probe pass | 8 |
| STT-assisted recommended PASS | 6 |
| STT-assisted recommended FLAG before override | 2 |
| Orthographic-only PASS override | 1 |
| Overall N4 PASS after application | 99 |
| Overall N4 PENDING after application | 0 |
| Overall N4 FLAG after application | 0 |

## Runtime Actions

1. Rewrote the five fragile source lines in the official N4 lesson JSON files.
2. Updated the matching packet rows to use the rewritten source text and Korean
   context before regeneration.
3. Ran `uv run python -m app.seeds.lessons --check --level N4`; the configured
   DB correctly reported 5 content mismatches before apply.
4. Ran `uv run python -m app.seeds.lessons --level N4`.
5. Re-ran `uv run python -m app.seeds.lessons --check --level N4`; sync passed
   with 0 content mismatches and 0 item-link mismatches.
6. Regenerated the five source-rewritten script-line TTS targets with Gemini.
7. Built a current-DB review CSV and ran STT-assisted post-regeneration audit.
8. Applied the first audit recommendations to the three N4 audio QA packet
   files, reducing the gate to two residual rows.
9. Applied v3/v4 source rewrites for the remaining HN4-006 and HN4-011 rows,
   regenerated their TTS, and re-ran STT-assisted audits.
10. Applied a canonical kana/kanji orthographic-only PASS override for
   `HN4-006 script:1`, consistent with the existing N4 packet policy.

## Result

| Target | Rewritten source | STT result | Verdict |
|---|---|---|---|
| HN4-002 script:2 | `医者に相談した方がいいです。` | exact match after normalization | PASS |
| HN4-005 script:2 | `はい。授業の予約もできます。` | exact match after normalization | PASS |
| HN4-006 script:1 | `この川の浅さがわかります。` | kana/kanji orthographic-only mismatch: `この川の浅さが分かります。` | PASS |
| HN4-008 script:2 | `会議が長かったんです。` | exact match | PASS |
| HN4-011 script:3 | `ノートの厚さと柔らかさを比べます。` | exact match after normalization | PASS |

## Artifacts

- `docs/operations/plans/n4-human-audio-qa-current-final-flag-source-rewrite-regeneration-plan-2026-05-18.md`
- `docs/operations/plans/n4-human-audio-qa-current-final-flag-source-rewrite-regeneration-plan-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-current-final-flag-source-rewrite-regeneration-dry-run-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-current-final-flag-source-rewrite-regeneration-results-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-current-final-flag-source-rewrite-current-db-results-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-current-final-flag-source-rewrite-post-regeneration-review-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-current-final-flag-source-rewrite-post-regeneration-recommendations-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-current-final-flag-source-rewrite-post-regeneration-audit-2026-05-18.md`
- `docs/operations/plans/n4-human-audio-qa-post-current-final-flag-source-rewrite-review-queue-2026-05-18.md`
- `docs/operations/plans/n4-human-audio-qa-post-current-final-flag-source-rewrite-review-queue-2026-05-18.html`
- `docs/operations/plans/n4-human-audio-qa-post-current-final-flag-source-rewrite-stt-reconciliation-2026-05-18.md`
- `docs/operations/plans/n4-human-audio-qa-post-current-final-flag-source-rewrite-stt-reconciliation-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-source-rewrite-v2-regeneration-plan-2026-05-18.md`
- `docs/operations/plans/n4-human-audio-qa-source-rewrite-v2-regeneration-plan-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-source-rewrite-v2-regeneration-dry-run-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-source-rewrite-v2-regeneration-results-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-source-rewrite-v2-current-db-results-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-source-rewrite-v2-post-regeneration-review-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-source-rewrite-v2-post-regeneration-recommendations-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-source-rewrite-v2-post-regeneration-audit-2026-05-18.md`
- `docs/operations/plans/n4-human-audio-qa-source-rewrite-v3-regeneration-plan-2026-05-18.md`
- `docs/operations/plans/n4-human-audio-qa-source-rewrite-v3-regeneration-plan-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-source-rewrite-v3-regeneration-dry-run-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-source-rewrite-v3-regeneration-results-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-source-rewrite-v3-current-db-results-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-source-rewrite-v3-post-regeneration-review-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-source-rewrite-v3-post-regeneration-recommendations-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-source-rewrite-v3-post-regeneration-audit-2026-05-18.md`
- `docs/operations/plans/n4-human-audio-qa-source-rewrite-v4-regeneration-plan-2026-05-18.md`
- `docs/operations/plans/n4-human-audio-qa-source-rewrite-v4-regeneration-plan-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-source-rewrite-v4-regeneration-dry-run-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-source-rewrite-v4-regeneration-results-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-source-rewrite-v4-current-db-results-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-source-rewrite-v4-post-regeneration-review-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-source-rewrite-v4-post-regeneration-recommendations-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-source-rewrite-v4-post-regeneration-audit-2026-05-18.md`
- `docs/operations/plans/n4-human-audio-qa-source-rewrite-v4-orthographic-pass-override-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-post-source-rewrite-v4-review-queue-2026-05-18.md`
- `docs/operations/plans/n4-human-audio-qa-post-source-rewrite-v4-review-queue-2026-05-18.html`
- `docs/operations/plans/n4-human-audio-qa-post-source-rewrite-v4-stt-reconciliation-2026-05-18.md`
- `docs/operations/plans/n4-human-audio-qa-post-source-rewrite-v4-stt-reconciliation-2026-05-18.csv`

## Decision

The delegated AI/STT N4 audio QA gate is clear:

- All 99 packet rows are `PASS`.
- No rows remain `PENDING`.
- No rows are `FLAG`, `FAIL`, or invalid.

This is still delegated AI/STT QA, not native-speaker approval.
