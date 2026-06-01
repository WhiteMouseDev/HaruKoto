# N4 CH06 Post-Merge Operational Check - 2026-06-01

## Result

Status: PASS for merged code, Cloud Run deployment, configured DB seed sync,
read-only service-path lesson exposure, authenticated remote HTTP list/detail
smoke, representative mobile target-runtime UAT, and first aggregate
pilot-feedback baseline.

Scope: `N4-CH06` / HN4-022 through HN4-026.

ASSUMPTION: The GCP Secret Manager `DATABASE_URL` used by the local check is
the same target DB used by the deployed `harukoto-api` Cloud Run service.

## Evidence

| Gate | Result | Evidence |
|---|---:|---|
| PR merge | PASS | PR #163 merged into `main` on 2026-05-29T06:13:06Z at `aedcccfcb5f633e825fb4d7a6981623cf1c014c3`. |
| Main CI | PASS | GitHub Actions `CI` run `26621397274` succeeded at `aedcccfcb5f633e825fb4d7a6981623cf1c014c3`. |
| API deploy | PASS | GitHub Actions `Deploy API` run `26621397227` succeeded at `aedcccfcb5f633e825fb4d7a6981623cf1c014c3`. |
| Cloud Run revision | PASS | `harukoto-api-00227-6sw` serves image `asia-northeast3-docker.pkg.dev/harukoto/harukoto/api:aedcccfcb5f633e825fb4d7a6981623cf1c014c3`. |
| API health | PASS | Both `https://harukoto-api-842843944454.asia-northeast3.run.app/health` and `https://harukoto-api-luvwnckhxa-du.a.run.app/health` returned `{"status":"ok"}`. |
| Configured N4 DB seed sync | PASS | `DATABASE_URL="$(gcloud secrets versions access latest --secret=DATABASE_URL)" uv run python -m app.seeds.lessons --check --level N4`: chapters 6, lessons 26, missing 0, content mismatches 0, item link mismatches 0. |
| Read-only service-path exposure | PASS | `get_chapters_data` + `get_lesson_detail_data` against the configured DB returned HN4-022 through HN4-026 in chapter 6 with 4 script lines, 5 questions, non-empty vocab/grammar, stripped answer keys, and 0 blockers. |
| Authenticated remote HTTP smoke | PASS | After adding local ignored smoke env vars, `uv run python scripts/smoke_remote_lesson_api.py ... --fail-on-blocker` returned `N4 target API smoke PASS: 26 lessons, 0 blockers`. |
| Mobile target-runtime UAT | PASS | iPhone 17 Pro Simulator iOS 26.5 completed HN4-022 detail/start/vocab TTS/dialogue TTS/recognition/matching/reorder/submit/result/retry/return-to-learning with remote API 200 responses and result 5/5. See `n4-ch06-mobile-uat-2026-06-01.md`. |
| Pilot feedback baseline | PASS | `report_lesson_pilot_feedback.py` over HN4-022 through HN4-026 found no rollback trigger: HN4-022 had 1 completion and 5 review events in the same-day UAT window, HN4-023 through HN4-026 are waiting for learner traffic, and all five lessons have complete script/question TTS records. See `n4-ch06-pilot-feedback-baseline-2026-06-01.md`. |
| Sentry API | WATCH | `HARUKOTO-API-1S` remains unresolved, last seen 2026-05-28T12:09:16Z. This predates the CH06 deploy and is not attributed to CH06. |
| Sentry web | PASS | `sentry-cli issues list -o whitemousedev -p harukoto-web --query 'is:unresolved'` returned `No issues found`. |

## CH06 Service-Path Detail Smoke

```text
HN4-022 chapter=6 detail=ok scripts=4 questions=5 vocab=5 grammar=1 answer_keys=stripped
HN4-023 chapter=6 detail=ok scripts=4 questions=5 vocab=6 grammar=1 answer_keys=stripped
HN4-024 chapter=6 detail=ok scripts=4 questions=5 vocab=6 grammar=1 answer_keys=stripped
HN4-025 chapter=6 detail=ok scripts=4 questions=5 vocab=5 grammar=1 answer_keys=stripped
HN4-026 chapter=6 detail=ok scripts=4 questions=5 vocab=4 grammar=1 answer_keys=stripped
N4 chapters=6 lessons=26 targets=5 blockers=0
```

## Authenticated Remote HTTP Smoke

Generated: 2026-06-01T01:45:34Z

Boundary: authenticated read-only list/detail API smoke; no start, submit, or
TTS generation calls.

```text
API base: https://harukoto-api-842843944454.asia-northeast3.run.app
Account: t***@test.com
Chapters: 6
Lessons: 26
Status: PASS
Blockers: None
```

| Lesson | Chapter | Chapter lesson | Result | Script lines | Questions | Vocab items | Grammar items | Answer keys stripped |
|---|---:|---:|---|---:|---:|---:|---:|---|
| `HN4-022` | 6 | 1 | PASS | 4 | 5 | 5 | 1 | yes |
| `HN4-023` | 6 | 2 | PASS | 4 | 5 | 6 | 1 | yes |
| `HN4-024` | 6 | 3 | PASS | 4 | 5 | 6 | 1 | yes |
| `HN4-025` | 6 | 4 | PASS | 4 | 5 | 5 | 1 | yes |
| `HN4-026` | 6 | 5 | PASS | 4 | 5 | 4 | 1 | yes |

## Boundary

- This check proves the merged code, deployed API image, configured DB seed
  sync, service-layer list/detail behavior, and authenticated remote HTTP
  list/detail behavior for CH06.
- The linked mobile UAT proves one representative HN4-022 simulator
  target-runtime happy path across detail, TTS, quiz, submit/result, retry, and
  return-to-learning.
- The linked pilot-feedback baseline proves no aggregate configured-DB rollback
  trigger in the first 14-day monitor window.
- It does not replace physical-device proof, every-lesson mobile UAT, or
  native-speaker/formal human curriculum approval.

## Next Gates

1. Continue CH06 pilot-feedback refreshes over time.
2. Keep native-speaker/human approval as a separate post-pilot quality gate.
