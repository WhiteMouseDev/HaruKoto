# AGENTS.md

## Scope

Instructions in this file apply to `apps/web/**`.

## Web Defaults

- This app uses Next.js App Router with strict TypeScript.
- Prefer Server Components by default. Add `"use client"` only when interactivity or browser APIs require it.
- Use `proxy.ts`, not `middleware.ts`.
- Treat `params` and `searchParams` as async values and await them.
- Treat `cookies()`, `headers()`, and `draftMode()` as async APIs.
- Keep components mobile-first, semantic, keyboard-accessible, and screen-reader-friendly.
- Prefer `next/image` for images unless there is a clear reason not to.
- Use TanStack Query for server state, Zustand for client state, and React Hook Form + Zod for forms.
- Reuse shared types and package APIs before creating duplicate local abstractions.

## Validation

- `pnpm --filter web lint`
- `pnpm --filter web test`
- `pnpm --filter web build` when routes, config, server/client boundaries, env usage, or shared package contracts change

## Change Risk

- Changes touching auth, payments, notifications, AI flows, or API response parsing need extra care and explicit regression review.
