# N4 Seed/TTS Rollout Preflight

> Generated: 2026-06-01T06:46:35Z
> Status: PASS
> Boundary: read-only rollout readiness check; not native-speaker approval

## Summary

| Gate | Result | Evidence |
|---|---|---|
| `curriculum_validate` | PASS | exit 0 |
| `lesson_seed_sync_check` | PASS | exit 0 |
| `tts_coverage` | PASS | exit 0 |
| `audio_qa_verdicts` | PASS | exit 0 |
| `tts_coverage` | PASS | 234/234 records; audio URL failures=0 |
| `audio_qa_verdicts` | PASS | 234/234 PASS; pending=0; flag=0; fail=0; invalid=0 |
| `audio_qa_target_coverage` | PASS | 234/234 verdict targets vs learner-facing TTS records |

## Commands

### curriculum_validate

```bash
cd /Users/kimkunwoo/WhiteMouseDev/japanese
pnpm --filter @harukoto/database curriculum:validate
```

- Exit: `0`

### lesson_seed_sync_check

```bash
cd /Users/kimkunwoo/WhiteMouseDev/japanese/apps/api
/Users/kimkunwoo/WhiteMouseDev/japanese/apps/api/.venv/bin/python3 -m app.seeds.lessons --check --level N4
```

- Exit: `0`

### tts_coverage

```bash
cd /Users/kimkunwoo/WhiteMouseDev/japanese/apps/api
/Users/kimkunwoo/WhiteMouseDev/japanese/apps/api/.venv/bin/python3 scripts/report_n4_pilot_tts_coverage.py --level N4 --timeout-seconds 10.0 --json --check-audio-urls
```

- Exit: `0`

### audio_qa_verdicts

```bash
cd /Users/kimkunwoo/WhiteMouseDev/japanese/apps/api
/Users/kimkunwoo/WhiteMouseDev/japanese/apps/api/.venv/bin/python3 scripts/report_n4_audio_qa_verdicts.py --json
```

- Exit: `0`

## Signals

- SCRIPT_LINE_TTS_RECORDS_READY: 104/104 records exist
- QUESTION_PROMPT_TTS_RECORDS_READY: 130/130 records exist
- PILOT_BATCH_TTS_RECORDS_READY: all expected script-line and question-prompt records exist
- AUDIO_URLS_READY: 234/234 checked URLs passed

## Blockers

- None

## Assumptions

- ASSUMPTION: This preflight is read-only and does not seed DB rows, generate TTS, or change packet verdicts.
- ASSUMPTION: Delegated AI/STT audio QA is not native-speaker approval.
- ASSUMPTION: GOOGLE_API_KEY is only required by separate --transcribe STT-audit flows, not by this preflight.
