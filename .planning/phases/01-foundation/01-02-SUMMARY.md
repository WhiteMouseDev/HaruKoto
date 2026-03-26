---
phase: 01-foundation
plan: 02
subsystem: apps/admin
tags: [auth, supabase, proxy, login, rbac, reviewer]
dependency_graph:
  requires:
    - apps/admin Next.js 16.1 scaffold (Plan 01)
    - apps/admin Supabase clients (Plan 01)
    - apps/admin next-intl ja.json messages (Plan 01)
  provides:
    - apps/admin/src/proxy.ts route guard with reviewer role check
    - apps/admin/src/middleware.ts Next.js middleware entry point
    - apps/admin/src/app/(auth)/login/page.tsx login page
    - apps/admin/src/components/auth/login-form.tsx login form
    - apps/admin/src/app/api/auth/callback/route.ts OAuth callback handler
    - apps/admin/scripts/provision-reviewer.ts reviewer role provisioning script
    - apps/admin/public/images/logo-symbol.svg app logo
  affects:
    - All admin routes (guarded by proxy.ts reviewer check)
tech_stack:
  added: []
  patterns:
    - Next.js 16 proxy.ts + middleware.ts re-export pattern
    - Supabase auth.getUser() (server-validated, not JWT-decoded) for role check
    - app_metadata.reviewer === true as reviewer role gate
    - Next.js 16 async searchParams in Server Components
    - signInWithPassword for email/password auth with inline error display
    - Submit-only validation (no real-time validation per D-03)
    - auth.admin.updateUserById for service-role reviewer provisioning
key_files:
  created:
    - apps/admin/src/proxy.ts
    - apps/admin/src/middleware.ts
    - apps/admin/src/app/(auth)/login/page.tsx
    - apps/admin/src/components/auth/login-form.tsx
    - apps/admin/src/app/api/auth/callback/route.ts
    - apps/admin/scripts/provision-reviewer.ts
    - apps/admin/public/images/logo-symbol.svg
  modified: []
decisions:
  - "proxy.ts uses getUser() not getSession() — server-validated auth ensures role revocation is effective immediately (AUTH-03)"
  - "Non-reviewer users redirected to /login?error=access_denied — distinct from unauthenticated redirect to /login"
  - "Login form validates on submit only (no real-time validation) per D-03 decision"
  - "OAuth callback route included for future-proofing; primary auth is email/password via signInWithPassword"
metrics:
  duration: 2m
  completed: 2026-03-26
  tasks_completed: 3
  tasks_total: 3
  files_created: 7
  files_modified: 0
---

# Phase 1 Plan 2: Authentication Flow Summary

**One-liner:** Admin route guard (proxy.ts) with app_metadata.reviewer role check using server-validated getUser(), email/password login form with inline error display, and reviewer provisioning script using Supabase admin API.

## What Was Built

Implemented the complete authentication flow for `apps/admin`. The security gate for the entire admin app is now in place.

**proxy.ts route guard:**
- Creates Supabase server client with cookie getAll/setAll pattern (mirrors apps/web)
- Calls `supabase.auth.getUser()` (NOT getSession) for server-validated auth on every request
- Exempts: `/login`, `/auth/*`, `/api/*` routes
- Non-exempt routes: redirects unauthenticated users to `/login`, non-reviewers to `/login?error=access_denied`
- Login page with authenticated reviewer: redirects to `/dashboard`
- No Prisma import (admin middleware is auth-only, no direct DB queries)

**middleware.ts:**
- Re-exports proxy as middleware entry point: `export { proxy as middleware, config } from './proxy'`

**Login page `/app/(auth)/login/page.tsx`:**
- Server Component with async searchParams (Next.js 16 pattern)
- Centered layout: `min-h-screen flex items-center justify-center`
- Card: `max-w-[400px]` with `py-12 px-8` padding (2xl/xl tokens per UI-SPEC)
- Logo (48x48) + Display heading (28px/semibold) + LoginForm component
- Passes `error` param ('access_denied' | 'session_expired') to LoginForm

**LoginForm `src/components/auth/login-form.tsx`:**
- Client component with `signInWithPassword`
- Inline error display for wrong credentials, access denied, session expired
- Submit-only validation (no real-time validation per D-03)
- Cherry pink submit button (`bg-primary`, `h-10`, `w-full`) per UI-SPEC
- Email + password fields with proper `autoComplete` attributes

**OAuth callback route `src/app/api/auth/callback/route.ts`:**
- Exchanges code for session via `exchangeCodeForSession`
- Redirects to `/dashboard` on success, `/login` on failure

**Provision script `scripts/provision-reviewer.ts`:**
- CLI: `npx tsx scripts/provision-reviewer.ts <userId> grant|revoke`
- Uses `supabase.auth.admin.updateUserById` with service role key
- Sets `app_metadata: { reviewer: true|false }`

## Decisions Made

1. **getUser() not getSession()**: Enforces AUTH-03 — role revocation is effective immediately on the next request. This was pre-decided in STATE.md and confirmed in auth.ts from Plan 01.

2. **access_denied vs plain /login redirect**: Non-reviewers (authenticated but no reviewer role) get `/login?error=access_denied` while unauthenticated users get plain `/login`. This allows the login form to show the appropriate error message.

3. **Submit-only validation**: Per D-03 decision, no real-time validation on email/password fields. Errors shown only after form submission.

4. **OAuth callback route**: Included for future OAuth provider support (Google, etc.) even though Phase 1 uses only email/password. Zero cost to add now.

5. **middleware.ts re-export pattern**: Follows plan design — business logic in proxy.ts, Next.js entry point in middleware.ts. Consistent with CLAUDE.md rule "proxy.ts 사용" (logic goes in proxy.ts).

## Verification Results

- `npx tsc --noEmit`: PASSED (zero errors)
- proxy.ts acceptance criteria: ALL PASS
  - `export async function proxy`: found
  - `auth.getUser()`: found (not getSession)
  - `app_metadata?.reviewer`: found (2 occurrences)
  - `access_denied`: found
  - `pathname === '/login'`: found
  - `/dashboard`: found
  - `matcher`: found (1 occurrence)
  - `prisma`: NOT found (clean)
  - `getSession`: NOT found (clean)
  - middleware.ts: EXISTS
- Login page acceptance criteria: ALL PASS
  - `getTranslations`: found
  - `max-w-[400px]`: found
  - `min-h-screen`: found
  - `await searchParams`: found
- Login form acceptance criteria: ALL PASS
  - `'use client'`: found
  - `signInWithPassword`: found
  - `errorWrongCredentials`: found
  - `errorAccessDenied`: found
  - `bg-primary`: found
  - No real-time validation: CONFIRMED
- `logo-symbol.svg`: EXISTS at apps/admin/public/images/
- `provision-reviewer.ts`: EXISTS, contains auth.admin.updateUserById + app_metadata
- `callback/route.ts`: EXISTS

## Deviations from Plan

None - plan executed exactly as written.

The plan stated "check apps/web's actual pattern first" for middleware.ts. Result: web app has only proxy.ts (no middleware.ts). Plan's recommendation of creating both proxy.ts (logic) + middleware.ts (re-export) was followed as the "safest approach" per plan wording.

## Known Stubs

**auth.test.ts stubs from Plan 01** — Plan 01 created 4 `.todo()` tests in `src/__tests__/auth.test.ts`. These stubs should be converted to real assertions now that proxy.ts and login-form.tsx are implemented. However, converting test stubs was not in the Plan 02 task list. The stubs remain as `.todo()` items to be addressed in Plan 03 or a dedicated test task.

| File | Stub | Resolution |
|------|------|-----------|
| `src/__tests__/auth.test.ts` | 4 `.todo()` tests for proxy and login-form | Deferred — not in Plan 02 scope |

## Codex Cross-Verification: PASSED

Codex reviewed all auth files (proxy.ts, auth.ts, login-form.tsx, provision-reviewer.ts):
- **P0/P1:** None
- **P2 (deferred):** 3 items — `/api/*` blanket exempt (fail-open for future APIs), metadata merge semantics, test stubs as todo
- AUTH-01: Only `getUser()` used ✓
- AUTH-02: `app_metadata.reviewer` in proxy.ts + auth.ts ✓
- AUTH-03: No bypass paths ✓
- No sensitive error leaks ✓
- OAuth callback secure ✓

## Self-Check: PASSED

Files verified:
- FOUND: apps/admin/src/proxy.ts
- FOUND: apps/admin/src/middleware.ts
- FOUND: apps/admin/src/app/(auth)/login/page.tsx
- FOUND: apps/admin/src/components/auth/login-form.tsx
- FOUND: apps/admin/src/app/api/auth/callback/route.ts
- FOUND: apps/admin/scripts/provision-reviewer.ts
- FOUND: apps/admin/public/images/logo-symbol.svg

Commits verified:
- c3aed91: feat(01-02): create proxy.ts route guard with reviewer role check and middleware.ts entry point
- 6e72231: feat(01-02): add login page, login form, OAuth callback handler, and reviewer provisioning script
