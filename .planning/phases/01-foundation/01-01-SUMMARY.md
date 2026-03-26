---
phase: 01-foundation
plan: 01
subsystem: apps/admin
tags: [scaffold, next.js, supabase, i18n, shadcn, tailwind]
dependency_graph:
  requires: []
  provides:
    - apps/admin Next.js 16.1 buildable app scaffold
    - Supabase browser/server/admin client files
    - requireReviewer() auth guard checking app_metadata.reviewer via getUser()
    - next-intl cookie-based i18n with ja default locale
    - Root layout with NextIntlClientProvider + Noto Sans JP + QueryProvider
    - Test scaffold stubs for Plans 02 and 03
  affects:
    - turbo.json (added Supabase env vars to globalEnv)
    - pnpm-lock.yaml (new workspace dependency)
tech_stack:
  added:
    - next-intl 4.8.3 (cookie-based i18n, without-routing mode)
    - @supabase/ssr 0.9.0 (server/browser Supabase clients)
    - @supabase/supabase-js 2.100.0 (admin client)
    - shadcn/ui (button, input, label, card, form, separator, dropdown-menu, sonner)
  patterns:
    - Next.js 16 async cookies() pattern in server.ts
    - app_metadata.reviewer role check via getUser() (not getSession())
    - next-intl getRequestConfig with NEXT_LOCALE cookie
    - TypeScript type source pattern (ja.json as IntlMessages type)
key_files:
  created:
    - apps/admin/package.json
    - apps/admin/next.config.ts
    - apps/admin/tsconfig.json
    - apps/admin/postcss.config.mjs
    - apps/admin/eslint.config.mjs
    - apps/admin/components.json
    - apps/admin/vitest.config.ts
    - apps/admin/src/app/globals.css
    - apps/admin/src/app/layout.tsx
    - apps/admin/src/lib/utils.ts
    - apps/admin/src/lib/supabase/client.ts
    - apps/admin/src/lib/supabase/server.ts
    - apps/admin/src/lib/supabase/admin.ts
    - apps/admin/src/lib/supabase/auth.ts
    - apps/admin/src/global.d.ts
    - apps/admin/i18n/request.ts
    - apps/admin/messages/ja.json
    - apps/admin/messages/ko.json
    - apps/admin/messages/en.json
    - apps/admin/src/components/providers/query-provider.tsx
    - apps/admin/src/__tests__/setup.ts
    - apps/admin/src/__tests__/auth.test.ts
    - apps/admin/src/__tests__/locale-route.test.ts
    - apps/admin/src/__tests__/layout.test.tsx
    - apps/admin/src/components/ui/button.tsx
    - apps/admin/src/components/ui/card.tsx
    - apps/admin/src/components/ui/dropdown-menu.tsx
    - apps/admin/src/components/ui/form.tsx
    - apps/admin/src/components/ui/input.tsx
    - apps/admin/src/components/ui/label.tsx
    - apps/admin/src/components/ui/separator.tsx
    - apps/admin/src/components/ui/sonner.tsx
  modified:
    - turbo.json (added NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY to globalEnv)
decisions:
  - "Warm-admin gray palette (#F9FAFB bg, #E5E7EB border) instead of cherry-pink bg for professional admin feel; primary accent remains #F6A5B3"
  - "requireReviewer() uses getUser() not getSession() to enforce live DB auth check per AUTH-03"
  - "next-intl without-routing mode with NEXT_LOCALE cookie — no URL locale segments"
  - "ja.json as IntlMessages TypeScript type source — missing translations surface as compile errors"
metrics:
  duration: 5m
  completed: 2026-03-26
  tasks_completed: 2
  tasks_total: 2
  files_created: 33
  files_modified: 1
---

# Phase 1 Plan 1: Admin Scaffold Summary

**One-liner:** Next.js 16.1 apps/admin scaffold with Supabase SSR clients, requireReviewer() role guard using app_metadata.reviewer, next-intl cookie-based i18n defaulting to Japanese, shadcn/ui new-york components, and test stubs for downstream plans.

## What Was Built

Created the `apps/admin` Next.js 16.1 app from scratch inside the Turborepo monorepo. This is the foundation that Plans 02-04 build on. No UI pages were created — only infrastructure, config, and test stubs.

**Key infrastructure:**
- Full Next.js 16.1 app config (package.json, next.config.ts with next-intl plugin, tsconfig.json, eslint.config.mjs, postcss.config.mjs)
- shadcn/ui initialized with new-york style and neutral base color, 8 components installed
- Supabase client files (client.ts, server.ts, admin.ts, auth.ts) matching apps/web patterns but extended with `requireReviewer()` guard
- next-intl configured in without-routing mode with `ja` as default locale (cookie-based)
- Root layout with NextIntlClientProvider + Noto Sans JP font + QueryProvider + Toaster
- Three message files (ja/ko/en) with identical key structure and TypeScript type source via global.d.ts
- Test scaffold stubs (3 files, 10 todos) ready for Plans 02 and 03 verify commands

## Decisions Made

1. **Gray admin palette instead of spring pink background**: Using #F9FAFB (gray-50) as background and #E5E7EB as borders for professional admin feel. Primary accent color (#F6A5B3 cherry pink) retained for buttons and interactive elements.

2. **getUser() not getSession()**: requireReviewer() calls `supabase.auth.getUser()` which validates against the live Supabase server on every call. This enforces AUTH-03: if the reviewer role is revoked in the DB, access is blocked immediately on the next page request.

3. **app_metadata.reviewer claim**: Reviewer role stored in `app_metadata.reviewer === true`. No Custom Access Token Hook needed at 1-3 user scale. Provisioned via Supabase Dashboard or service-role admin API.

4. **next-intl without-routing mode**: No `/ja/` URL segments. Locale stored in NEXT_LOCALE cookie. Japanese as default. This matches the decision documented in STATE.md.

5. **ja.json as TypeScript type source**: `src/global.d.ts` extends `IntlMessages` from `ja.json`. Any missing translation key in ko.json or en.json surfaces as a TypeScript compile error, not a raw key string visible to users.

## Verification Results

- `pnpm build --filter=@harukoto/admin`: PASSED (Next.js 16.1 build succeeds with turbopack)
- `npx tsc --noEmit`: PASSED (zero errors)
- `pnpm test -- --run`: PASSED (3 test files, 10 todos skipped, no failures)
- `grep -r "getSession" apps/admin/src/`: CLEAN (only in test comment string)
- `grep "getUser" apps/admin/src/lib/supabase/auth.ts`: FOUND
- Message key structure: IDENTICAL across ja/ko/en (auth, dashboard, locale, common)
- `pnpm ls --filter=@harukoto/admin`: workspace:* dependencies resolved

## Deviations from Plan

None - plan executed exactly as written.

The pnpm-workspace.yaml already had `apps/*` glob which covers apps/admin automatically — no change was needed (this was pre-noted in the plan as Issue #3 fix: verify glob, skip if present).

shadcn installation added additional dependencies (@hookform/resolvers, next-themes, radix-ui) beyond what was in the initial package.json. This is expected shadcn behavior — these are required peer dependencies for the installed components.

## Known Stubs

The following test files are intentional stubs (placeholder todos):

| File | Stub | Reason |
|------|------|--------|
| `apps/admin/src/__tests__/auth.test.ts` | 4 `.todo()` tests | Features implemented in Plan 02; stubs exist so Plan 02 verify commands can run |
| `apps/admin/src/__tests__/locale-route.test.ts` | 3 `.todo()` tests | API route implemented in Plan 03; stubs exist so Plan 03 verify commands can run |
| `apps/admin/src/__tests__/layout.test.tsx` | 3 `.todo()` tests | Layout component implemented in Plan 03; stubs exist so Plan 03 verify commands can run |

These stubs are intentional per plan design. Plans 02 and 03 executors must convert `.todo()` tests to real assertions as they implement the features.

## Self-Check: PASSED

Files verified:
- FOUND: apps/admin/package.json
- FOUND: apps/admin/next.config.ts
- FOUND: apps/admin/src/lib/supabase/auth.ts
- FOUND: apps/admin/i18n/request.ts
- FOUND: apps/admin/messages/ja.json
- FOUND: apps/admin/src/__tests__/auth.test.ts
- FOUND: apps/admin/src/components/ui/button.tsx

Commits verified:
- c14edb2 feat(01-01): scaffold apps/admin with configs, shadcn init, and workspace registration
- 66fec00 feat(01-01): add Supabase clients, auth guard, i18n config, root layout, and test scaffolds
