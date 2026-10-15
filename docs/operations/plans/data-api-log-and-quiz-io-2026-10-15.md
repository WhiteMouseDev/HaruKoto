# Data API retry logs and quiz query reuse — 2026-10-15

## Scope and authorization

The user approved keeping the Data API blocked, stopping the repeated missing-schema errors, removing redundant quiz queries, validating login/learning, and deploying the server. Work is isolated from the original checkout's existing uncommitted changes.

Production project: `tdimppgykstgeykbnwal`. Starting Alembic head: `k1l2m3n4o5p6`. Starting release: `198e47ab`.

## Implementation plan

1. Add an Alembic revision using the official Supabase workaround: an empty, client-inaccessible `pgrst_no_exposed_schemas`, an `authenticator`-only `pgrst.db_schemas` override, and a PostgREST configuration/cache reload. Keep the platform Data API control disabled, public RLS/grants intact, and Auth/server DB access unchanged. Refuse a nonempty or unexpectedly owned placeholder. Recovery must remain fail-closed.
2. Load the smart vocabulary quiz's same-level candidate pool and user-seen IDs once per quiz. Reuse them only within that request and preserve distractor ranking, correct-answer exclusion, option count, and all existing response contracts.
3. Validate query count and selection behavior; exercise the migration in disposable PostgreSQL including permissions, round trip, reapplication, and Auth/learning compatibility. Run affected API checks and consumer checks.
4. Dry-run the exact migration SQL in production with bounded timeouts and pre/postconditions, roll back, then apply the same SQL. Confirm the Data API remains blocked and new missing-schema logs cease after the cutoff.
5. Merge the scoped PR after required CI, deploy Cloud Run, and repeat production login/read UAT plus a dedicated test-account quiz persistence check. Preserve credentials and customer data in their existing systems.

## Baseline and attribution limits

- At 2026-10-15 09:26 KST: production head `k1l2m3n4o5p6`; 42 public application tables have RLS, zero public table/view objects have client DML grants, Auth user trigger exists, and the public object creation guard is enabled.
- No `pgrst.db_schemas` role override or placeholder schema existed before this change.
- Dedicated test account login/read UAT: 10/10 passed, no learning writes or ensure-user calls. Existing incomplete sessions: zero.
- Observability showed a repeated `schema "pg_pgrst_no_exposed_schemas" does not exist` error approximately every 32 seconds. This matches Supabase's documented behavior when the Data API is disabled.
- The Disk IO email is not proven to be caused by those errors or by repeated application queries. Short observed DB statistics did not show growing disk block reads or temporary file use. Do not interpret cumulative statistics since February/March as the email's hourly workload.

## Validation and release

- Implemented revision `l2m3n4o5p6q7` and a user/type/level-scoped, request-local distractor pool. Ten-question smart vocabulary candidate/seen-ID SELECTs fall from 20 to 2. This is a query-count result, not a measured 90% reduction in total disk I/O.
- Combined API checks: **583 passed / 13 existing skips**, including eight real PostgreSQL tests. Ruff lint and format (281 files), mypy (168 files), and `git diff --check` passed.
- Real route/PostgreSQL tests cover both 2- and 10-question requests, one candidate query and one seen-ID query, four distinct options, correct metadata, user isolation, and prior standalone behavior.
- The migration's PostgreSQL tests cover wrong-owner/nonempty schema refusal, client denial, unchanged public/Auth/Storage metadata, Auth user creation and smart quiz persistence, reapplication, and fail-closed downgrade/re-upgrade. The operational wrappers were also exercised against disposable PostgreSQL.
- OpenAPI snapshot remains byte-identical (102 paths). Mobile's 62 endpoint calls and admin's 14 endpoint calls plus one annotated enum match. Mobile field annotation coverage is limited; no request/response fields changed.
- Production dry run applied the exact SQL and rolled back: committed head remained `k1l2m3n4o5p6`, placeholder absent, role override absent.
- Production commit succeeded at **2026-10-15 09:31:34.901 KST**: head `l2m3n4o5p6q7`, empty schema owned by `postgres` with owner-only ACL, authenticator override recorded. RLS 42, client DML objects zero, Auth trigger and public DDL guard remain enabled.
- The dashboard Data API switch remains off. Anonymous body-free `HEAD /rest/v1/users?select=id&limit=0` is denied: 503 before, 404 after the empty-schema fix. No application rows were retrieved.
- Dedicated test account read UAT passed **10/10 both before and after** the DB change, with no learning writes or ensure-user calls.
- PR CI, Cloud Run deployment, post-deploy UAT, and final log observation are pending at this record's first commit; final release details will be recorded below.

## Recovery

- Keep Data API disabled throughout recovery. Never restore public client grants to suppress a platform warning.
- The quiz change can be reverted independently without reverting security controls.
- Preserve role/schema metadata and record the exact applied revision before modifying production.

## References

- [Supabase disabled Data API missing-schema workaround](https://supabase.com/docs/guides/troubleshooting/schema-pg_pgrst_no_exposed_schemas-does-not-exist)
- [Supabase high disk I/O](https://supabase.com/docs/guides/troubleshooting/exhaust-disk-io)
