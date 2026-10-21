# Read only review event partition inspection

## Scope and authorization

On 2026-10-21 the user approved implementing a read-only partition inspector and regression tests first, preserving existing learning records and the Data API restriction. Any required production DB-role/grant or cloud configuration change must be presented as a concrete proposal before application. The user also requested blog-ready records of prior problems, design choices, fixes and verification.

This change adds an explicitly invoked CLI and typed internal inspection logic. It does not introduce an HTTP endpoint, migration, production dependency, environment-variable contract, runtime DDL, scheduler or notification integration. Production DB access is outside the implementation verification scope; PostgreSQL integration tests use disposable local databases only.

## Implementation plan

1. Reuse the clean attached checkout on `codex/read-only-partition-check`, based on main `a6fc41f6d86edd6582c1421ffa1dd0591bc55526`. Preserve all unrelated changes in the original checkout.
2. Backend owner implements catalog-only inspection under a bounded read-only consistent transaction. Explicitly use the existing `DATABASE_URL` without importing application configuration or automatically loading `.env` files.
3. Inspect the exact public parent, real monthly attachments and UTC bounds, continuous historical/current/future coverage, expected inherited indexes, RLS and effective client privileges, DDL security guard and empty PostgREST schema configuration. Do not equate catalog checks with verification of the platform Data API toggle.
4. Return safe structured results with stable exit semantics. DB failures, permission failures and timeouts must return an unknown/failure result, without credentials, raw exception messages or customer data.
5. Cover middle gaps, future warnings, UTC/calendar boundaries, unexpected catalog state, privilege drift, read-only enforcement and preservation of synthetic learning data/security with unit and real PostgreSQL regressions. Add critical real-PostgreSQL cases to the existing CI no-skip gate.
6. Independent reviewer checks transaction safety, coverage, privilege checks and error handling. Run affected API lint/format/type/test/contract checks and PR CI. Synchronize only scoped files back to the original checkout.
7. Save blog case studies in the existing `docs/blog` directory, separating implemented/deployed changes from planned monitoring. Record test results and a concrete future DB/cloud setup proposal without applying that setup.

## Inspection policy

- Monthly boundaries are UTC. Required history begins March 2026, matching the approved retention policy of keeping existing partitions, and extends through the current calendar month and the next three complete months.
- Every expected child must be actually attached to the exact parent with the exact monthly range. A distant maximum end date is not proof that intervening months exist.
- Missing future reserve produces an advisory. A current or historical gap or a security violation is an error. Remaining contiguous coverage of 60, 30 and 7 days escalates the finding. Connection/catalog failures are unknown, never healthy.
- No event contents, account identifiers, quiz answers, row counts or customer tables are read by the inspector. Output contains only bounded status, dates and catalog findings.
- The inspector creates, grants, revokes, repairs and deletes nothing. Fixture DDL/DML is isolated to disposable test databases.

## Future deployment proposal requiring approval

The later scheduled monitor should use a separate no-write DB login role and a dedicated Secret Manager connection string, supplied to the job through the existing `DATABASE_URL` variable. Catalog visibility and any needed schema/connection permissions must be tested before role creation. No `SELECT` on learning tables, schema creation, table ownership, BYPASSRLS or role-management rights should be granted to this monitor.

Cloud Scheduler would invoke a dedicated Cloud Run Job daily at 09:00 Asia/Seoul. Scheduler identity would receive invocation permission only on that job; the job identity would receive access only to its required secret. An external Sentry Cron Monitor would detect missing starts, failures and timeouts, with a separately verified email alert rule. IAM, secret, job packaging, schedule, notification recipient and available quota/cost require a concrete deployment review. None is applied by this implementation task.

The detailed decision is retained in `.planning/escalations/2026-10-21-partition-monitor-deployment.md`. A job wrapper must map the inspector's structured advisory/error/unknown states to the intended alert policy and separately verify actual job completion; a successful Scheduler dispatch alone is not a successful inspection.

## Operator interface

From `apps/api`, invoke `uv run python scripts/check_review_event_partitions.py`. The existing `DATABASE_URL` must already be injected into the process environment. The tool does not load `.env` or import application startup/session configuration. `--help` and invalid arguments do not connect. Do not put a production URL in command arguments or shell history; production invocation requires the reviewed deployment and credential path above.

Optional `--as-of` accepts an aware ISO timestamp for deterministic local evaluation, such as `2026-11-01T00:00:00Z`. It is a test override, not a way to query a historical DB snapshot. The actual catalog is read now and evaluated against that timestamp.

| Exit | Status | Meaning |
|---|---|---|
| 0 | OK | Required catalog coverage and security checks passed |
| 1 | ADVISORY | Future reserve is missing or coverage is within the warning threshold |
| 2 | ERROR | Current/history gap, confirmed security/structure drift or urgent expiry |
| 3 | UNKNOWN | Invalid input, missing required metadata, DB failure, timeout or unverifiable cleanup |

JSON contains UTC evaluation/required/continuous-end dates, missing months, remaining days and bounded finding codes. `dataApiPlatformSwitch: not_verified` is deliberate: PostgreSQL catalog checks do not inspect the platform dashboard toggle or the live PostgREST process. The CLI never enables that API or grants access.

## Blog records

The user-requested casebook and publication outline are saved as drafts under `docs/blog/2026-10-21-harukoto-improvement-casebook.md` and `docs/blog/2026-10-21-harukoto-blog-outline.md`. They distinguish local UI work, merged/deployed fixes, real device observations and pending work. Prior untracked operation notes remain in the original checkout; they are not silently included with this scoped implementation. References to those notes are identified as local source paths in the blog drafts.

## Status

Implementation and regression validation completed. The CLI and internal library are explicitly invoked and not scheduled. Existing production DB, Data API settings and cloud resources remain unchanged by this task. No production connection was used for this implementation verification.


## Verified implementation results

- New tests: **60 passed** (33 unit cases and 27 actual disposable-PostgreSQL cases). The actual CLI success path also runs inside the healthy PostgreSQL case, with exit 0, empty stderr and JSON matching the internal library. It uses only a synthetic database connection in the process environment.
- Full clean-checkout API suite: **669 passed, 13 existing optional AI skips**, 73.58 seconds. All **52 required PostgreSQL cases** passed the exact-name JUnit gate without skips. The gate's own 10 unit tests passed.
- Ruff lint and format passed across the affected API/CI scope (288 formatted files); mypy passed 169 application files. OpenAPI is byte-identical with 102 paths. Mobile's 62 endpoint calls and admin's 14 calls plus one enum match; mobile field annotation coverage remains zero and is not claimed as new field validation.
- Real PostgreSQL assertions verify unchanged synthetic user/event rows and protected security metadata across repeated inspections; catalog-only statements; actual read-only write denial; a consistent snapshot under concurrent catalog changes; minimum-role success while customer-table reads and permanent public DDL are denied; extra healthy future partitions accepted; middle gaps and security drift rejected.
- Boundaries cover UTC/non-UTC, year rollover and leap day, current-plus-three-month horizon, 60/30/7-day thresholds, invalid/missing input, DB errors and cleanup. Controlled cancellation-resistant read/cleanup cases and an actual subprocess prove bounded completion without pending tasks or credential output.
- The six scoped code/CI files were synchronized to the original checkout only after checking absent-file and prior-base conditions. Original-checkout verification then passed all 60 new tests without skips, plus scoped Ruff/format, and the four API file hashes remained identical to the clean implementation. The API HTTP surface, migrations, models, dependencies, env contract and production settings are unchanged.
- Inspector guard validation covers identity/owner/SECURITY DEFINER/search path/required CREATE TABLE event tags and enabled state, not a full function-body integrity audit. The empty schema check establishes postgres ownership and client denial, not exclusivity against every trusted role.

Independent read-only review found no unresolved blocking issue. Operational role and cloud setup remain the separate proposal above; no scheduler or email notification is active as a consequence of this code change.
