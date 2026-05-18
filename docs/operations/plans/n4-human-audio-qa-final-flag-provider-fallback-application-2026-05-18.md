# N4 Final FLAG Provider Fallback Application

> Status: PROVIDER FALLBACK + SOURCE REWRITE V4 APPLIED - rollout still HOLD
> Scope: the two N4 script-line rows that remained `FLAG` after source rewrite v2
> Boundary: delegated AI/STT audio QA only; not native-speaker review

ASSUMPTION: Provider diversity is worth trying before another source rewrite
because the previous ElevenLabs regenerations repeatedly produced lexical STT
drift. Rows should still remain `FLAG` when the regenerated audio does not
match source text exactly.

## Provider Fallback Result

Gemini TTS fallback was run for the remaining two `FLAG` rows.

| Target | Source | Audio run | STT signal | Verdict |
|---|---|---|---|---|
| HN4-006 script:0 | `この川の深さを確認しました。` | `20260518T023000Z` | exact match | PASS |
| HN4-011 script:1 | `紙の厚さが違いますね。` | `20260518T023000Z` | `TRANSCRIPTION_TEXT_MISMATCH:髪の厚さが違うね` | FLAG |

## Source Rewrite v3 Result

HN4-011 was rewritten again to avoid the `紙/髪` homophone failure mode while
staying inside the notebook comparison context.

| Target | Source rewrite v3 | Audio run | STT signal | Verdict |
|---|---|---|---|---|
| HN4-011 script:1 | `ノートの厚さが違いますね。` | `20260518T024500Z` | `TRANSCRIPTION_TEXT_MISMATCH:ノートの厚さが違います。` | FLAG |

## Source Rewrite v4 Result

The v3 audio was intelligible but consistently omitted the sentence-final
`ね`. v4 removed that discourse particle while preserving the same `さ`
nominalization target.

| Target | Source rewrite v4 | Audio run | STT signal | Verdict |
|---|---|---|---|---|
| HN4-011 script:1 | `ノートの厚さが違います。` | `20260518T025500Z` | exact match | PASS |

## Packet Summary After Application

| Metric | Result |
|---|---:|
| Packets | 3 |
| Targets | 99 |
| PASS | 37 |
| PENDING | 62 |
| FLAG | 0 |
| FAIL | 0 |
| WAIVED | 0 |
| Invalid verdicts | 0 |

## Artifacts

- `docs/operations/plans/n4-human-audio-qa-final-flag-provider-fallback-regeneration-plan-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-final-flag-provider-fallback-regeneration-dry-run-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-final-flag-provider-fallback-regeneration-results-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-final-flag-provider-fallback-post-regeneration-review-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-final-flag-provider-fallback-post-regeneration-recommendations-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-final-flag-provider-fallback-post-regeneration-audit-2026-05-18.md`
- `docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v3-regeneration-plan-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v3-regeneration-dry-run-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v3-regeneration-results-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v3-post-regeneration-review-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v3-post-regeneration-recommendations-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v3-post-regeneration-audit-2026-05-18.md`
- `docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v4-regeneration-plan-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v4-regeneration-dry-run-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v4-regeneration-results-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v4-post-regeneration-review-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v4-post-regeneration-recommendations-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v4-post-regeneration-audit-2026-05-18.md`

## Decision

Clear HN4-006 script:0 and HN4-011 script:1 to `PASS`. Broad N4 audio rollout
still remains blocked by the 62 `PENDING` rows, but there are no remaining
`FLAG` or `FAIL` rows after this pass.
