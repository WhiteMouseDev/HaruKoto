# Review partition monitor deployment — 2026-10-21

## Authorization and current status

On 2026-10-21 the user approved merging PR #181 and deploying the previously proposed minimum-privilege DB login, daily 09:00 Asia/Seoul inspection and problem notifications. Existing learning records and the blocked Data API must remain intact. This document is the deployment runbook and evidence ledger; the implementation, manual end-to-end run and actual notification receipts are verified below. The first naturally scheduled daily run is still a future observation.

- [PR #181](https://github.com/WhiteMouseDev/HaruKoto/pull/181) merged as `572823d4`. [Deployment run 39528250347](https://github.com/WhiteMouseDev/HaruKoto/actions/runs/39528250347) produced the ready API revision ending `239-2tp`.
- The acknowledged Sentry wrapper is in [PR #182](https://github.com/WhiteMouseDev/HaruKoto/pull/182), source `b1d8df22`. [CI run 39529405806](https://github.com/WhiteMouseDev/HaruKoto/actions/runs/39529405806) passed: 710 tests, 13 existing optional AI skips; all 52 required PostgreSQL regressions passed without skips. PR #182 merged as `eee951835953d9aac0f06747d7e8bfc065381734`; [deployment run 39529637102](https://github.com/WhiteMouseDev/HaruKoto/actions/runs/39529637102) produced ready revision `harukoto-api-00240-gp7`.
- The current production catalog inspection is OK: eleven monthly partitions, continuous coverage through the exclusive UTC bound `2027-02-01T00:00:00Z`. The rolling current-plus-three-month policy first requires February on `2026-11-01`.
- Two dedicated service accounts and three narrow Secret Accessor bindings exist. Cloud Scheduler API is enabled. The dedicated DB login and payload version 1 are verified, and the digest-pinned job and paused daily schedule exist. The daily schedule and production monitor are active, the rehearsal monitor is disabled, and manual end-to-end execution plus actual failure/missed/recovery email receipts are verified.

Use an explicit verified deployment account and project on cloud commands. Preserve the operator's existing default gcloud account/configuration. Never copy credentials, DSNs, project references, email addresses, tokens or raw driver failures into repository files or public blog drafts.

## Verified production configuration

| Resource | Configuration and boundary |
|---|---|
| DB login | `partition_monitor_catalog`; no application table, column or sequence grants, privileged memberships, object ownership, BYPASSRLS or administrative rights |
| Job runtime identity | `harukoto-partition-monitor`; Secret Accessor only on the three specific secrets listed below |
| Scheduler identity | `harukoto-partition-scheduler`; Cloud Run Invoker only on the inspection job |
| Run job | Dedicated job in `asia-northeast3`; reviewed immutable image digest; one task, parallelism one, zero automatic task retries, maximum task duration 120 seconds |
| Command | `/app/.venv/bin/python scripts/monitor_review_event_partitions.py --monitor-slug new-monitor`; no Alembic, seed or HTTP server startup |
| Runtime settings | `ENVIRONMENT=production`; `PGSSLROOTCERT=/var/run/partition-monitor-ca/root.crt`; explicit version-pinned Secret references |
| Schedule | `0 9 * * *`, timezone `Asia/Seoul`; Scheduler POST to the Cloud Run v2 `jobs:run` API using the separate identity's OAuth token |
| Sentry production monitor | ID `10708112`, slug `new-monitor`, display name `HaruKoto review partitions`; the existing slug is intentionally preserved |
| Sentry timing | Daily 09:00 Asia/Seoul; check-in margin 30 minutes; maximum runtime 2 minutes; failure/recovery thresholds one |
| Alert recipient | Existing verified organization member, alert ID `6203133`; retain the selected member action without recording personal contact data here |
| Rehearsal monitor | ID `10708141`, slug `harukoto-partition-rehearsal`; disabled except during controlled validation |

Confirm the final job command against the pinned image's interpreter path before creating the job. Do not attach the API service's privileged `DATABASE_URL` secret or other application secrets to this job. Scheduler API acceptance starts an execution; it does not prove the inspection completed.

### Secret and certificate inventory

| Secret | Version / use |
|---|---|
| `PARTITION_MONITOR_DATABASE_URL` | Version `1`; dedicated catalog-only login, verified before storing; never the API owner connection |
| `SENTRY_DSN` | Existing version `3`; SDK ingestion only, not a Sentry management token |
| `PARTITION_MONITOR_CA_CERT` | Version `1`; public Supabase CA, mounted at `/var/run/partition-monitor-ca/root.crt` |

The CA was obtained from the official dashboard-linked [Supabase certificate](https://supabase-downloads.s3-ap-southeast-1.amazonaws.com/prod/ssl/prod-ca-2021.crt). Its SHA-256 fingerprint is `807025AD50D4ED219D2C9C7D299C004F824EB00CF7F65AFEF607D07B72E6CAFA`, with expiry `2031-04-26`. It is public trust material, not a private key. Verify the certificate chain and connection hostname with `sslmode=verify-full`; mounting a certificate does not itself prove successful verification.

## DB provisioning and preservation checks

1. Read the current Alembic head, partition attachments/bounds, RLS, effective client ACLs, default privileges, DDL guard and empty PostgREST schema/authenticator overrides. Keep a bounded security-metadata snapshot outside the repository. No customer-row export, full-table count or checksum is needed for this role change.
2. Fail on an unexpected existing `partition_monitor_catalog` role. For a new role, explicitly use `LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS NOINHERIT` and a small connection limit. Grant only required connection/schema visibility after checking effective existing access. Do not grant application data access, `pg_read_all_data`, schema CREATE or access to `pgrst_no_exposed_schemas`.
3. Set scoped role defaults for UTC, `search_path=pg_catalog`, read-only transactions and bounded statement/idle timeouts. These defaults supplement ACLs; the role can change ordinary session settings, so defaults do not establish absence of write privileges.
4. Generate the dedicated password securely and store it only through the protected secret workflow. Never place the password or connection string in command arguments, shell history, logs or this document. Do not reset the API owner's password or disturb its connections while waiting for Supavisor credential-cache propagation.
5. Use the verified Supabase endpoint. Shared pooler usernames require `partition_monitor.<project-ref>`; direct connections use the actual role name. Prefer the verified session/direct endpoint for asyncpg prepared-statement compatibility. Retain certificate and hostname verification.
6. Read effective role attributes/memberships and table, column, sequence, schema and routine permissions. Check a body-free `SELECT ... LIMIT 0` is denied for learning tables. Inventory PUBLIC-derived privileges explicitly: existing PUBLIC TEMP permission is preserved, and a role-specific REVOKE cannot negate it. Do not revoke global PUBLIC rights or change managed Auth/Storage routines for this deployment.
7. Execute the actual inspector with the dedicated login. Compare protected security metadata before and after; only the approved role/defaults and narrowly required grants may differ. Alembic head, learning schema/records, RLS, client grants, DDL guard and Data API restrictions must remain unchanged.

The job's catalog query runs in a bounded UTC, repeatable-read, read-only transaction and reads no learning rows. Its `dataApiPlatformSwitch: not_verified` field is deliberate. Separately verify the existing dashboard/API restriction without enabling Data API or granting client access.

## Deployment and notification verification

Complete these steps in order and record actual execution/check-in/message references in the ledger below.

1. Require final PR #182 CI, reviewed image packaging and immutable digest. Verify the image contains the CLI and CA mount location. Create the dedicated job with only the minimum runtime identity and explicitly pinned secret versions.
2. Use the acknowledged wrapper. It sends `in_progress` before DB inspection, then `ok` only for an actual OK result with accepted start delivery. `ADVISORY`, `ERROR`, `UNKNOWN`, cancellation and DB cleanup uncertainty become an error check-in. Either rejected delivery produces a nonzero unknown result; a returned SDK event ID alone is insufficient proof.
3. Keep production scheduling unarmed while rehearsing. The current account permits one active Sentry Cron monitor. Temporarily deactivate the unarmed production monitor, activate the clearly named rehearsal monitor and run success, real future-coverage advisory, missing-start and recovery tests serially. Do not enable paid overage, upgrade the plan or leave two active monitors. Restore production as the sole active monitor and disable the rehearsal monitor afterward.
4. For the advisory rehearsal, use `--as-of 2026-11-01T00:00:00Z` with the separate rehearsal slug. This evaluates the actual present catalog against a future date; it does not simulate a historical database or modify partitions. Confirm February is missing and the alert is an authentic advisory mapping, not a fabricated DB failure.
5. For missing-start verification, temporarily give only the rehearsal monitor a short known schedule/margin and omit its expected check-in. Wait for an actual missed incident. Then submit a healthy run to verify recovery. A configuration screenshot or manual issue creation is not evidence of a missed-run detector.
6. Verify incident creation and the selected recipient's actual email receipt for the test failure and missed run. Verify recovery state and its configured notification behavior; do not claim a recovery email unless received. Correlate timestamps and links rather than copying personal message contents into public docs.
7. Restore the production monitor's approved daily schedule, margin, runtime and alert recipient. Create/enable the Scheduler only after readback confirms the production monitor is active. Bind invocation only to the specific job; use OAuth for the Google Run API, not an OIDC token intended for a `run.app` HTTP service.
8. Force one Scheduler run, correlate its dispatch with a completed Cloud Run execution, structured `status=OK` / `exitCode=0`, and the production Sentry OK check-in. Verify no credential values appear in logs. Read back the next daily run time and timezone. This establishes the manual end-to-end path; the first naturally scheduled daily run must be recorded separately when it occurs.
9. Repeat body-free Data API denial and existing login/profile/learning/unfinished-quiz read checks. A persistence exercise must use only the designated test account and retain existing real learner data. Record precisely which checks ran rather than claiming every mobile flow was exercised.

HTTP transport-close failure after both check-ins were acknowledged is recorded as `HTTP_CLEANUP_FAILED` cleanup warning. The one-shot process releases its HTTP resources on exit; this does not undo a completed inspection or invent an unalerted job failure. Actual DB cleanup uncertainty remains an inspection failure.

## Evidence ledger

| Verification | Actual result / reference |
|---|---|
| Final wrapper CI and exact merge commit | PASS — 710 passed, 13 optional skips; 52 required PostgreSQL cases passed; CI 39529405806, merge `eee951835953d9aac0f06747d7e8bfc065381734` |
| Job image digest / final job and Scheduler resource names | PASS — `harukoto-partition-check`, Scheduler `harukoto-partition-check-daily`; image digest `sha256:fb43171826a47e75b512db829d4ac45e82f1bdde9793ba97b3aba5223f2a6fbb`; task timeout 120s, one task, zero retries, pinned secret versions |
| Monitor DB login, secret version and verified TLS | PASS — `partition_monitor_catalog`, DB secret version 1, zero application data/routine grants or privileged membership; official-CA client-to-pooler TLS `verify-full` |
| Preserved security metadata / Alembic head | PASS — protected catalog SHA-256 unchanged (`2730c873415b3620136ef6fc853ff270d7de8a233688c706ff6e457a1acdaba5`); no customer-row reads/writes or migrations |
| Direct job success | PASS — `harukoto-partition-check-sg9c6`, completed 02:23:00 UTC / 11:23:00 KST; task succeeded, structured OK and acknowledged Sentry recovery `3b20d081...` |
| Rehearsal failure + email | PASS — real Nov1 evaluation reported missing February; new regression event 02:14:49 UTC, error email received 11:17 KST, explicit “An error check-in was detected”; same issue HARUKOTO-API-1W and alert 6203133 |
| Rehearsal missed start + email | PASS — expected 02:02 UTC, actual missed incident 02:03 UTC, regression email received 11:12 KST; body explicitly states “A missed check-in was detected”, issue HARUKOTO-API-1W, alert 6203133 |
| Recovery | First recovery PASS — `1c843b07...`, actual healthy inspection at 02:01:23 UTC and resolved Sentry state; recovery email received at 11:01 KST. Final Cloud Run recovery `3b20d081...` at 02:22:56–57 UTC also shows resolved, followed by rehearsal disable. |
| Production restored / rehearsal disabled | PASS — rehearsal disabled and production enabled as sole active Cron monitor; production UI confirms 09:00 Asia/Seoul, 30min margin, 2min timeout and connected email alert |
| Scheduler force-run completion | PASS — Scheduler dispatch 02:25:51 UTC → execution `harukoto-partition-check-bts4v`, creator is the dedicated Scheduler identity → completed 02:26:08 UTC with one succeeded task / exit0 → Sentry `b31c0a6fdb2d4490996113a27eb15bf0` Okay at 02:26:02–03 UTC |
| Next daily 09:00 KST run | CONFIGURED — 2026-10-22 around 09:00 KST (Scheduler readback 00:00:04.979742 UTC); naturally scheduled completion has not yet occurred. Cron expression remains exactly `0 9 * * *`. |
| Login / learning / unfinished quiz / Data API denial | PASS — baseline14/14 and post-deployment14/14: dedicated login, profile, stats, subscription, dashboard, review, vocabulary/grammar preview, chapter/lesson content, incomplete lookup; anonymous and authenticated Data API requests remain404; zero learning writes |

## Response and rollback

For a coverage advisory, review the reported month and prepare the normal reviewed partition migration before the horizon advances. The monitor does not repair partitions. For security drift, investigate the affected setting while keeping Data API blocked. For UNKNOWN/missed/timeout, inspect Cloud Run execution/secret/IAM/network state and Sentry ingestion; absence of a successful check must never be recorded as healthy.

If rollout must stop, pause the new Scheduler first, deactivate its Cron monitor and cancel only this job's active executions if necessary. Set the new role `NOLOGIN`, remove only newly added invocation/secret bindings and retire only the dedicated job and credentials. If dropping the role, first establish zero owned-object dependencies and remove only its specific new grants. Never use `DROP OWNED`, `CASCADE` or restore broad public grants. Do not disable/delete the existing shared `SENTRY_DSN` secret/version or alter the API service's credentials. Learning records, migrations, RLS and blocked Data API remain intact during recovery.

## References

- [Inspector implementation and validation](read-only-partition-check-2026-10-21.md)
- [Approved deployment proposal](../../../.planning/escalations/2026-10-21-partition-monitor-deployment.md)
- [Google: schedule Cloud Run jobs with OAuth](https://docs.cloud.google.com/run/docs/execute/jobs-on-schedule)
- [Google: job-scoped invocation and execution completion](https://docs.cloud.google.com/run/docs/execute/jobs)
- [Google: version-pinned secrets for jobs](https://docs.cloud.google.com/run/docs/configuring/jobs/secrets)
- [Supabase: shared pooler role/project usernames](https://supabase.com/docs/guides/troubleshooting/tenant-or-user-not-found)
- [Supabase: SSL enforcement and verified connections](https://supabase.com/docs/guides/platform/ssl-enforcement)
- [PostgreSQL: effective privileges and PUBLIC defaults](https://www.postgresql.org/docs/current/ddl-priv.html)
- [Sentry: margins, failure and recovery thresholds](https://sentry.io/changelog/2023-12-20-margins-and-thresholds-for-cron-monitors/)

## Implementation observations

The new monitor uses standard SCRAM iterations with a high-entropy random password for managed-pooler compatibility. Early custom iteration settings and short-lived reused role names could not authenticate and were tested without changing the API owner password; only roles created by this rollout were cleaned up. All transient names were removed and the final role is `partition_monitor_catalog`.

The proof query guards relation-kind-specific privilege functions with CASE: PostgreSQL may evaluate a function before a WHERE filter, so calling a sequence privilege function on a table is not a permission failure. Also, `pg_stat_ssl` behind the managed pooler describes its upstream DB connection; it does not measure the monitor-to-pooler TLS connection. That pre-existing upstream value was false for both owner and monitor. Client certificate/hostname validation was verified separately using the official CA and `verify-full`; no cluster TLS setting was changed.

## Email delivery configuration approval

The operator explicitly approved reducing the HaruKoto API project’s maximum digest delay from 30 to 5 minutes after being informed that other API error email digests also use this project setting. Minimum delay remains 5 minutes; maximum 5 was verified after reload. Other project settings and notification recipients were not changed. This is a batching bound rather than an end-to-end email delivery SLA. Fast recovery may suppress an error still waiting for a digest, so notification validation holds real rehearsal failures open until receipt.

## Final boundaries and retained evidence

The real warning rehearsal in the Cloud Run image (`harukoto-partition-check-djhvk`) returned ADVISORY/exit1 and one failed task as expected, with accepted error check-in. This was a deliberate future-date evaluation, not a production data-write failure. A bounded six-run warning hold kept the true future assessment unresolved while waiting for an email, then stopped; it is not a recurring schedule.

Only the daily production schedule remains active. No PAYG budget or paid Sentry plan was enabled. The default local Google Cloud account stayed unchanged; deployment calls explicitly selected the authorized account/project. Production learning rows were never written by this rollout. Final read-only DB inspection still finds only the final monitor role, no transient roles, the same eleven partitions and Alembic head `m3n4o5p6q7r8`, and the same protected-catalog signature.

The deployment account, role/secret payload values, message contents and customer identifiers are not included here. Sanitized role and IAM proofs, test reports, job configurations, completed execution results, email timing observations and the production-monitor screenshot are retained in the local task artifact directory. The operator-visible screenshot matches the CLI/job check-in ID and shows no ongoing production issue.
