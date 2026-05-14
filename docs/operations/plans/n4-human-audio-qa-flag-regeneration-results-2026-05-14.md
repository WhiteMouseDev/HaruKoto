# N4 Audio QA FLAG Regeneration Results

> Status: REGENERATED - requires post-regeneration listening review
> Boundary: this does not clear `FLAG` verdicts, replace native-speaker review,
> or approve broad/full N4 rollout

ASSUMPTION: Regenerated audio should be treated as new review input. A row can
move out of `FLAG` only after the new audio is listened to and a verdict is
recorded through the existing CSV apply flow.

## Inputs

- Manifest: `docs/operations/plans/n4-human-audio-qa-flag-regeneration-plan-2026-05-14.csv`
- Result CSV: `docs/operations/plans/n4-human-audio-qa-flag-regeneration-results-2026-05-14.csv`
- Run id: `20260514T083500Z`

## Result Summary

| Metric | Count |
|---|---:|
| Manifest FLAG rows | 8 |
| Regenerated rows | 8 |
| Failed rows | 0 |
| DB URL matches checked after regeneration | 8 |
| New audio URLs returning audio content | 8 |

## Verification

Read-only verification checked each result row against `tts_audio` using
`target_id`, `target_type=lesson_script_line`, `field=script_line`, and
`speed=1.0`. Every database row matched the `new_audio_url` in the result CSV.
Each `new_audio_url` also returned HTTP 200 with an audio content type.

The packet verdict tracker still reports:

- PASS: 29
- PENDING: 62
- FLAG: 8
- FAIL: 0
- invalid: 0

## Gate Decision

Broad/full N4 rollout remains on hold. The 8 regenerated rows now need a
post-regeneration listening pass. If the new audio is complete and intelligible,
record `PASS` through `scripts/apply_n4_audio_qa_verdicts.py`; otherwise keep
`FLAG` or set `FAIL` with explicit notes.
