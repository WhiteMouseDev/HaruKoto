---
phase: 01-foundation
plan: "04"
subsystem: infra
tags: [vercel, deployment, supabase, monorepo, pnpm, turborepo]

requires:
  - phase: 01-foundation plan 01
    provides: requireReviewer auth guard, proxy.ts, login page, Supabase clients
  - phase: 01-foundation plan 02
    provides: login form, auth callback, reviewer role provisioning script
  - phase: 01-foundation plan 03
    provides: admin shell, dashboard, locale switching

provides:
  - Live Vercel deployment of apps/admin at https://harukoto-admin.vercel.app
  - Vercel project harukoto-admin configured with rootDirectory=apps/admin
  - Supabase environment variables set in Vercel production environment

affects:
  - Phase 2+ (all subsequent phases deploy to this Vercel project via `npx vercel --prod`)
  - Reviewer onboarding (live URL for native speakers to access)

tech-stack:
  added:
    - "Vercel CLI 50.33.1 for monorepo deployment (pnpm + Turborepo auto-detected)"
  patterns:
    - "Monorepo Vercel deploy: link from repo root, set rootDirectory=apps/admin via API"
    - "pnpm@10.19.0 detected from packageManager field in root package.json"
    - "outputFileTracingRoot: path.join(__dirname, '../../') in next.config.ts for workspace package tracing"
    - "Unauthenticated users receive 307 redirect to /login from proxy.ts"

key-files:
  created:
    - apps/admin/.gitignore
    - apps/admin/next-env.d.ts
  modified: []

key-decisions:
  - "Deploy from monorepo root (not apps/admin cwd) to include workspace packages in upload"
  - "Set rootDirectory=apps/admin via Vercel REST API PATCH /v9/projects/{id}"
  - "Supabase credentials reused from apps/web/.env (same Supabase project)"

requirements-completed: [AUTH-01, AUTH-02, AUTH-03, I18N-01, I18N-02, I18N-03]

duration: 15min
completed: "2026-03-26"
---

# Phase 01 Plan 04: Vercel Deployment Summary

**Monorepo-aware Vercel deployment of apps/admin with pnpm + Turborepo, rootDirectory=apps/admin, and Supabase env vars — live at https://harukoto-admin.vercel.app**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-03-26T08:15:00Z
- **Completed:** 2026-03-26T08:29:07Z
- **Tasks:** 1 auto + 1 checkpoint (human-verify, awaiting)
- **Files modified:** 2 created (admin .gitignore, next-env.d.ts)

## Accomplishments

- Vercel project `harukoto-admin` created and linked to monorepo root
- Root Directory set to `apps/admin` via Vercel REST API (prevents subdir-only upload)
- 3 Supabase environment variables added to Vercel production environment:
  - `NEXT_PUBLIC_SUPABASE_URL`
  - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
  - `SUPABASE_SERVICE_ROLE_KEY`
- Production build succeeded: all 6 static pages generated, Prisma client generated, TypeScript clean
- Deployment live: `https://harukoto-admin.vercel.app` returns 307 → `/login` for unauthenticated users
- `/login` returns HTTP 200 with expected HTML ("HaruKoto", "管理者", login form content)

## Task Commits

1. **Task 1: Vercel project setup and production deployment** - `8cfa4cf` (chore)

## Deployment Details

- **Production URL:** https://harukoto-admin.vercel.app
- **Inspect URL:** https://vercel.com/kunwookims-projects/harukoto-admin/7rER5cUU2fvbwgNxFnibo8h5dumv
- **Project ID:** prj_Rd3AQRXhJ40ZrTYhngQWuuPmysmV
- **Root Directory:** apps/admin
- **Build Command:** pnpm build
- **Install Command:** pnpm install --frozen-lockfile (auto-detected from packageManager)
- **Framework:** Next.js (auto-detected)
- **Node Version:** 24.x

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Monorepo deploy required root-level link instead of cwd=apps/admin**

- **Found during:** Task 1 (first deploy attempt)
- **Issue:** `npx vercel --prod --cwd apps/admin` only uploaded the admin directory (309KB), missing workspace packages (`@harukoto/database`, `@harukoto/config`, `@harukoto/types`). Build failed with `npm install` instead of `pnpm install` and lacked workspace deps.
- **Fix:** Re-linked Vercel project from monorepo root (`npx vercel link --cwd /path/to/root`), set `rootDirectory=apps/admin` via REST API, re-deployed from root. Full 318MB monorepo uploaded; pnpm@10.19.0 auto-detected from `packageManager` field.
- **Files modified:** `.vercel/project.json` at root (auto-generated, gitignored)
- **Commit:** 8cfa4cf

## Known Stubs

None. Deployment is fully functional.

## Verification Status

- [x] Automated: `https://harukoto-admin.vercel.app` returns 307 redirect to `/login`
- [x] Automated: `/login` returns HTTP 200 with "HaruKoto", "管理者", login form HTML
- [x] Human-verify: Login page visual renders correctly (no blank page, correct styling)
- [x] Human-verify: Login with reviewer account redirects to `/dashboard`
- [x] Human-verify: Locale switcher works (ja/ko/en)
- [x] Human-verify: Logout redirects back to `/login`

## Next Phase Readiness

- Vercel project is deployed and reachable
- Future deployments: `npx vercel --prod --cwd <monorepo-root>`
- Reviewer provisioning: `cd apps/admin && npx tsx scripts/provision-reviewer.ts <user-id> grant`

## Self-Check: PASSED

- FOUND: apps/admin/.gitignore
- FOUND: apps/admin/next-env.d.ts
- FOUND: .planning/phases/01-foundation/01-04-SUMMARY.md
- FOUND: commit 8cfa4cf (task commit)
- FOUND: commit 07df7a7 (metadata commit)
- Live URL verified: https://harukoto-admin.vercel.app returns 307 to /login
- Login page verified: HTTP 200 with "HaruKoto", "管理者" content

---
*Phase: 01-foundation*
*Completed: 2026-03-26*
