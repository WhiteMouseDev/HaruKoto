# N4 Current Final FLAG Regeneration Application

> Status: CURRENT FINAL FLAG REGENERATION APPLIED - rollout still HOLD
> Scope: the five N4 script-line rows that remained `FLAG` after the prior
> final pending cleanup
> Boundary: delegated AI/STT audio QA only; not native-speaker review

ASSUMPTION: The project owner delegated one more targeted regeneration and
STT-assisted audit pass, but rows with continued source/transcript divergence
must remain `FLAG` until direct listening review, waiver, or source rewrite.

## Summary

| Metric | Result |
|---|---:|
| Current final FLAG rows regenerated | 5 |
| TTS provider | Gemini |
| Audio run | `20260518T074847Z` |
| Machine probe pass | 5 |
| STT-assisted recommended PASS | 0 |
| STT-assisted recommended FLAG | 5 |
| Packet rows updated | 5 |
| Overall N4 PASS after application | 94 |
| Overall N4 PENDING after application | 0 |
| Overall N4 FLAG after application | 5 |

## Result

| Target | Source | Latest audio | STT signal | Verdict |
|---|---|---|---|---|
| HN4-002 script:2 | `医者に相談したほうがいいですか。` | `20260518T074847Z` | `TRANSCRIPTION_TEXT_MISMATCH:医者に相談した方がいいですか？` | FLAG |
| HN4-005 script:2 | `はい。授業の予約にも申し込めます。` | `20260518T074847Z` | `TRANSCRIPTION_TEXT_MISMATCH:はい、授業の予約にも申し込みます。` | FLAG |
| HN4-006 script:1 | `この川の浅さも分かりますか。` | `20260518T074847Z` | `TRANSCRIPTION_TEXT_MISMATCH:この川の浅さも分かります。` | FLAG |
| HN4-008 script:2 | `会議が長かったのです。` | `20260518T074847Z` | `TRANSCRIPTION_TEXT_MISMATCH:会議が長かった` | FLAG |
| HN4-011 script:3 | `厚さと柔らかさを比べて選びましょう。` | `20260518T074847Z` | `TRANSCRIPTION_TEXT_MISMATCH:暑さと柔らかさを比べて選びましょう。` | FLAG |

## Artifacts

- `docs/operations/plans/n4-human-audio-qa-final-flag-cleanup-regeneration-plan-2026-05-18.md`
- `docs/operations/plans/n4-human-audio-qa-final-flag-cleanup-regeneration-plan-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-current-final-flag-regeneration-plan-2026-05-18.md`
- `docs/operations/plans/n4-human-audio-qa-current-final-flag-regeneration-plan-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-current-final-flag-regeneration-dry-run-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-current-final-flag-regeneration-results-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-current-final-flag-current-db-results-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-current-final-flag-post-regeneration-review-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-current-final-flag-post-regeneration-recommendations-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-current-final-flag-post-regeneration-audit-2026-05-18.md`
- `docs/operations/plans/n4-human-audio-qa-post-current-final-flag-cleanup-review-queue-2026-05-18.md`
- `docs/operations/plans/n4-human-audio-qa-post-current-final-flag-cleanup-review-queue-2026-05-18.html`
- `docs/operations/plans/n4-human-audio-qa-post-current-final-flag-cleanup-stt-reconciliation-2026-05-18.md`
- `docs/operations/plans/n4-human-audio-qa-post-current-final-flag-cleanup-stt-reconciliation-2026-05-18.csv`

## Decision

Do not clear these five rows by delegated AI/STT evidence. Broad N4 audio
rollout remains blocked by `FLAG_VERDICTS: 5`.

The next useful slice is content-level adjudication:

- direct listening review can waive rows where STT mismatch is orthographic or
  punctuation-only;
- rows with semantic drift should be source-rewritten and regenerated;
- no remaining rows are `PENDING`, so the blocker is now limited to these five
  explicit `FLAG` decisions.
