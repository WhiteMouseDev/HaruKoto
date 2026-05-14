# N4 FLAG TTS Replacement Harness

> Status: EXECUTED - post-regeneration listening review required
> Boundary: this does not clear audio QA verdicts, perform native-speaker
> review, or change packet markdown by itself

ASSUMPTION: The 8 current `FLAG` rows should be regenerated into new object
paths, then listened to again before any verdict is changed.

## Source Manifest

- `docs/operations/plans/n4-human-audio-qa-flag-regeneration-plan-2026-05-14.csv`
- Current manifest scope: 8 rows, all `lesson_script_line` / `script_line`
- Current gate state after canonical PASS apply: 29 PASS, 62 PENDING, 8 FLAG

## Harness

`apps/api/scripts/regenerate_n4_audio_qa_flagged_tts.py` reads the regeneration
manifest and validates each row before it can execute:

- `current_verdict` must be `FLAG`
- post-regeneration columns must still be blank
- `lesson_id`, `target_kind`, `target_order`, `target_type`, `field`, and
  `target_id` must agree
- published lesson content must still resolve to the manifest `source_text`
- existing `tts_audio.audio_url` must still match `current_audio_url`

When executed, the script uploads a new object path such as
`tts/lesson/<lesson-id>/script-line-3-regen-<run-id>.mp3` and updates the
existing `tts_audio` row for the same target. It intentionally does not
overwrite the old object path.

## Commands

Dry-run planning:

```bash
cd apps/api
uv run python scripts/regenerate_n4_audio_qa_flagged_tts.py \
  --manifest ../../docs/operations/plans/n4-human-audio-qa-flag-regeneration-plan-2026-05-14.csv \
  --run-id dryrun-20260514
```

Optional dry-run CSV output:

```bash
cd apps/api
uv run python scripts/regenerate_n4_audio_qa_flagged_tts.py \
  --manifest ../../docs/operations/plans/n4-human-audio-qa-flag-regeneration-plan-2026-05-14.csv \
  --run-id dryrun-20260514 \
  --result-output ../../docs/operations/plans/n4-flagged-tts-replacement-dry-run-2026-05-14.csv
```

Execution, after explicit operator approval:

```bash
cd apps/api
uv run python scripts/regenerate_n4_audio_qa_flagged_tts.py \
  --manifest ../../docs/operations/plans/n4-human-audio-qa-flag-regeneration-plan-2026-05-14.csv \
  --run-id 20260514T000000Z \
  --result-output ../../docs/operations/plans/n4-flagged-tts-replacement-results-2026-05-14.csv \
  --execute \
  --continue-on-error
```

## Execution Result

`docs/operations/plans/n4-human-audio-qa-flag-regeneration-results-2026-05-14.csv`
records one execution with run id `20260514T083500Z`: 8 regenerated rows and
0 failed rows. The companion result summary is
`docs/operations/plans/n4-human-audio-qa-flag-regeneration-results-2026-05-14.md`.

## Post-Execution Gate

After replacement, the new URLs must be listened to and reviewed. Only then
should verdicts be updated through the existing CSV apply path:

```bash
cd apps/api
uv run python scripts/apply_n4_audio_qa_verdicts.py \
  --reviewed-csv ../../docs/operations/plans/<reviewed-verdicts>.csv \
  --output ../../docs/operations/plans/<application-report>.md
```

Broad/full N4 rollout remains on hold while any `PENDING`, `FLAG`, `FAIL`, or
invalid verdict remains.
