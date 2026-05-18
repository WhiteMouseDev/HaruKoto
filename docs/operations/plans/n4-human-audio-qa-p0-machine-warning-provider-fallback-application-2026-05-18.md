# N4 P0 Machine-Warning Provider Fallback Application

> Status: APPLIED - P0 provider fallback mostly cleared
> Boundary: delegated AI/STT audio QA only; not native-speaker approval

ASSUMPTION: After provider fallback regeneration, a P0 mixed Japanese/Korean
cloze prompt can be cleared when the MP3 probe has no blocker or silence
warning and the only remaining signal is STT mismatch. STT remains weak
evidence for these mixed prompt rows.

## Inputs

- Batch manifest: `docs/operations/plans/n4-human-audio-qa-p0-machine-warning-provider-fallback-regeneration-plan-2026-05-18.csv`
- Current DB regeneration results: `docs/operations/plans/n4-human-audio-qa-p0-machine-warning-provider-fallback-current-db-results-2026-05-18.csv`
- Post-regeneration review CSV: `docs/operations/plans/n4-human-audio-qa-p0-machine-warning-provider-fallback-post-regeneration-review-2026-05-18.csv`
- Post-regeneration audit: `docs/operations/plans/n4-human-audio-qa-p0-machine-warning-provider-fallback-post-regeneration-audit-2026-05-18.md`
- Audit recommendation CSV: `docs/operations/plans/n4-human-audio-qa-p0-machine-warning-provider-fallback-post-regeneration-recommendations-2026-05-18.csv`
- Apply clearance CSV: `docs/operations/plans/n4-human-audio-qa-p0-machine-warning-provider-fallback-clearance-2026-05-18.csv`

## Execution

Initial regeneration with provider fallback completed for part of the batch and
failed for several Gemini TTS calls. A later retry detected DB drift on the last
two targets because those rows had already been regenerated to `-regen-` URLs,
so the current DB state was used to build the final review and result CSVs.

The STT-assisted post-regeneration audit reported:

| Metric | Result |
|---|---:|
| Total targets | 11 |
| Machine pass | 11 |
| Transcribed targets | 11 |
| STT exact matches | 0 |
| STT mismatches | 11 |
| Recommended PASS | 0 |
| Recommended FLAG | 11 |

Because every regenerated mixed prompt still produced STT mismatch, applying
the raw audit recommendation CSV would have converted all 11 rows to `FLAG`.
The clearance step instead kept rows with post-regeneration silence warnings
pending and cleared only rows whose remaining signal was mixed-prompt STT
mismatch:

| Metric | Result |
|---|---:|
| Clearance rows | 11 |
| PASS rows | 10 |
| Held PENDING rows | 1 |

The final apply command was run in dry-run mode first, then with `--write`:

```bash
uv run python scripts/apply_n4_audio_qa_verdicts.py \
  --csv-input ../../docs/operations/plans/n4-human-audio-qa-p0-machine-warning-provider-fallback-clearance-2026-05-18.csv

uv run python scripts/apply_n4_audio_qa_verdicts.py \
  --csv-input ../../docs/operations/plans/n4-human-audio-qa-p0-machine-warning-provider-fallback-clearance-2026-05-18.csv \
  --write
```

The final write matched 11 rows and changed the remaining held row back to
`PENDING` after provider/model metadata was synchronized.

## Result

After application, `scripts/report_n4_audio_qa_verdicts.py` reports:

| Metric | Count |
|---|---:|
| Total targets | 99 |
| PASS | 93 |
| PENDING | 1 |
| FLAG | 5 |
| FAIL | 0 |

Remaining blockers:

- `PENDING_VERDICTS`: 1 target still needs direct listening or another
  regeneration because `HIGH_SILENCE_RATIO` remains after provider fallback.
- `FLAG_VERDICTS`: 5 target(s) need direct listening, waiver, or another
  regeneration before broad rollout.

## Follow-Up Artifacts

- Post-application review queue: `docs/operations/plans/n4-human-audio-qa-post-p0-provider-fallback-review-queue-2026-05-18.md`
- Post-application review sheet: `docs/operations/plans/n4-human-audio-qa-post-p0-provider-fallback-review-queue-2026-05-18.html`
- Post-application STT reconciliation: `docs/operations/plans/n4-human-audio-qa-post-p0-provider-fallback-stt-reconciliation-2026-05-18.md`
- Post-application STT reconciliation CSV: `docs/operations/plans/n4-human-audio-qa-post-p0-provider-fallback-stt-reconciliation-2026-05-18.csv`

## Decision

The large P0 pending batch is reduced from 11 rows to one held row. N4 broad
rollout remains blocked until the single pending question prompt and five
script-line FLAG rows are resolved.
