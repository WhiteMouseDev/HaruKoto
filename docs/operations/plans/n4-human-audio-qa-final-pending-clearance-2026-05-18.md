# N4 P0 Provider Fallback Clearance

> Status: APPLY CSV GENERATED
> Boundary: delegated AI-assisted verdicts only; not native-speaker approval

ASSUMPTION: After provider fallback regeneration, a P0 mixed Japanese/Korean
cloze prompt can be cleared when the MP3 probe has no blocker or silence
warning and the only remaining signal is STT mismatch. STT remains weak
evidence for these mixed prompt rows.

## Inputs

- Post-regeneration recommendation CSV: `docs/operations/plans/n4-human-audio-qa-final-pending-post-regeneration-recommendations-2026-05-18.csv`
- Regeneration results CSV: `docs/operations/plans/n4-human-audio-qa-final-pending-regeneration-results-2026-05-18.csv`

## Summary

| Metric | Count |
|---|---:|
| Total rows | 1 |
| PASS rows | 1 |
| Held rows | 0 |

## Decisions

| Target | Decision | Basis | Provider/model | Audio |
|---|---|---|---|---|
| HN4-003 question:4 | PASS | provider fallback machine pass; STT mismatch only | gemini / gemini-2.5-flash-preview-tts | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/question-4-regen-20260518T070000Z.mp3) |

## Decision

Apply the companion CSV to update regenerated audio URLs, clear rows that
only have mixed-prompt STT mismatch remaining, and keep any row with
post-regeneration silence warning pending.
