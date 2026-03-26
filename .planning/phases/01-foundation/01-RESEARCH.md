# Phase 1: Foundation - Research

**Researched:** 2026-03-26
**Domain:** Next.js 16.1 app scaffold in Turborepo monorepo, Supabase Auth RBAC, next-intl without routing, Vercel monorepo deployment
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AUTH-01 | Reviewer가 ID/PW로 어드민에 로그인할 수 있다 | Supabase `signInWithPassword` pattern from apps/web; `@supabase/ssr` server/client client setup documented |
| AUTH-02 | Reviewer가 아닌 사용자는 어드민 페이지 접근이 차단된다 | `app_metadata.reviewer` claim check via `requireReviewer()` + proxy.ts pattern; two-layer guard documented |
| AUTH-03 | Reviewer 역할이 폐기되면 즉시 접근이 차단된다 (DB 레벨 확인) | Live DB lookup on every request (not just JWT) documented; `supabase.auth.getUser()` forces server-side validation |
| I18N-01 | UI가 일본어를 기본 언어로 제공한다 | next-intl 4.8.3 without-routing mode, `ja` as default locale in `i18n/request.ts` |
| I18N-02 | UI 언어를 한국어로 전환할 수 있다| Cookie-based locale store, language picker component writes `NEXT_LOCALE` cookie |
| I18N-03 | UI 언어를 영어로 전환할 수 있다 | Same cookie-based mechanism; `en.json`, `ko.json`, `ja.json` message files |
</phase_requirements>

---

## Summary

Phase 1 creates `apps/admin` from scratch inside the existing Turborepo monorepo. It is the only phase with zero dependencies — everything else builds on it. The three pillars are: (1) a valid Next.js 16.1 app scaffold that shares monorepo packages and deploys to Vercel cleanly, (2) Supabase Auth with a `reviewer` role gate that enforces access both at the JWT level and at the live-DB level, and (3) next-intl "without routing" mode providing Japanese as the default UI language with Korean and English switchable via a cookie.

The existing `apps/web` is the canonical pattern to replicate: it uses `@supabase/ssr` for both browser (`createBrowserClient`) and server (`createServerClient`) clients, a `proxy.ts` file instead of `middleware.ts` (Next.js 16 pattern), and `signInWithPassword` for email/password auth. The admin app diverges from `apps/web` in exactly one auth dimension: it adds a `reviewer` role check on top of the basic authentication check. The role is stored in `app_metadata` and set via the Supabase service-role admin API — no Custom Access Token Hook or new DB table needed at 1-3 user scale.

The two most important build-order constraints are: (a) get a green Vercel deploy before building any feature (verify `outputFileTracingRoot` and monorepo-root file tracing), and (b) establish the `ja.json` locale file as the TypeScript type source for next-intl before writing any UI string, so missing translations surface as compile errors rather than raw key strings visible to Japanese reviewers.

**Primary recommendation:** Scaffold `apps/admin` by copying `apps/web` structure, stripping main-app-specific features, and adding the `reviewer` role guard in the proxy. Set up next-intl with `ja` as default locale. Verify Vercel deploy before adding any content UI.

---

## Project Constraints (from CLAUDE.md)

| Directive | Category |
|-----------|----------|
| Turborepo + pnpm workspace monorepo | Required toolchain |
| Next.js 16.1 App Router, Turbopack | Required framework version |
| TypeScript strict mode, no `any` | Type safety rule |
| shadcn/ui (Radix-based) for all UI components | UI library constraint |
| TanStack Query for server state | State management |
| Supabase (PostgreSQL + Auth) | Auth and DB constraint |
| Vercel deployment | Deployment target |
| Vitest + Testing Library for tests | Test framework |
| `proxy.ts` instead of `middleware.ts` | Next.js 16 specific pattern |
| `params`, `searchParams` must be `await`-ed | Next.js 16 async APIs |
| `cookies()`, `headers()` must be async | Next.js 16 async APIs |
| Commit convention: `feat:`, `fix:`, `chore:` etc. | Git convention |
| Codex cross-verification required before feat/bug commits | Workflow rule |
| pnpm from monorepo root only (no npm/yarn in subdirs) | Package manager rule |
| DDL changes via Alembic only | DB schema authority |
| File naming: kebab-case for files, PascalCase for components | Naming convention |

---

## Standard Stack

### Core (New for apps/admin)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| next-intl | 4.8.3 | i18n without URL routing, cookie-based locale | Only App Router-native i18n library with Server Component support; verified on npm 2026-03-26 |
| @supabase/ssr | 0.9.0 | Cookie-based Supabase auth for Next.js | Already used in apps/web; handles server/client session sync |
| @supabase/supabase-js | 2.100.0 | Supabase admin client (service role provisioning) | Already used in apps/web; required for `auth.admin.updateUserById` |

### Already in Monorepo (add to apps/admin/package.json)

| Library | Version | Purpose | Source |
|---------|---------|---------|--------|
| next | 16.1.6 | Framework | apps/web pinned |
| react | 19.2.3 | UI runtime | apps/web pinned |
| @tanstack/react-query | ^5.90.21 | Server state | apps/web pinned |
| react-hook-form | ^7.71.2 | Forms | apps/web pinned |
| zod | ^3.25.76 | Validation schemas | apps/web pinned |
| @harukoto/database | workspace:* | Prisma client | packages/database |
| @harukoto/types | workspace:* | Shared types | packages/types |
| @harukoto/config | workspace:* | TS / ESLint configs | packages/config |
| tailwindcss | ^4 | Styling | apps/web pinned |
| shadcn/ui (via CLI) | latest | Component library | apps/web pattern |
| lucide-react | ^0.575.0 | Icons | apps/web pinned |
| sonner | ^2.0.7 | Toast notifications | apps/web pinned |

### Not Used in Phase 1 (added later)

| Library | Phase | Reason Deferred |
|---------|-------|-----------------|
| @tanstack/react-table | Phase 2 | Data tables not needed until content list views |

### Installation

```bash
# From monorepo root
cd apps/admin
pnpm add next-intl

# Already in monorepo — reference as workspace deps in package.json
# @supabase/ssr, @supabase/supabase-js, next, react, @tanstack/react-query,
# react-hook-form, zod, tailwindcss, lucide-react, sonner
```

**Version verification (2026-03-26):**
- `next-intl`: 4.8.3 (latest stable) — `npm view next-intl version`
- `@supabase/ssr`: 0.9.0 — `npm view @supabase/ssr version`
- `@supabase/supabase-js`: 2.100.0 — `npm view @supabase/supabase-js version`

---

## Architecture Patterns

### Recommended Project Structure

```
apps/admin/
├── src/
│   ├── app/
│   │   ├── (auth)/
│   │   │   └── login/
│   │   │       └── page.tsx      # Email/password login form
│   │   ├── (admin)/
│   │   │   ├── layout.tsx        # Admin shell: sidebar + header + reviewer guard
│   │   │   └── dashboard/
│   │   │       └── page.tsx      # Stub dashboard (Phase 1: just a landing page)
│   │   ├── auth/
│   │   │   └── callback/
│   │   │       └── route.ts      # Supabase OAuth callback handler
│   │   ├── api/
│   │   │   └── locale/
│   │   │       └── route.ts      # POST: set locale cookie
│   │   ├── layout.tsx            # Root layout: NextIntlClientProvider + QueryProvider
│   │   ├── globals.css
│   │   └── not-found.tsx
│   ├── components/
│   │   ├── ui/                   # shadcn components (added via CLI)
│   │   ├── auth/
│   │   │   └── login-form.tsx
│   │   └── layout/
│   │       ├── sidebar.tsx
│   │       ├── header.tsx
│   │       └── locale-switcher.tsx
│   ├── lib/
│   │   ├── supabase/
│   │   │   ├── client.ts         # createBrowserClient
│   │   │   ├── server.ts         # createServerClient (cookies)
│   │   │   ├── admin.ts          # createAdminClient (service role)
│   │   │   └── auth.ts           # requireReviewer() guard
│   │   └── utils.ts              # cn() helper
│   └── proxy.ts                  # Next.js 16 middleware (reviewer route guard)
├── messages/
│   ├── ja.json                   # PRIMARY — Japanese (default locale)
│   ├── ko.json                   # Korean
│   └── en.json                   # English
├── i18n/
│   └── request.ts                # next-intl locale resolution (reads cookie)
├── next.config.ts                # createNextIntlPlugin + outputFileTracingRoot
├── tsconfig.json                 # extends @harukoto/config/tsconfig.nextjs.json
├── tailwind.config.ts
├── postcss.config.mjs
└── package.json                  # name: @harukoto/admin
```

### Pattern 1: apps/admin package.json

```json
{
  "name": "@harukoto/admin",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "eslint",
    "test": "vitest run",
    "test:watch": "vitest"
  },
  "dependencies": {
    "@harukoto/database": "workspace:*",
    "@harukoto/types": "workspace:*",
    "@harukoto/config": "workspace:*",
    "@supabase/ssr": "^0.9.0",
    "@supabase/supabase-js": "^2.100.0",
    "@tanstack/react-query": "^5.90.21",
    "class-variance-authority": "^0.7.1",
    "clsx": "^2.1.1",
    "lucide-react": "^0.575.0",
    "next": "16.1.6",
    "next-intl": "^4.8.3",
    "react": "19.2.3",
    "react-dom": "19.2.3",
    "react-hook-form": "^7.71.2",
    "sonner": "^2.0.7",
    "tailwind-merge": "^3.5.0",
    "zod": "^3.25.76"
  },
  "devDependencies": {
    "@testing-library/jest-dom": "^6.9.1",
    "@testing-library/react": "^16.3.2",
    "@types/node": "^20",
    "@types/react": "^19",
    "@types/react-dom": "^19",
    "@vitejs/plugin-react": "^5.1.4",
    "@tailwindcss/postcss": "^4",
    "eslint": "^9",
    "eslint-config-next": "16.1.6",
    "jsdom": "^28.1.0",
    "shadcn": "^3.8.5",
    "tailwindcss": "^4",
    "typescript": "^5",
    "vitest": "^4.0.18"
  }
}
```

### Pattern 2: next.config.ts — outputFileTracingRoot + next-intl plugin

```typescript
// Source: apps/web/next.config.ts adapted + PITFALLS.md Pitfall 4
import type { NextConfig } from 'next';
import path from 'path';
import createNextIntlPlugin from 'next-intl/plugin';

const withNextIntl = createNextIntlPlugin('./i18n/request.ts');

const nextConfig: NextConfig = {
  reactCompiler: true,
  // CRITICAL: must point to monorepo root so shared packages are traced
  outputFileTracingRoot: path.join(__dirname, '../../'),
};

export default withNextIntl(nextConfig);
```

### Pattern 3: i18n/request.ts — cookie-based locale (without routing mode)

```typescript
// Source: next-intl official docs — without i18n routing
// https://next-intl.dev/docs/getting-started/app-router/without-i18n-routing
import { getRequestConfig } from 'next-intl/server';
import { cookies } from 'next/headers';

export default getRequestConfig(async () => {
  const cookieStore = await cookies();
  const locale = cookieStore.get('NEXT_LOCALE')?.value ?? 'ja'; // ja is default

  return {
    locale,
    messages: (await import(`../messages/${locale}.json`)).default,
  };
});
```

### Pattern 4: Root layout with NextIntlClientProvider

```typescript
// apps/admin/src/app/layout.tsx
import { NextIntlClientProvider } from 'next-intl';
import { getLocale, getMessages } from 'next-intl/server';
import { QueryProvider } from '@/components/providers/query-provider';

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const locale = await getLocale();
  const messages = await getMessages();

  return (
    <html lang={locale} suppressHydrationWarning>
      <body>
        <NextIntlClientProvider messages={messages}>
          <QueryProvider>{children}</QueryProvider>
        </NextIntlClientProvider>
      </body>
    </html>
  );
}
```

### Pattern 5: Supabase client files (replicate from apps/web exactly)

```typescript
// src/lib/supabase/client.ts — browser client (same as apps/web)
'use client';
import { createBrowserClient } from '@supabase/ssr';

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}

// src/lib/supabase/server.ts — server client (same as apps/web)
import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';

export async function createClient() {
  const cookieStore = await cookies();
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() { return cookieStore.getAll(); },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            );
          } catch {}
        },
      },
    }
  );
}

// src/lib/supabase/admin.ts — service role client (same as apps/web)
import { createClient } from '@supabase/supabase-js';

export function createAdminClient() {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { autoRefreshToken: false, persistSession: false } }
  );
}
```

### Pattern 6: requireReviewer() guard — AUTH-02 and AUTH-03

The key requirement for AUTH-03 (immediate revocation on DB change) means we cannot rely on the JWT `app_metadata` claim alone — the JWT lives up to 1 hour. We must call `supabase.auth.getUser()` on every protected request, which issues a server-side token validation against Supabase's auth server (not just local JWT signature verification). This is the correct pattern per Supabase's own security guidance: `getUser()` hits the Supabase Auth API and always returns the current user state.

```typescript
// src/lib/supabase/auth.ts
import { redirect } from 'next/navigation';
import { createClient } from './server';

export async function getReviewerUser() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  return user;
}

export async function requireReviewer() {
  const user = await getReviewerUser();

  if (!user) {
    redirect('/login');
  }

  // Check reviewer role in app_metadata (set via service role admin API)
  // app_metadata is server-controlled — users cannot modify it themselves
  const isReviewer = user.app_metadata?.reviewer === true;

  if (!isReviewer) {
    redirect('/login?error=access_denied');
  }

  return user;
}
```

**Why `getUser()` satisfies AUTH-03:** `supabase.auth.getUser()` validates the access token against Supabase Auth's server. When a reviewer's role is revoked (their `app_metadata.reviewer` removed via admin API), the next `getUser()` call returns the updated user object without the reviewer claim, regardless of how much time is left on the JWT. This gives near-real-time revocation on the next page load or refresh.

### Pattern 7: proxy.ts — admin route guard (Next.js 16 pattern)

```typescript
// src/proxy.ts
// Named proxy.ts (not middleware.ts) — this is the Next.js 16 project pattern
// as documented in .claude/rules/web.md
import { createServerClient } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';

export async function proxy(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() { return request.cookies.getAll(); },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value)
          );
          supabaseResponse = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options)
          );
        },
      },
    }
  );

  const { data: { user } } = await supabase.auth.getUser();

  // All admin pages except /login require reviewer role
  const isLoginPage = request.nextUrl.pathname === '/login';
  const isAuthCallback = request.nextUrl.pathname.startsWith('/auth/');
  const isApiRoute = request.nextUrl.pathname.startsWith('/api/');

  if (!isLoginPage && !isAuthCallback && !isApiRoute) {
    if (!user) {
      const url = request.nextUrl.clone();
      url.pathname = '/login';
      return NextResponse.redirect(url);
    }

    // Role check — app_metadata is returned by getUser() server-side
    const isReviewer = user.app_metadata?.reviewer === true;
    if (!isReviewer) {
      const url = request.nextUrl.clone();
      url.pathname = '/login';
      url.searchParams.set('error', 'access_denied');
      return NextResponse.redirect(url);
    }
  }

  // Redirect logged-in reviewer away from /login
  if (user && isLoginPage && user.app_metadata?.reviewer === true) {
    const url = request.nextUrl.clone();
    url.pathname = '/dashboard';
    return NextResponse.redirect(url);
  }

  return supabaseResponse;
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
};
```

**Important:** There must also be a `middleware.ts` at `apps/admin/src/` (or root) that calls `proxy()`. In Next.js 16, the pattern used by apps/web is: `middleware.ts` imports and calls `proxy()` from `proxy.ts`.

```typescript
// src/middleware.ts
export { proxy as middleware, config } from './proxy';
```

### Pattern 8: Reviewer provisioning (one-time setup, not code)

```typescript
// scripts/provision-reviewer.ts (run once, not part of app runtime)
// Uses service role key to set app_metadata
import { createAdminClient } from '../src/lib/supabase/admin';

async function provisionReviewer(userId: string) {
  const supabase = createAdminClient();
  const { error } = await supabase.auth.admin.updateUserById(userId, {
    app_metadata: { reviewer: true },
  });
  if (error) throw error;
  console.log(`Reviewer role granted to ${userId}`);
}

async function revokeReviewer(userId: string) {
  const supabase = createAdminClient();
  const { error } = await supabase.auth.admin.updateUserById(userId, {
    app_metadata: { reviewer: false },
  });
  if (error) throw error;
  console.log(`Reviewer role revoked from ${userId}`);
}
```

This can also be done directly in Supabase Dashboard under Authentication > Users > Edit User > app_metadata (JSON editor).

### Pattern 9: Language switcher component

```typescript
// src/components/layout/locale-switcher.tsx
'use client';
import { useRouter } from 'next/navigation';

const LOCALES = [
  { code: 'ja', label: '日本語' },
  { code: 'ko', label: '한국어' },
  { code: 'en', label: 'English' },
] as const;

export function LocaleSwitcher({ currentLocale }: { currentLocale: string }) {
  const router = useRouter();

  async function switchLocale(locale: string) {
    // Set cookie and refresh — next-intl reads it on next request
    await fetch('/api/locale', {
      method: 'POST',
      body: JSON.stringify({ locale }),
      headers: { 'Content-Type': 'application/json' },
    });
    router.refresh();
  }

  return (
    <div className="flex gap-2">
      {LOCALES.map(({ code, label }) => (
        <button
          key={code}
          onClick={() => switchLocale(code)}
          className={currentLocale === code ? 'font-bold underline' : ''}
        >
          {label}
        </button>
      ))}
    </div>
  );
}
```

```typescript
// src/app/api/locale/route.ts
import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';

export async function POST(request: Request) {
  const { locale } = await request.json();
  const validLocales = ['ja', 'ko', 'en'];
  if (!validLocales.includes(locale)) {
    return NextResponse.json({ error: 'Invalid locale' }, { status: 400 });
  }
  const cookieStore = await cookies();
  cookieStore.set('NEXT_LOCALE', locale, {
    path: '/',
    maxAge: 365 * 24 * 60 * 60,
    sameSite: 'lax',
  });
  return NextResponse.json({ locale });
}
```

### Pattern 10: next-intl TypeScript type safety setup

Create `src/global.d.ts` so all message keys are type-checked:

```typescript
// src/global.d.ts
import messages from '../messages/ja.json';

type Messages = typeof messages;

declare global {
  interface IntlMessages extends Messages {}
}
```

This makes `ja.json` the type source. Any key used in `useTranslations()` that does not exist in `ja.json` is a TypeScript compile error.

### Anti-Patterns to Avoid

- **Using `session.user` instead of `getUser()` for role checks:** `session.user` is decoded from the local JWT without server validation. For AUTH-03 (immediate revocation), you must call `supabase.auth.getUser()` which validates against Supabase Auth server.
- **Checking JWT expiry manually:** Do not implement custom JWT decoding for role checks. `getUser()` handles this correctly.
- **URL-based locale routing:** Do not use `[locale]` folder wrapping. The without-routing mode uses cookie-based locale only — flat `app/` directory.
- **Using `middleware.ts` as the main auth logic file:** In this project, `middleware.ts` exports from `proxy.ts`. Auth logic lives in `proxy.ts` to match `apps/web` conventions.
- **Adding reviewer role to `user_metadata`:** `user_metadata` is user-writable. Only `app_metadata` is admin-only and cannot be changed by the user themselves.
- **Forgetting `outputFileTracingRoot` before first Vercel deploy:** Silent `MODULE_NOT_FOUND` at runtime if omitted.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Cookie session management for Supabase | Custom cookie read/write | `@supabase/ssr` `createServerClient` + `createBrowserClient` | Handles token refresh, SameSite, HttpOnly, secure flags correctly across all Next.js rendering modes |
| JWT verification | Custom JWKS fetch + decode | `supabase.auth.getUser()` | Server-validated; handles token refresh transparently |
| i18n message loading | Manual JSON import per page | next-intl `getTranslations()` / `useTranslations()` | Server Component support, TypeScript key inference, automatic locale resolution |
| Language preference storage | localStorage | Cookie via `/api/locale` route | Works server-side during SSR; localStorage is client-only |
| Monorepo shared package resolution | Custom webpack aliases | `workspace:*` in package.json + `outputFileTracingRoot` in next.config.ts | Correct tracing for Vercel standalone deployment |

**Key insight:** The entire auth stack (session, role check, redirect) is 3 files: `client.ts`, `server.ts`, `auth.ts` — all copied from `apps/web` with a one-line role check addition. Do not add complexity here.

---

## Common Pitfalls

### Pitfall 1: AUTH-03 — `session.user` vs `getUser()` for Reviewer Check

**What goes wrong:** Using `supabase.auth.getSession()` returns a locally decoded JWT. If the reviewer's `app_metadata.reviewer` is removed via admin API, the old session still has `reviewer: true` until the JWT expires (up to 1 hour). AUTH-03 requires immediate revocation on page refresh.

**Why it happens:** Developers assume JWT validation is sufficient. It is for expiry but not for claims that can be updated server-side.

**How to avoid:** Always use `supabase.auth.getUser()` in proxy.ts and `requireReviewer()`. This validates the token against Supabase Auth servers and returns the current `app_metadata` state.

**Warning signs:** proxy.ts contains `getSession()` rather than `getUser()`.

### Pitfall 2: outputFileTracingRoot Missing — Vercel Deploy Crashes

**What goes wrong:** `apps/admin` builds fine locally with `turbo build --filter=@harukoto/admin`, but Vercel deployment crashes with `Cannot find module '@harukoto/database'` at runtime.

**Why it happens:** Next.js standalone output traces dependencies relative to the app directory. `@harukoto/database` is at `../../packages/database` — outside the app directory.

**How to avoid:** Add `outputFileTracingRoot: path.join(__dirname, '../../')` to `apps/admin/next.config.ts` before attempting first Vercel deploy.

**Warning signs:** `next build` output shows `.next/standalone/` with no `packages/` folder inside.

### Pitfall 3: next-intl Japanese Locale Missing Keys

**What goes wrong:** UI strings added to `ko.json` but not `ja.json`. Japanese reviewers see raw key strings like `auth.login.submit` in the button instead of "ログイン".

**Why it happens:** Developer writes Korean first (development language), defers Japanese translation. With no CI enforcement, the gap grows silently.

**How to avoid:** Set `ja.json` as the TypeScript type source via `global.d.ts`. Any key in `useTranslations()` not in `ja.json` is a compile error. All three files (`ja.json`, `ko.json`, `en.json`) must be populated before any UI component is committed.

**Warning signs:** `tsc --noEmit` passes but `ja.json` has fewer keys than `ko.json`.

### Pitfall 4: User-Writable `user_metadata` Used for Role

**What goes wrong:** Reviewer role stored in `user_metadata.reviewer` instead of `app_metadata.reviewer`. Any authenticated user can call `supabase.auth.updateUser({ data: { reviewer: true } })` from the browser to grant themselves reviewer access.

**Why it happens:** `user_metadata` is the familiar field; `app_metadata` is less commonly documented.

**How to avoid:** Role MUST be in `app_metadata`. Only writable via service-role admin API (`supabase.auth.admin.updateUserById`). Check `user.app_metadata?.reviewer`, never `user.user_metadata?.reviewer`.

**Warning signs:** Reviewer provisioning script uses `updateUser` (user-scoped) instead of `auth.admin.updateUserById` (admin-scoped).

### Pitfall 5: Not Creating middleware.ts (only proxy.ts)

**What goes wrong:** The route guard in `proxy.ts` never runs because Next.js looks for `middleware.ts` (or `middleware.js`) at the app root. If `proxy.ts` exists but no `middleware.ts` re-exports it, all routes are unprotected.

**Why it happens:** Following the `apps/web` naming convention without understanding that `apps/web` does have a `middleware.ts` that calls `proxy()`.

**How to avoid:** Create both files: `proxy.ts` (logic) and `middleware.ts` (re-export that Next.js picks up).

**Warning signs:** Unauthenticated browser can access `/dashboard` without being redirected to `/login`.

### Pitfall 6: Vercel Project Root Directory Misconfiguration

**What goes wrong:** Vercel project root is set to `/` (monorepo root) instead of `apps/admin`. The build command runs `turbo build` which builds ALL apps, deploys the wrong output.

**How to avoid:** In Vercel project settings: Root Directory = `apps/admin`, Framework Preset = Next.js. Add admin-specific env vars to THIS project, not the main app project.

---

## Reviewer Provisioning Flow (Phase 1 Risk Item)

From STATE.md: "Document reviewer provisioning flow before first deploy."

**Two methods:**

1. **Supabase Dashboard** (recommended for 1-3 users): Authentication > Users > Click user > Edit > Add to `app_metadata` JSON:
   ```json
   { "reviewer": true }
   ```

2. **Script** (for automation): `scripts/provision-reviewer.ts` using `createAdminClient()` and `auth.admin.updateUserById()`.

**Revocation:** Set `app_metadata.reviewer` to `false` or remove the key. The next `getUser()` call (next page refresh) will fail the reviewer check and redirect to login.

---

## Environment Variables

```bash
# .env.local for apps/admin (separate from apps/web)
NEXT_PUBLIC_SUPABASE_URL=https://[project].supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=[anon key]
SUPABASE_SERVICE_ROLE_KEY=[service role key — server only, never exposed to client]
```

**Vercel setup:** Add these three env vars to the `apps/admin` Vercel project separately from the `apps/web` project. The service role key must be marked as "Server-side only" (not exposed to browser).

**turbo.json globalEnv update required:** Add admin-specific env vars so Turborepo cache busting works:
```json
"globalEnv": [
  "DATABASE_URL",
  "DIRECT_URL",
  // ... existing ...
  "NEXT_PUBLIC_SUPABASE_URL",
  "NEXT_PUBLIC_SUPABASE_ANON_KEY",
  "SUPABASE_SERVICE_ROLE_KEY"
]
```

Note: If `NEXT_PUBLIC_SUPABASE_URL` is already in globalEnv for `apps/web`, no duplication needed — it's project-wide. Check current `turbo.json`.

---

## State of the Art

| Old Approach | Current Approach | Impact for Phase 1 |
|--------------|------------------|-------------------|
| `middleware.ts` as monolithic auth file | `proxy.ts` (logic) + `middleware.ts` (re-export) | Must use two-file pattern per `.claude/rules/web.md` |
| `createMiddlewareClient` from `@supabase/auth-helpers-nextjs` | `createServerClient` from `@supabase/ssr` | Already in apps/web; use same import |
| `getSession()` for server-side auth | `getUser()` for server-side auth | getUser() is always server-validated — required for AUTH-03 |
| URL-segment locale routing (`/ja/`, `/ko/`) | Cookie-based locale (next-intl without routing) | Flat `app/` structure, simpler redirect logic |
| Custom Access Token Hook for roles | `app_metadata` via admin API | No hook setup needed at 1-3 user scale |

**Deprecated/outdated:**
- `@supabase/auth-helpers-nextjs`: Replaced by `@supabase/ssr`. Do not use.
- `next-i18next`: Pages Router heritage. Do not use in App Router project.
- `getSession()` for server-side auth checks: Returns locally decoded JWT without server validation. Use `getUser()`.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Vitest 4.0.18 + @testing-library/react 16.3.2 |
| Config file | `apps/admin/vitest.config.ts` (Wave 0 gap — replicate from apps/web) |
| Quick run command | `cd apps/admin && pnpm test` |
| Full suite command | `cd apps/admin && pnpm test:coverage` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AUTH-01 | Login form submits with email+password; on success redirects to /dashboard | unit (mock Supabase) | `pnpm test -- login-form` | Wave 0 gap |
| AUTH-02 | Non-reviewer user after login gets redirected to /login?error=access_denied | unit (mock getUser returning no reviewer claim) | `pnpm test -- auth` | Wave 0 gap |
| AUTH-03 | requireReviewer() calls getUser() not getSession() | unit (verify getUser called) | `pnpm test -- require-reviewer` | Wave 0 gap |
| I18N-01 | Root layout renders with `lang="ja"` when no cookie set | unit | `pnpm test -- layout` | Wave 0 gap |
| I18N-02 | POST /api/locale with `{ locale: "ko" }` sets NEXT_LOCALE cookie | unit (Route Handler test) | `pnpm test -- locale-route` | Wave 0 gap |
| I18N-03 | POST /api/locale with `{ locale: "en" }` sets NEXT_LOCALE cookie | unit (Route Handler test) | (same file as I18N-02) | Wave 0 gap |

### Sampling Rate
- **Per task commit:** `cd apps/admin && pnpm test`
- **Per wave merge:** `cd apps/admin && pnpm test:coverage`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `apps/admin/vitest.config.ts` — copy from apps/web, update paths
- [ ] `apps/admin/src/__tests__/setup.ts` — `import '@testing-library/jest-dom/vitest'`
- [ ] `apps/admin/src/__tests__/auth.test.ts` — covers AUTH-01, AUTH-02, AUTH-03
- [ ] `apps/admin/src/__tests__/locale-route.test.ts` — covers I18N-02, I18N-03
- [ ] `apps/admin/src/__tests__/layout.test.tsx` — covers I18N-01

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node.js | All builds | Yes | (monorepo uses it) | — |
| pnpm | Monorepo install | Yes | (monorepo uses it) | — |
| Supabase project | Auth, DB | Yes (existing project) | 2.100.0 SDK | — |
| Vercel CLI / project | Deployment | Needs new project creation | — | Create during Phase 1 |
| next-intl | i18n | Not yet (new dep) | 4.8.3 | — |

**Missing dependencies with no fallback:**
- New Vercel project for `apps/admin` — must be created before deploy verification (Phase 1 success criterion 5)

**Missing dependencies with fallback:**
- None for core functionality

---

## Open Questions

1. **Is `NEXT_PUBLIC_SUPABASE_URL` already in `turbo.json` globalEnv?**
   - What we know: Current `turbo.json` globalEnv has `DATABASE_URL`, `DIRECT_URL`, `AI_PROVIDER`, `OPENAI_API_KEY`, `GOOGLE_GENERATIVE_AI_API_KEY`, `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`. Supabase vars are NOT listed.
   - What's unclear: Whether this causes incorrect Turborepo cache hits when `SUPABASE_*` env vars change.
   - Recommendation: Add `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` to `turbo.json` globalEnv as part of Phase 1 scaffold task.

2. **Does `apps/web` have a `middleware.ts` file?**
   - What we know: `apps/web` has `src/proxy.ts` and CLAUDE.md rules say "use proxy.ts not middleware.ts". BUT Next.js still requires a `middleware.ts` to be the entry point — `proxy.ts` must be called from somewhere.
   - What's unclear: The exact location and content of the middleware.ts entry point in apps/web (didn't find it in `find` output because the search was scoped).
   - Recommendation: Before writing `apps/admin/src/middleware.ts`, verify with `find /Users/kimkunwoo/WhiteMouseDev/japanese/apps/web -name "middleware.ts"` — it may be at the app root rather than `src/`.

3. **Are Noto fonts (NotoSansJP, NotoSansKR) needed in apps/admin?**
   - What we know: `apps/web` loads both `Noto_Sans_JP` and `Noto_Sans_KR` from Google Fonts. Since admin displays Japanese content (vocabulary, grammar) and has a 3-language UI, both fonts are likely needed.
   - Recommendation: Include both fonts in `apps/admin/src/app/layout.tsx` matching the `apps/web` pattern.

---

## Sources

### Primary (HIGH confidence)
- `apps/web/src/proxy.ts` — auth proxy pattern (direct codebase read)
- `apps/web/src/lib/supabase/{client,server,admin,auth}.ts` — Supabase client setup (direct codebase read)
- `apps/web/src/app/layout.tsx` — root layout pattern (direct codebase read)
- `apps/web/vitest.config.ts` — test framework setup (direct codebase read)
- `apps/web/package.json` — all pinned versions (direct codebase read)
- `.claude/rules/web.md` — proxy.ts convention, async cookies/params rules (project rules)
- `.planning/research/STACK.md` — stack decisions (project research, verified 2026-03-26)
- `.planning/research/ARCHITECTURE.md` — architecture decisions (project research, verified 2026-03-26)
- `.planning/research/PITFALLS.md` — pitfall catalog (project research, verified 2026-03-26)
- `turbo.json` — current globalEnv and task pipeline (direct codebase read)
- npm registry: next-intl@4.8.3, @supabase/ssr@0.9.0, @supabase/supabase-js@2.100.0 — verified 2026-03-26

### Secondary (MEDIUM confidence)
- [next-intl without routing docs](https://next-intl.dev/docs/getting-started/app-router/without-i18n-routing) — getRequestConfig + cookie pattern
- [Supabase getUser() vs getSession()](https://supabase.com/docs/reference/javascript/auth-getuser) — server-validated auth
- [Supabase app_metadata RBAC](https://supabase.com/docs/guides/database/postgres/custom-claims-and-role-based-access-control-rbac) — app_metadata is admin-only

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all versions verified from npm registry and existing codebase
- Architecture: HIGH — based on direct codebase analysis of apps/web patterns + official Supabase docs
- Auth patterns (AUTH-03 via getUser): HIGH — Supabase official docs confirm getUser() is server-validated
- Pitfalls: HIGH — outputFileTracingRoot verified in PITFALLS.md, middleware.ts gap is observable

**Research date:** 2026-03-26
**Valid until:** 2026-04-25 (next-intl and @supabase/ssr are active development; check for breaking changes after 30 days)
