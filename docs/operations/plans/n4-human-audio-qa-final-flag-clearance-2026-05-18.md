# N4 Final FLAG Clearance

> Status: FINAL FLAG CLEARED - broad rollout still HOLD on pending human QA
> Scope: the two N4 script-line rows that remained `FLAG` after source rewrite v2
> Boundary: delegated AI/STT audio QA only; not native-speaker review

ASSUMPTION: STT exact match plus MP3 probe success is acceptable delegated
evidence for clearing the remaining machine-detected `FLAG` rows, while
non-reviewed rows must remain `PENDING` for human QA.

## Resolution Summary

| Target | Final source | Final audio run | Provider | STT result | Applied verdict |
|---|---|---|---|---|---|
| HN4-006 script:0 | `この川の深さを確認しました。` | `20260518T023000Z` | Gemini TTS | exact match | PASS |
| HN4-011 script:1 | `ノートの厚さが違います。` | `20260518T025500Z` | Gemini TTS | exact match | PASS |

## Decision Log

- HN4-006 cleared after provider fallback because Gemini TTS produced an exact
  STT match for the v2 source text.
- HN4-011 did not clear on provider fallback because `紙` was still transcribed
  as the homophone `髪`.
- HN4-011 source was narrowed to the existing notebook context:
  `ノートの厚さが違いますね。`, then finally `ノートの厚さが違います。`
  after STT consistently omitted the sentence-final `ね`.
- HN4-006 question prompts 3 and 5 were refreshed because source rewrite v2
  replaced the old `湖` / `호수` prompt text with the river context.

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

## Remaining Gate

Do not call N4 audio QA broadly complete yet. There are still 62 `PENDING`
targets that need human review, but the prior `FLAG` blocker is cleared without
using waivers.
