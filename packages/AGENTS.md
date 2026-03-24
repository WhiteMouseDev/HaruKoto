# AGENTS.md

## Scope

Instructions in this file apply to `packages/**`.

## Shared Package Defaults

- Shared packages are high leverage. Keep APIs small, explicit, and stable.
- Avoid importing app-specific UI, routing, or runtime assumptions into shared packages.
- Update exports intentionally so downstream consumers do not rely on deep internal paths.
- For `packages/database`, do not run schema-changing commands such as `db:push` or `db:migrate` without explicit approval.
- For `packages/types`, `packages/ai`, and `packages/database`, validate at least one direct consumer after the package check passes.
- Treat a package change as incomplete until the affected app surfaces have been checked as well.

## Consumer Map

- `packages/types`: usually consumed by `apps/web` and other TypeScript workspaces.
- `packages/ai`: primarily consumed by `apps/web`, and may also affect backend AI integrations.
- `packages/database`: affects Prisma generation plus any web or API code that reads or writes data.

## Validation

- `pnpm --filter @harukoto/types lint`
- `pnpm --filter @harukoto/ai lint`
- `pnpm --filter @harukoto/database lint`
- Run the relevant app checks for each affected consumer

## Change Risk

- Treat package API changes, Prisma schema updates, and provider contract changes as cross-repo changes, not local edits.
