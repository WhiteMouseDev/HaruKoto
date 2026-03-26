---
phase: 01-foundation
plan: "03"
subsystem: ui
tags: [next-intl, next.js, supabase, shadcn, i18n, locale, dashboard]

requires:
  - phase: 01-foundation plan 01
    provides: requireReviewer auth guard, Supabase clients, i18n NEXT_LOCALE cookie config

provides:
  - Admin shell layout with header (logo, locale switcher, user info, logout)
  - POST /api/locale endpoint setting NEXT_LOCALE cookie with 1-year expiry
  - LocaleSwitcher client component (ja/ko/en native labels, active state highlight)
  - Dashboard page with welcome message and 4 placeholder content type cards
  - LogoutButton client component calling supabase.auth.signOut()
  - 404 not-found page
  - Logo SVG asset in admin public directory

affects:
  - 01-04 (login page can use same header pattern)
  - Phase 2 (sidebar addition: layout is flex-col compatible)
  - Phase 3/4 (content pages will extend dashboard cards)

tech-stack:
  added: []
  patterns:
    - "Server component Header receives locale from getLocale() and passes to LocaleSwitcher client component"
    - "Locale switching: client POST to /api/locale -> cookieStore.set('NEXT_LOCALE') -> router.refresh()"
    - "LogoutButton as minimal 'use client' component receiving label from server component translation"
    - "Admin layout calls requireReviewer() at layout level, protecting all (admin) routes"
    - "proxy.ts only (no middleware.ts re-export) per CLAUDE.md Next.js 16 convention"

key-files:
  created:
    - apps/admin/src/app/api/locale/route.ts
    - apps/admin/src/components/layout/locale-switcher.tsx
    - apps/admin/src/components/layout/header.tsx
    - apps/admin/src/components/layout/logout-button.tsx
    - apps/admin/src/app/(admin)/layout.tsx
    - apps/admin/src/app/(admin)/dashboard/page.tsx
    - apps/admin/src/app/not-found.tsx
    - apps/admin/public/logo-symbol.svg
  modified:
    - apps/admin/src/middleware.ts (deleted — was redundant re-export of proxy.ts)

key-decisions:
  - "Header is async Server Component using getTranslations(); locale string passed from layout via getLocale()"
  - "LogoutButton extracted as separate 'use client' file to keep Header as pure Server Component"
  - "Native language labels hardcoded (日本語/한국어/English) not translated — shown in own language regardless of UI locale"
  - "Removed middleware.ts: Next.js 16 forbids both middleware.ts and proxy.ts; proxy.ts is canonical per CLAUDE.md"

patterns-established:
  - "Pattern: Server layout -> getLocale() -> pass locale prop to client components that need it"
  - "Pattern: Server component passes translated string to client button (LogoutButton.label)"

requirements-completed: [I18N-02, I18N-03]

duration: 5min
completed: "2026-03-26"
---

# Phase 01 Plan 03: Admin Shell, Dashboard, and Locale Switcher Summary

**Next-intl cookie-based locale switching with ja/ko/en support, admin shell header (logo/user/logout), and dashboard stub with 4 content-type placeholder cards**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-03-26T08:00:00Z
- **Completed:** 2026-03-26T08:03:40Z
- **Tasks:** 2
- **Files modified:** 8 created, 1 deleted

## Accomplishments

- Locale API route (`POST /api/locale`) sets `NEXT_LOCALE` cookie with 1-year expiry; validates against ja/ko/en allowlist
- LocaleSwitcher dropdown with native language labels (日本語/한국어/English), active locale highlighted with cherry-pink primary color
- Admin shell layout calls `requireReviewer()` protecting all `(admin)` routes; header shows logo + HaruKoto Admin + locale switcher + user name + logout
- Dashboard page with localized welcome message (`こんにちは、{name}さん`) and 2x2 grid of placeholder content cards
- Full `pnpm build` passes with all routes registered: `/dashboard`, `/api/locale`, `/api/auth/callback`, `/login`, `/_not-found`

## Task Commits

1. **Task 1: Locale API route and locale switcher** - `c9c3d1e` (feat)
2. **Task 2: Admin shell layout, header, dashboard, not-found** - `34cc427` (feat)

## Files Created/Modified

- `apps/admin/src/app/api/locale/route.ts` - POST endpoint setting NEXT_LOCALE cookie with validation
- `apps/admin/src/components/layout/locale-switcher.tsx` - Client dropdown with native language labels and router.refresh()
- `apps/admin/src/components/layout/header.tsx` - Async server component: logo, HaruKoto Admin, locale switcher, user name, logout
- `apps/admin/src/components/layout/logout-button.tsx` - Client component: supabase.auth.signOut() + router.push('/login')
- `apps/admin/src/app/(admin)/layout.tsx` - Admin shell with requireReviewer guard and flex-col layout for Phase 2 sidebar
- `apps/admin/src/app/(admin)/dashboard/page.tsx` - Welcome message + 4 placeholder cards (vocabulary/grammar/quiz/conversation)
- `apps/admin/src/app/not-found.tsx` - 404 page with link back to /dashboard
- `apps/admin/public/logo-symbol.svg` - HaruKoto cherry-pink logo asset
- `apps/admin/src/middleware.ts` - DELETED (redundant re-export of proxy.ts)

## Decisions Made

- Header implemented as async Server Component using `getTranslations()` from `next-intl/server`; locale string threaded from layout via `getLocale()`
- LogoutButton extracted as separate `'use client'` component to keep Header free of client directives
- Native language labels hardcoded (not translated) in LocaleSwitcher — show in their own language regardless of current UI locale
- Removed `middleware.ts` (it was re-exporting proxy.ts); Next.js 16 forbids both files and CLAUDE.md specifies proxy.ts only

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Removed middleware.ts that conflicted with proxy.ts**

- **Found during:** Task 2 (build verification)
- **Issue:** `pnpm build` failed with "Both middleware file ./src/middleware.ts and proxy file ./src/proxy.ts are detected" — Next.js 16 forbids both
- **Fix:** Deleted `middleware.ts` (it was only re-exporting from proxy.ts anyway); `proxy.ts` is the canonical approach per CLAUDE.md
- **Files modified:** `apps/admin/src/middleware.ts` (deleted)
- **Verification:** Build succeeded after deletion
- **Committed in:** 34cc427 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking build error)
**Impact on plan:** Fix was necessary; middleware.ts was vestigial scaffolding. No scope creep.

## Issues Encountered

None beyond the middleware.ts/proxy.ts conflict auto-fixed above.

## Known Stubs

- Dashboard cards show `t('dashboard.emptyBody')` placeholder text ("コンテンツ一覧はフェーズ2で追加されます") — intentional per plan; Phase 2 will wire real content lists

## Next Phase Readiness

- Admin shell complete; Phase 2 can add sidebar by inserting it as flex sibling in `(admin)/layout.tsx`
- Locale switching fully functional — I18N-02 and I18N-03 satisfied
- Dashboard placeholder cards ready for Phase 2 content list wiring
- `requireReviewer()` gate is active on all `(admin)` routes

---
*Phase: 01-foundation*
*Completed: 2026-03-26*
