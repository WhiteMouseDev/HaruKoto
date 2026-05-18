# N4 Final FLAG Regeneration Application

> Status: FINAL FLAG REGENERATION APPLIED - rollout still HOLD
> Scope: the two N4 script-line rows that remained `FLAG` after source rewrite
> and post-regeneration audit
> Boundary: delegated AI/STT audio QA only; not native-speaker review

ASSUMPTION: A final targeted regeneration pass is useful before rewriting the
source again, but rows with continued STT divergence must remain `FLAG`.

## Summary

| Metric | Result |
|---|---:|
| Final FLAG rows regenerated | 2 |
| Machine probe pass | 2 |
| STT-assisted recommended PASS | 0 |
| STT-assisted recommended FLAG | 2 |
| Packet rows updated | 2 |
| Overall N4 PASS after application | 35 |
| Overall N4 PENDING after application | 62 |
| Overall N4 FLAG after application | 2 |

## Result

| Target | Source | Latest audio | STT signal | Verdict |
|---|---|---|---|---|
| HN4-006 script:0 | 水の深さを確認しました。 | `20260518T015416Z` | `TRANSCRIPTION_TEXT_MISMATCH:ニズノウをゼンサオを確認しました。` | FLAG |
| HN4-011 script:1 | 厚さが違う紙がありますね。 | `20260518T015416Z` | `TRANSCRIPTION_TEXT_MISMATCH:とさかちかうしがおります` | FLAG |

## Artifacts

- `docs/operations/plans/n4-human-audio-qa-final-flag-regeneration-plan-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-final-flag-regeneration-dry-run-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-final-flag-regeneration-results-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-final-flag-post-regeneration-review-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-final-flag-post-regeneration-recommendations-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-final-flag-post-regeneration-audit-2026-05-18.md`

## Decision

Do not clear these two rows by AI/STT evidence. The next useful slice is source
rewrite v2 for HN4-006 script:0 and HN4-011 script:1, followed by another
targeted seed, TTS regeneration, and audit pass.

Follow-up executed in
`docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v2-application-2026-05-18.md`.
