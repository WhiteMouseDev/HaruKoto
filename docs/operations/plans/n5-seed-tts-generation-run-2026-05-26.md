# N5 Seed/TTS Generation Run

> Generated: 2026-05-26
> Target DB: configured `apps/api` environment
> Boundary: actual TTS generation, GCS upload, DB `tts_audio` coverage, and
> read-only URL validation. This is not native-speaker audio approval.

ASSUMPTION: The configured `apps/api` database is the intended N5 learner-facing
audio target for this run.

ASSUMPTION: Lesson audio must be generated through the existing lesson TTS
service path, not by manually editing `tts_audio` rows.

## Summary

N5 published lesson seed sync was already clean, but lesson TTS coverage was
mostly missing before the run:

| Check | Before | After |
|---|---:|---:|
| Published N5 lessons | 50 | 50 |
| Script-line TTS records | 8/198 | 198/198 |
| Question-prompt TTS records | 0/250 | 250/250 |
| Total lesson TTS records | 8/448 | 448/448 |
| Audio URL validation | not complete | 448/448 passed |
| Remaining generation tasks | 440 | 0 |

All generated rows used the existing lesson TTS service and storage flow:

- `generate_lesson_script_line_tts`
- `generate_lesson_question_prompt_tts`
- `upload_tts_to_gcs`
- `tts_audio` cache lookup before generation
- per-target DB commit after successful upload

## Commands

Initial read-only seed sync:

```bash
cd apps/api
uv run python -m app.seeds.lessons --check --level N5
```

Result:

```text
chapters: 9
lessons: 50
missing_lessons: 0
content_mismatches: 0
item_link_mismatches: 0
```

Initial read-only TTS coverage:

```bash
cd apps/api
uv run python scripts/report_n4_pilot_tts_coverage.py --level N5 --json
```

Result:

```text
script_line_records: 8/198
question_prompt_records: 0/250
total_records: 8/448
blockers:
- SCRIPT_LINE_TTS_RECORDS_MISSING
- QUESTION_PROMPT_TTS_RECORDS_MISSING
- LESSONS_WITH_TTS_GAPS
```

Generation was executed in controlled chunks:

```bash
cd apps/api
uv run python scripts/generate_n4_pilot_tts_batch.py --level N5 --limit 1 --execute --sleep-seconds 0
uv run python scripts/generate_n4_pilot_tts_batch.py --level N5 --limit 8 --execute --sleep-seconds 0.1
uv run python scripts/generate_n4_pilot_tts_batch.py --level N5 --limit 50 --execute --sleep-seconds 0.1
uv run python scripts/generate_n4_pilot_tts_batch.py --level N5 --limit 100 --execute --sleep-seconds 0
uv run python scripts/generate_n4_pilot_tts_batch.py --level N5 --limit 100 --execute --sleep-seconds 0
uv run python scripts/generate_n4_pilot_tts_batch.py --level N5 --limit 50 --execute --sleep-seconds 0
uv run python scripts/generate_n4_pilot_tts_batch.py --level N5 --limit 50 --execute --sleep-seconds 0
uv run python scripts/generate_n4_pilot_tts_batch.py --level N5 --limit 50 --execute --sleep-seconds 0
uv run python scripts/generate_n4_pilot_tts_batch.py --level N5 --limit 50 --execute --sleep-seconds 0
```

Generation result:

```text
generated: 440
skipped_existing: 0
failed: 0
```

Final read-only coverage and URL validation:

```bash
cd apps/api
uv run python scripts/report_n4_pilot_tts_coverage.py --level N5 --json --check-audio-urls --timeout-seconds 10
```

Result:

```text
script_line_records: 198/198
question_prompt_records: 250/250
total_records: 448/448
provider_model_counts: elevenlabs/eleven_multilingual_v2 = 448
audio_url_check: 448 checked, 448 ok, 0 failed
blockers: none
```

Final missing-task dry-run:

```bash
cd apps/api
uv run python scripts/generate_n4_pilot_tts_batch.py --level N5 --limit 5 --sleep-seconds 0
```

Result:

```text
planned_missing_tasks 0
dry_run true
```

## Remaining Gates

This run closes generated audio coverage for N5 lesson script lines and question
prompts. It does not close the broader release gate.

Remaining work:

- Build N5 audio QA packet from the generated `tts_audio` rows.
- Run delegated STT/audio quality checks and record `PASS`, `FLAG`, or `FAIL`.
- Direct-listen high-risk targets, especially mixed Korean/Japanese question
  prompts and short homophone-prone lines.
- Exercise target app playback on mobile for lesson detail script lines and
  question prompt TTS.
- Keep native-speaker approval as a separate product-quality gate when a human
  reviewer is available.
