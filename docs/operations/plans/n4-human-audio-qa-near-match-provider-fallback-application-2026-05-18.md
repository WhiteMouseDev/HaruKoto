# N4 Near-Match Provider Fallback Application

> Status: APPLIED - rollout still HOLD
> Scope: 11 N4 script-line rows that remained `PENDING` after mixed-prompt clearance
> Date: 2026-05-18

## Boundary

This pass handles only `NEAR_JAPANESE_MATCH` script-line rows. These rows were
too risky for automatic PASS because the STT transcript was close to the source
but could still change sentence mood, lexical target, or the spoken word.

ASSUMPTION: Provider fallback can clear a near-match row only when the
regenerated audio passes the machine probe and the STT transcript matches the
source text exactly. Continued STT divergence remains a review blocker and is
recorded as `FLAG`.

## Application Summary

| Metric | Count |
|---|---:|
| Previous PASS | 77 |
| Previous PENDING | 22 |
| Previous FLAG | 0 |
| Near-match fallback regenerated | 11 |
| Post-regeneration PASS | 6 |
| Post-regeneration FLAG | 5 |
| Current PASS | 83 |
| Current PENDING | 11 |
| Current FLAG | 5 |
| Current FAIL | 0 |

## Applied Evidence

- Near-match review batch: `docs/operations/plans/n4-human-audio-qa-near-match-review-2026-05-18.md`
- Provider fallback plan: `docs/operations/plans/n4-human-audio-qa-near-match-provider-fallback-regeneration-plan-2026-05-18.csv`
- Provider fallback dry-run: `docs/operations/plans/n4-human-audio-qa-near-match-provider-fallback-regeneration-dry-run-2026-05-18.csv`
- Provider fallback results: `docs/operations/plans/n4-human-audio-qa-near-match-provider-fallback-regeneration-results-2026-05-18.csv`
- Post-regeneration audit: `docs/operations/plans/n4-human-audio-qa-near-match-provider-fallback-post-regeneration-audit-2026-05-18.md`
- Post-regeneration recommendations: `docs/operations/plans/n4-human-audio-qa-near-match-provider-fallback-post-regeneration-recommendations-2026-05-18.csv`
- Post-application review queue: `docs/operations/plans/n4-human-audio-qa-post-near-match-fallback-review-queue-2026-05-18.md`
- Post-application STT reconciliation: `docs/operations/plans/n4-human-audio-qa-post-near-match-fallback-stt-reconciliation-2026-05-18.md`

## Cleared Rows

- `HN4-002 script:0`
- `HN4-004 script:0`
- `HN4-004 script:1`
- `HN4-005 script:1`
- `HN4-011 script:0`
- `HN4-011 script:2`

## New FLAG Rows

- `HN4-002 script:2`
- `HN4-005 script:2`
- `HN4-006 script:1`
- `HN4-008 script:2`
- `HN4-011 script:3`

## Remaining Pending Rows

The 11 remaining `PENDING` rows are still the high-silence question prompts
from the previous mixed-prompt clearance pass. They need direct listening,
regeneration, or explicit waiver before broad rollout.

## Decision

Near-match script-line fallback reduced the N4 QA blocker set from 22
`PENDING` rows to 11 `PENDING` question rows plus 5 `FLAG` script rows. Broad
N4 rollout remains blocked until both groups are resolved.
