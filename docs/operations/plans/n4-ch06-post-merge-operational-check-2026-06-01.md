# N4 CH06 Post-Merge Operational Check - 2026-06-01

## Result

Status: PASS for merged code, Cloud Run deployment, configured DB seed sync,
and read-only service-path lesson exposure. One evidence gap remains:
authenticated remote HTTP list/detail smoke could not run because the smoke
account environment variables are not configured in this shell.

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
| Authenticated remote HTTP smoke | BLOCKED | `uv run python scripts/smoke_remote_lesson_api.py ... --fail-on-blocker` exited 1 because `HARUKOTO_SMOKE_EMAIL` and `HARUKOTO_SMOKE_PASSWORD` are missing. |
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

## Boundary

- This check proves the merged code, deployed API image, configured DB seed
  sync, and service-layer list/detail behavior for CH06.
- It does not prove an end-to-end authenticated HTTP request through Supabase
  sign-in because the smoke credentials are absent.
- It does not replace mobile target-runtime UAT or native-speaker/formal human
  curriculum approval.

## Next Gates

1. Configure a non-secret smoke account path for `HARUKOTO_SMOKE_EMAIL` and
   `HARUKOTO_SMOKE_PASSWORD`, then rerun `scripts/smoke_remote_lesson_api.py`
   against HN4-022 through HN4-026.
2. Run mobile target-runtime UAT for the N4 lesson list, CH06 lesson detail,
   TTS playback, quiz submit/result, wrong-answer retry, and return-to-learning
   flow.
3. Create the first CH06 pilot feedback baseline after learner traffic appears.
