# AGENTS.md

## Scope

Instructions in this file apply to `apps/admin/**`.

## Admin Defaults

- This app uses Next.js App Router with strict TypeScript and `next-intl`.
- Prefer Server Components by default. Add `"use client"` only for interactivity, browser APIs, or client state.
- Use `proxy.ts`, not `middleware.ts`.
- Treat `params` and `searchParams` as async values and await them.
- Treat `cookies()`, `headers()`, and `draftMode()` as async APIs.
- Keep reviewer workflows keyboard-accessible, mobile-aware, and explicit about loading/error states.
- Reuse shared types and package APIs before creating admin-only copies of domain logic.

## Validation

- `pnpm --filter @harukoto/admin lint`
- `pnpm --filter @harukoto/admin typecheck`
- `pnpm --filter @harukoto/admin test`
- `pnpm --filter @harukoto/admin e2e` when admin routing, auth boundaries, or reviewer-critical UI flows change
- `pnpm --filter @harukoto/admin build` when routes, config, auth boundaries, or shared package contracts change

## Change Risk

- Changes touching auth, reviewer permissions, moderation flows, queue navigation, or API response parsing need explicit regression review.
