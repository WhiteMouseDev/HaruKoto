# N4 Human Audio QA Canonical PASS Application

Date: 2026-05-14
Scope: 3 `CANONICAL_MATCH` script rows from the N4 pilot human audio QA packets
Status: Applied as delegated AI-assisted `PASS` verdicts

## Review Boundary

This is a delegated AI-assisted audio QA pass, not a native-speaker review.

ASSUMPTION: The project owner delegated AI-assisted review because no human or
native-speaker reviewer is currently available. These rows had normalized STT
similarity `1.000`, and their transcript differences were orthographic only:
`ほう` vs `方`, `とき` vs `時`, and punctuation.

## Inputs

- Source batch:
  `docs/operations/plans/n4-human-audio-qa-near-canonical-review-2026-05-14.csv`
- Reviewed update CSV:
  `docs/operations/plans/n4-human-audio-qa-canonical-pass-reviewed-2026-05-14.csv`
- Apply command:
  `cd apps/api && uv run python scripts/apply_n4_audio_qa_verdicts.py --csv-input ../../docs/operations/plans/n4-human-audio-qa-canonical-pass-reviewed-2026-05-14.csv --write`

Applied note:

`Delegated AI-assisted PASS: canonical STT normalized match with orthographic-only mismatch; not native-speaker review.`

## Applied Targets

| Target | Packet | Source text | STT transcript | Similarity | Applied verdict |
|---|---|---|---|---:|---|
| HN4-002 script:1 | `n4-pilot-human-audio-qa-ch01-2026-05-13.md` | 心配ですね。今日は早く寝たほうがいいです。 | 心配ですね。今日は早く寝た方がいいです。 | 1.000 | PASS |
| HN4-002 script:3 | `n4-pilot-human-audio-qa-ch01-2026-05-13.md` | 熱があれば、医者に相談したほうが安心です。 | 熱があれば医者に相談した方が安心です。 | 1.000 | PASS |
| HN4-010 script:2 | `n4-pilot-human-audio-qa-ch02-2026-05-13.md` | はい。自然な結果を言うときに使います。 | はい、自然な結果を言う時に使います。 | 1.000 | PASS |

## Post-Apply Verdict State

`scripts/report_n4_audio_qa_verdicts.py` after application:

```text
packets 3
targets 99
pass 29
pending 62
flag 8
fail 0
waived 0
invalid 0
packet_details
- ch01: total=45 pass=14 pending=28 flag=3 fail=0 waived=0 invalid=0
- ch02: total=45 pass=14 pending=27 flag=4 fail=0 waived=0 invalid=0
- ch03: total=9 pass=1 pending=7 flag=1 fail=0 waived=0 invalid=0
blockers
- PENDING_VERDICTS: 62 target(s) still need human verdicts
- FLAG_VERDICTS: 8 target(s) need waiver or regeneration before broad rollout
```

## Batch Refresh

After applying these rows, the near/canonical focused review batch was
regenerated. It now contains 11 `NEAR_JAPANESE_MATCH` rows and 0
`CANONICAL_MATCH` rows. The mixed-prompt review batch summary was also
regenerated to show 62 remaining pending review-signal items.

## Rollout Decision

Broad/full N4 rollout remains on hold. The canonical rows are no longer
pending blockers, but 62 pending targets and 8 flagged targets still block
broader rollout.
