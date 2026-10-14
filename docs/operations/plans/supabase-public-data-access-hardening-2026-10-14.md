# Supabase public data access hardening — 2026-10-14

## Outcome

User approved the proposed Data API block and privilege/RLS hardening on 2026-10-14. Both changes are applied to HaruKoto production, and login plus learning persistence were verified. Production Supabase project: `tdimppgykstgeykbnwal`. Alembic revision: `9f1e2d3c4b5a` → `k1l2m3n4o5p6`.

## Applied controls

- Dashboard **Enable Data API** is off. A body-free anonymous `HEAD /rest/v1/users?select=id&limit=0` changed from HTTP 200 to HTTP 503 after disabling the Data API. No user rows were retrieved.
- All 42 application tables/partitioned tables have RLS enabled, without enabling FORCE RLS.
- All 43 public application table/view objects have no effective SELECT/INSERT/UPDATE/DELETE grants for `anon` or `authenticated`. Column grants, sequence access, and public application routine execution were also restricted.
- `user_chapter_progress_v` uses `security_invoker=true`.
- The existing Auth `on_auth_user_created` trigger and `handle_new_user()` SECURITY DEFINER behavior remain. Server `postgres/BYPASSRLS` and `service_role` access are retained.
- `postgres` default privileges in `public` no longer grant client access. `zz_harukoto_secure_public_ddl` secures newly created public application objects, including table/partition RLS and routine ACLs.
- Managed schemas, other owners, and extension members are excluded. The guard covers CREATE/SELECT INTO events; later explicit GRANT or ALTER SET SCHEMA/OWNER still requires normal migration review.

The deployment ran the exact Alembic-generated SQL inside a bounded transaction with role/head preconditions and postconditions. An identical dry run succeeded in production and rolled back to the original head before the committed application. Supautils event-trigger support was verified by that dry run.

## Before and after

| Check                                            |               Before | After |
| ------------------------------------------------ | -------------------: | ----: |
| Security Advisor ERROR findings                  | 42 (41 RLS + 1 view) |     0 |
| Application tables with RLS enabled              |                 0/42 | 42/42 |
| Public table/view objects with client DML grants |                43/43 |  0/43 |
| View security invoker                            |          false/unset |  true |
| Login and mobile read-contract UAT               |                10/10 | 10/10 |
| Server Prisma metadata and empty-result queries  |                 pass |  pass |

Security Advisor retains one separate WARN: `auth_leaked_password_protection`. This is an Auth password-protection setting, not an unresolved table/RLS finding. No Auth credential or pricing setting was changed.

## Validation

- Clean security worktree: API pytest **569 passed / 13 existing skipped**, Ruff lint/format **279 files**, mypy **168 files**.
- Real disposable PostgreSQL regression: migration, repeat application, client CRUD/column/view/partition/sequence/routine denial, independent RLS denial, Auth user trigger, server smart quiz **2/2, 100%, 20 XP**, secure future creation, managed objects preserved, and unsafe downgrade refusal.
- Original working tree: new PostgreSQL security regression **1 passed** after scoped synchronization, preserving prior uncommitted changes.
- Web and admin TypeScript checks passed. Database package declaration lint has an existing `TS2742` portability error; declaration-disabled checking passed and the actual production Prisma connection passed. No package source/lockfile changes were needed.
- Production Prisma connection verified against the exact Vercel project/Git/root directory and matching Supabase reference: `postgres`, `BYPASSRLS=true`, table owner reads/writes retained. Contradictory WHERE predicates returned no customer data.
- Production login/read UAT passed before the change, after Data API off, and after RLS/grants. It covered password Auth, Auth user, profile, subscription status, dashboard, N5 chapters, lesson detail, review summary, vocabulary and grammar smart previews.
- A documented test-only account, with zero preexisting incomplete sessions, completed one normal N5 vocabulary quiz: START → ANSWER → persisted answer RESUME → COMPLETE. Result **1/1, 100%, 10 XP**; subsequent stats/profile confirmed +1 completed quiz, +1 question, +1 correct answer, +10 XP.
- No customer account was used, no preexisting session cleanup was requested, and no credentials, JWTs, or response-body data were persisted in the report.

## Recovery and follow-up

Automatic Alembic downgrade deliberately fails before making changes. It must not silently restore public access. Retain Data API off during any recovery and use the pre-deployment ACL/RLS/default-privilege snapshot for reviewed manual recovery. The schema/data shape is unchanged.

Only this security revision was applied. Existing unrelated review-event partition, streak marker, and special-quiz resume follow-ups remain outside this rollout.

## Evidence

Local evidence is metadata/status only; private environment files used to validate Prisma were removed.

- `/private/tmp/harukoto-security-preflight-2026-10-14.json`
- `/private/tmp/harukoto-security-preflight-after-2026-10-14.json`
- `/private/tmp/harukoto-security-catalog-after-2026-10-14.json`
- `/private/tmp/harukoto-security-advisors-after-2026-10-14.json`
- `/private/tmp/harukoto-hardening-dry-run-result.json`
- `/private/tmp/harukoto-hardening-apply-result.json`
- `/private/tmp/harukoto_mobile_security_uat_safe_report.json`
- `/private/tmp/harukoto-data-api-disabled.jpg`

## References

- [Supabase Data API controls](https://supabase.com/docs/guides/api/securing-your-api)
- [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Supabase event triggers and Supautils](https://supabase.com/docs/guides/database/postgres/event-triggers)
