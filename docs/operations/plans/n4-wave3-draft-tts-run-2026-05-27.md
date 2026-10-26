# N4 Wave 3 Draft TTS Run - 2026-05-27

> Scope: `N4-CH05` DRAFT lessons `HN4-017` through `HN4-021`
> Boundary: generated TTS and machine/STT evidence only; not native-speaker
> approval and not a `DRAFT` to `PILOT` publish decision.

## Inputs

- lesson source:
  `packages/database/data/lessons/n4/ch05-observation-reporting-and-expectation.json`
- lessons:
  `HN4-017`, `HN4-018`, `HN4-019`, `HN4-020`, `HN4-021`
- target scope:
  20 lesson script lines and 25 question prompts

## DB Seed

```bash
uv run python -m app.seeds.lessons --level N4 --extra-content-file ../../packages/database/data/lessons/n4/ch05-observation-reporting-and-expectation.json
```

Result:

- seeded N4 chapters 1 through 5 into the API DB.
- `N4-CH05` remained `status=DRAFT` and `published=false`.
- `HN4-017` through `HN4-021` received DB lesson IDs for TTS target
  resolution.

Post-seed check:

```bash
uv run python -m app.seeds.lessons --check --level N4 --extra-content-file ../../packages/database/data/lessons/n4/ch05-observation-reporting-and-expectation.json
```

Result:

- chapters: 5
- lessons: 21
- missing lessons: 0
- content mismatches: 0
- item link mismatches: 0

## TTS Generation

```bash
uv run python scripts/generate_n4_pilot_tts_batch.py --level N4 --include-unpublished --lesson-no 17 --lesson-no 18 --lesson-no 19 --lesson-no 20 --lesson-no 21 --target-kind all --execute --continue-on-error --sleep-seconds 0.5
```

Result:

- planned missing tasks: 45
- generated: 45
- skipped existing: 0
- failed: 0
- provider/model for new audio: `elevenlabs/eleven_multilingual_v2`

## Coverage

```bash
uv run python scripts/report_n4_pilot_tts_coverage.py --level N4 --include-unpublished --check-audio-urls --timeout-seconds 10.0 --json --fail-on-missing
```

Result:

- lesson count: 21
- script-line records: 84/84
- question-prompt records: 105/105
- total records: 189/189
- checked audio URLs: 189
- reachable audio URLs: 189
- failed audio URLs: 0
- blockers: none

Provider/model coverage across all included N4 lessons:

- `elevenlabs/eleven_multilingual_v2`: 166
- `gemini/gemini-2.5-flash-preview-tts`: 23

## Audio QA

Machine audio QA without STT:

```bash
uv run python scripts/audit_n4_pilot_tts_audio_quality.py --level N4 --include-unpublished --lesson-no 17 --lesson-no 18 --lesson-no 19 --lesson-no 20 --lesson-no 21 --fail-on-blocker --markdown-output ../../docs/operations/plans/n4-wave3-draft-tts-machine-report-2026-05-27.md
```

Result:

- targets: 45
- machine pass: 45
- blockers: 0
- warnings: 0
- total audio duration: 153.184s

STT-assisted run:

```bash
uv run python scripts/audit_n4_pilot_tts_audio_quality.py --level N4 --include-unpublished --lesson-no 17 --lesson-no 18 --lesson-no 19 --lesson-no 20 --lesson-no 21 --transcribe --transcription-timeout-seconds 20 --markdown-output ../../docs/operations/plans/n4-wave3-draft-tts-stt-assist-run-2026-05-27.md
```

Result:

- targets: 45
- STT transcribed: 27
- STT exact matches: 6
- STT mismatches: 21
- STT errors: 18

Decision boundary:

- The non-STT machine audio gate is PASS.
- The STT-assisted report remains a REVIEW/BLOCK signal because STT calls
  timed out for 18 targets and produced 21 mismatches on mixed Korean/Japanese
  prompts.
- STT output is not treated as native-speaker approval. It is an automated
  triage signal for deciding whether a row needs direct listening, source
  rewrite, or regeneration before a broader rollout.

## Next Action

Before promoting `N4-CH05` from `DRAFT` to `PILOT`, triage the
STT-assisted signals in
`docs/operations/plans/n4-wave3-draft-tts-stt-assist-run-2026-05-27.md`.
