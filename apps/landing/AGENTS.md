# AGENTS.md

## Scope

Instructions in this file apply to `apps/landing/**`.

## Landing Defaults

- This is a Next.js App Router marketing surface. Keep it lightweight and fast.
- Prefer Server Components by default. Add `"use client"` only when interaction requires it.
- Keep the UI intentional and polished, but do not introduce heavy client-side state or app-only dependencies unless required.
- Keep landing concerns separate from authenticated app concerns unless the task explicitly requires a shared flow.
- Maintain semantic HTML, accessibility, and mobile-first responsive behavior.
- Prefer `next/image` for image rendering unless there is a clear reason not to.

## Validation

- `pnpm --filter landing lint`
- `pnpm --filter landing build`

## Change Risk

- Watch bundle size, hydration cost, SEO metadata, and analytics behavior when changing landing pages.
