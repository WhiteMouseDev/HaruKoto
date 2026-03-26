# Technology Stack — HaruKoto Admin (apps/admin)

**Project:** HaruKoto Admin — 학습 데이터 관리 도구
**Researched:** 2026-03-26
**Scope:** Additive stack for `apps/admin` within an existing Next.js + Turborepo + Supabase + FastAPI monorepo.
**What this does NOT cover:** The existing stack (Next.js 16.1, Supabase, Prisma, TanStack Query, React Hook Form, Zod, shadcn/ui, Tailwind) — these are already verified in `.planning/codebase/STACK.md` and are reused as-is.

---

## Decision Summary

| Dimension | Choice | Version | Confidence |
|-----------|--------|---------|------------|
| i18n | next-intl (without routing mode) | ^4.8.3 | HIGH |
| Data table | TanStack Table + shadcn data-table pattern | ^8.21.3 | HIGH |
| Form builder | React Hook Form + Zod + shadcn Form (already in monorepo) | already pinned | HIGH |
| Admin framework | None — build custom with existing primitives | — | HIGH |
| Workspace config | Turborepo standard `apps/admin` package | — | HIGH |

---

## Recommended Stack (New Additions Only)

### i18n: next-intl 4.8.3 — "without routing" mode

**Why next-intl:**
next-intl is the de-facto standard for Next.js App Router i18n in 2026. It has native Server Component support (`getTranslations()` runs server-side with zero JS shipped to the client), full TypeScript type safety for message keys, and an officially documented "without i18n routing" setup path that is purpose-built for exactly this use case: a small internal tool where locale is stored in a cookie/user preference rather than the URL.

**Why "without routing" mode:**
The admin panel has 1-3 users who each have a preferred language (Korean developer, Japanese native reviewers). URL-based routing (`/ja/vocabulary`, `/ko/vocabulary`) adds complexity and is wrong for a preference-driven tool. With "without routing" mode:
- Locale is read from a cookie set on login or a language-picker UI element
- No URL rewrites or middleware locale matching needed
- Structure of `apps/admin/app/` stays flat — no `[locale]/` wrapping
- Locale changes update the cookie; the page re-renders with new messages

**Why not next-i18next:** next-i18next is Pages Router heritage. It has App Router support but it is retrofitted and requires extra setup. next-intl was built for App Router from the ground up.

**Why not react-i18next standalone:** Works, but duplicates what next-intl provides with better Next.js integration (Server Component support, SWC plugin for ahead-of-time compilation, typed message keys).

```bash
pnpm add next-intl
```

**Setup notes:**
- Create `apps/admin/messages/ko.json`, `apps/admin/messages/ja.json`, `apps/admin/messages/en.json`
- Configure `apps/admin/i18n/request.ts` to read locale from cookie
- Wrap root layout with `<NextIntlClientProvider>` (inherits server config automatically in v4+)
- Add `createNextIntlPlugin` to `apps/admin/next.config.ts`

---

### Data Table: TanStack Table ^8.21.3 + shadcn data-table pattern

**Why TanStack Table:**
The monorepo already uses `@tanstack/react-query` ^5.90.21. TanStack Table is the headless companion. shadcn/ui's official docs provide a canonical `data-table.tsx` component built on TanStack Table — this is the standard internal-tool pattern for this stack in 2026. No new UI library is introduced; the table uses existing shadcn `<Table>`, `<Button>`, `<DropdownMenu>`, `<Input>` primitives.

TanStack Table v8 (current: 8.21.3) provides:
- Server-side pagination, sorting, filtering (essential for Vocabulary/Grammar tables with potentially hundreds of rows)
- Column visibility toggles (useful for dense data like vocabulary entries)
- Row selection for bulk operations
- Full TypeScript generic inference on column definitions

**Why not AG Grid / Handsontable / react-data-grid:**
These are heavyweight grid libraries designed for spreadsheet-style editing. The admin use case is "review and edit individual records" — not bulk cell editing. AG Grid Community is 400KB+. TanStack Table is ~15KB headless. The shadcn pattern keeps the UI consistent with the existing design system.

**Why not a simple `<table>`:**
Sorting, filtering, and pagination across Vocabulary/Grammar/Quiz tables are required features. Manual implementation duplicates what TanStack Table provides.

```bash
# @tanstack/react-table is likely already in the monorepo; verify first
pnpm add @tanstack/react-table
```

**Pattern to follow:**
Copy shadcn's data-table building blocks into `apps/admin/components/data-table/`:
- `data-table.tsx` — generic wrapper with TanStack Table instance
- `data-table-column-header.tsx` — sortable column headers
- `data-table-pagination.tsx` — page controls
- `data-table-toolbar.tsx` — search input + filter dropdowns

Each content type (Vocabulary, Grammar, Quiz, Scenario) gets its own `columns.tsx` that uses these shared primitives.

---

### Form Builder: React Hook Form + Zod + shadcn Form (already in monorepo)

**No new libraries needed.** The existing stack already has:
- `react-hook-form` ^7.71.2 (pinned in `apps/web`)
- `@hookform/resolvers` ^5.2.2
- `zod` ^3.25.76
- shadcn `<Form>`, `<FormField>`, `<FormItem>`, `<FormLabel>`, `<FormMessage>` components

**Why not a schema-driven form builder (e.g., react-jsonschema-form, Formly):**
Schema-driven builders trade flexibility for convention. The admin forms here are small in number (Vocabulary edit, Grammar edit, Quiz edit, Scenario edit), each with different field types and validation rules. Building them explicitly with React Hook Form + Zod is faster and produces more maintainable, type-safe code than wiring up a form builder's configuration layer.

For TTS audio fields (play/regenerate buttons), explicit field components are the only sane path — no form builder handles that custom interaction.

**Pattern:**
Each data type gets a `<VocabularyForm>`, `<GrammarForm>`, etc. Each form:
1. Defines a Zod schema that matches the Prisma/SQLAlchemy model
2. Uses `useForm<z.infer<typeof schema>>` from React Hook Form
3. Submits via a TanStack Query `useMutation` to the FastAPI endpoint
4. Uses shadcn `<FormField>` components for every field

---

### Admin Framework: None — Custom Build with Existing Primitives

**Decision: Do NOT adopt an admin framework (Refine, React-Admin, shadcn-admin-kit).**

**Rationale:**

*Refine* (@refinedev/core 5.0.11): Refine is powerful when you need to wire up multiple data providers, auto-generate CRUD routes, and manage ACL at scale. The admin tool here has 4 content types, 1-3 users, and already has TanStack Query doing data fetching. Refine's abstraction layer (dataProvider, routerProvider, authProvider) would add configuration overhead for zero benefit. It is also primarily tested with Vite — the Next.js App Router integration requires extra bridging.

*React-Admin* (react-admin 5.14.4): React-Admin runs as an SPA with react-router. It explicitly does not support Next.js SSR — the official docs say to disable SSR for the `/admin` route. This works but means the admin app cannot use Server Components or Server Actions, which the rest of the monorepo's Next.js apps use heavily. Using `"use client"` for the entire admin app is a sharp regression from the established monorepo patterns.

*shadcn-admin-kit* (marmelab): This is a component kit built on top of React-Admin. It inherits the same SPA/react-router constraint. Not yet stable for production at the time of research.

**What to build instead:**
A purpose-built Next.js App Router admin following the monorepo's established patterns:
- Layouts: shadcn `Sidebar` + `Header` (already in `packages/ui` or copied from shadcn blocks)
- Routing: Next.js App Router file-system routing (`app/vocabulary/page.tsx`, etc.)
- Data fetching: TanStack Query mutations + Server Actions for mutations
- Auth: `@supabase/ssr` middleware (already used in `apps/web`)
- CRUD: TanStack Table for lists + React Hook Form for edit/create forms

This approach adds zero new abstractions, uses patterns the codebase already follows, and can be built in less time than learning and configuring a framework.

---

### Monorepo Integration: Turborepo Standard `apps/admin`

**Why a new app in `apps/` (not a route in `apps/web`):**
PROJECT.md explicitly requires `apps/admin` as a separate Next.js app. This gives independent deployment on Vercel, separate environment variables (admin Supabase service role key never leaks to the main app), and no bundle size impact on the main user-facing app.

**Workspace setup:**
`apps/admin/package.json` references shared monorepo packages:

```json
{
  "name": "@harukoto/admin",
  "dependencies": {
    "@harukoto/database": "workspace:*",
    "@harukoto/types": "workspace:*",
    "@harukoto/ui": "workspace:*",
    "next": "16.1.6",
    "next-intl": "^4.8.3",
    "@tanstack/react-table": "^8.21.3",
    "@tanstack/react-query": "^5.90.21",
    "react-hook-form": "^7.72.0",
    "zod": "^3.25.76",
    "@supabase/supabase-js": "^2.98.0",
    "@supabase/ssr": "^0.8.0"
  },
  "devDependencies": {
    "@harukoto/config": "workspace:*",
    "typescript": "^5.8.0"
  }
}
```

**turbo.json:** No changes needed — existing `build`, `dev`, `lint` pipeline tasks apply to all `apps/*` automatically.

**Vercel:** Add a new Vercel project pointing to `apps/admin` with `rootDirectory: apps/admin`. Set the admin-specific env vars there separately from the main app.

---

## Full Installation

```bash
# From monorepo root — add to apps/admin
cd apps/admin
pnpm add next-intl @tanstack/react-table

# @tanstack/react-query, react-hook-form, zod, @supabase/supabase-js, @supabase/ssr
# are already present in the monorepo — add to apps/admin/package.json as workspace deps
```

---

## Alternatives Considered and Rejected

| Category | Recommended | Alternative | Why Rejected |
|----------|-------------|-------------|--------------|
| i18n | next-intl (without routing) | next-i18next | Pages Router heritage, retrofitted App Router support |
| i18n | next-intl (without routing) | react-i18next standalone | Less Next.js integration, no Server Component support |
| i18n | next-intl (without routing) | URL-based routing mode | Wrong UX for preference-driven internal tool |
| Data table | TanStack Table + shadcn pattern | AG Grid Community | 400KB+, spreadsheet UX mismatch, breaks shadcn consistency |
| Data table | TanStack Table + shadcn pattern | react-data-grid | No shadcn integration, different design language |
| Form builder | RHF + Zod (existing) | react-jsonschema-form | Inflexible for custom TTS field interactions |
| Admin framework | None (custom build) | Refine | Overkill abstraction for 4 CRUD types, Next.js App Router friction |
| Admin framework | None (custom build) | React-Admin | Incompatible with SSR/Server Components, requires disabling SSR entirely |
| Admin framework | None (custom build) | shadcn-admin-kit | Built on React-Admin, same SPA constraint |

---

## Confidence Assessment

| Area | Confidence | Basis |
|------|------------|-------|
| next-intl version (4.8.3) | HIGH | npm registry verified 2026-03-26 |
| next-intl "without routing" mode | HIGH | Official docs confirm the pattern; multiple community confirmations |
| TanStack Table v8 (8.21.3) | HIGH | npm registry verified 2026-03-26 |
| shadcn data-table pattern | HIGH | Official shadcn/ui docs; widely adopted in 2025-2026 ecosystem |
| React Hook Form + Zod reuse | HIGH | Already pinned and running in apps/web |
| Rejecting admin frameworks | MEDIUM | Architectural judgment based on scale (1-3 users, 4 CRUD types); React-Admin SSR incompatibility is verified (official docs), Refine App Router friction is MEDIUM confidence (community reports, not official statement) |
| Turborepo workspace integration | HIGH | Official Turborepo docs + established pattern in this repo |

---

## Sources

- [next-intl official docs — App Router without i18n routing](https://next-intl.dev/docs/getting-started/app-router/without-i18n-routing)
- [next-intl 4.0 release notes](https://next-intl.dev/blog/next-intl-4-0)
- [TanStack Table v8 — npm](https://www.npmjs.com/package/@tanstack/react-table)
- [shadcn/ui Data Table docs](https://ui.shadcn.com/docs/components/radix/data-table)
- [shadcn/ui React Hook Form docs](https://ui.shadcn.com/docs/forms/react-hook-form)
- [React-Admin Next.js integration — official docs](https://marmelab.com/react-admin/NextJs.html) (confirms SSR must be disabled)
- [shadcn-admin-kit — marmelab](https://marmelab.com/shadcn-admin-kit/)
- [Turborepo Next.js guide](https://turborepo.dev/docs/guides/frameworks/nextjs)
- [next-intl 2026 guide — intlpull.com](https://intlpull.com/blog/next-intl-complete-guide-2026)

---

*Stack research: 2026-03-26*
