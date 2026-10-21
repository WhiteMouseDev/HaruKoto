---
raised_by: codex-root
raised_at: 2026-10-21T09:59:18+09:00
phase: read-only-partition-monitor
severity: info
status: resolved
resolved_at: 2026-10-21T11:20:00+09:00
---

## Resolution

The user explicitly approved merging PR #181 and applying the proposed minimum-privilege daily 09:00 Asia/Seoul monitor, preserving learning records and Data API blocking, and verifying actual execution and notification. The later project-wide email digest maximum change from 30 to 5 minutes was also explicitly approved. This resolves the deployment decision; actual evidence and any remaining technical checks are tracked in `docs/operations/plans/partition-monitor-deployment-2026-10-21.md`. The final compatible DB role is named `partition_monitor_catalog`; no application-data grants were needed.

## What happened

The user approved the read-only inspector and regression tests first, requesting a concrete proposal before any production DB permission or cloud configuration change. Implementation proceeds independently of this future deployment decision. No monitor login, grants, secrets, cloud job, scheduler or notification rule is created by the implementation task.

## Decision required

Approve a later deployment of the tested inspector with the following separately reviewed changes, after its least-privilege PostgreSQL test and packaging checks pass:

1. A dedicated `partition_monitor` DB LOGIN role with no superuser, database creation, role management, replication or BYPASSRLS privileges and no inherited privileged membership. Grant only target-database CONNECT and public-schema USAGE if not already provided. Catalog inspection needs no SELECT on learning tables. Do not grant access to the private empty PostgREST schema or grant `pg_read_all_data`, public table access, application routine execution or schema CREATE. Inventory inherited PUBLIC privileges rather than claiming a per-role REVOKE can negate them.
2. A separate Secret Manager connection string for this role, injected into the job's existing `DATABASE_URL` variable. Generate/store credentials through the normal secure workflow; do not put values in repository files, command arguments, logs or the proposal. The application server's privileged connection string is not the recommended monitor credential.
3. A dedicated Cloud Run Job using a pinned reviewed image and the explicit inspector command, one task, bounded runtime and bounded retries. Its service account gets Secret Accessor only on the specific required secret. No public HTTP endpoint is added and no migrations run in this job.
4. Cloud Scheduler invokes only this job daily at 09:00 Asia/Seoul. Its separate identity receives invocation permission on this job, without project-wide admin grants. Confirm actual deployment permissions and API availability before enabling resources.
5. Sentry Cron monitoring and an explicitly selected, verified email recipient. Detect missing starts after a 30-minute grace period, execution errors/timeouts, coverage warnings, security failures and recovery. A manual success/failure/missed-run notification test is required; scheduler dispatch success alone does not establish job success. Confirm account quota and cost before enabling the monitor.

## Options considered

1. Inspector and regression tests only: authorized now and independently useful.
2. Dedicated DB role plus Cloud Run Job, Scheduler and Sentry: recommended deployment follow-up, pending the decision above.
3. Reuse the API server's owner-level DB credential: fewer setup changes, but gives the monitor more authority than it needs; not recommended as the default.
4. Schedule the existing `ensure-partitions` endpoint: rejected for this scope because it executes DDL and needs a separate authentication/error-handling review.

## Recommended direction

Finish the pure/read-only implementation and actual PostgreSQL tests first. Present their result and the exact role/secret/IAM/job/notification changes for approval. Keep schema additions under reviewed Alembic migrations. The last approved partition repair covers through the exclusive bound 2027-02-01 UTC; the rolling current-plus-three-month policy first needs February on 2026-11-01.

## Side effects

This follow-up would introduce a monitor login and secret, cloud execution resources, narrow IAM bindings and external notification configuration. It does not require Data API exposure or customer-row access. None of these side effects is necessary to finish the currently approved code and local test task.

Implementation plan: `docs/operations/plans/read-only-partition-check-2026-10-21.md`.
