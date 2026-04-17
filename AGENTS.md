# AGENTS.md

## Project Identity

HaruKoto is a monorepo for a Japanese learning product for Korean speakers.

- Product context: `docs/product/prd.md`
- Docs index: `docs/README.md`
- Repo overview: `README.md`

## Repository Shape

- `apps/admin`: internal reviewer/admin Next.js app
- `apps/web`: main Next.js learning app
- `apps/landing`: public landing site
- `apps/api`: FastAPI backend
- `apps/mobile`: Flutter mobile app
- `packages/ai`: shared AI provider layer
- `packages/database`: Prisma schema and database access
- `packages/types`: shared TypeScript types
- `packages/config`: shared TS config

## Working Agreements

- Read the nearby code, package manifest, and existing tests before editing.
- Keep changes scoped. Do not fold unrelated cleanup into the same task.
- Match established patterns in the touched area before introducing new abstractions.
- Prefer `pnpm` for JavaScript and TypeScript workspaces.
- Ask before adding production dependencies, changing env contracts, or altering database schema and migration behavior.
- Never commit secrets or copy values from `credentials/`, `.env*`, or external dashboards into the repo.
- Treat auth, billing, AI provider switching, Prisma schema changes, and API contract changes as high-risk work.
- Respect existing uncommitted user changes. Do not revert unrelated edits.

## Validation Defaults

- Run the narrowest useful checks while iterating, then run all affected checks before finishing.
- Root shortcuts:
  - `pnpm lint`
  - `pnpm typecheck` for TypeScript workspaces
  - `pnpm test`
  - `pnpm build`
  - `pnpm format`
- If only one workspace changed, prefer `pnpm --filter <workspace> <script>`.
- Changes in `packages/*` must be validated in at least one direct consumer app.
- If a required tool is unavailable or a check cannot run, call that out explicitly.

## Planning Artifacts

- Use `docs/operations/plans/*.md` for feature design and implementation plans that should stay human-readable in repo docs.
- Use `.planning/` for roadmap, milestone, phase, and GSD state artifacts.
- Avoid introducing ad hoc top-level planning files when one of the two homes above fits.

## Monorepo Guardrails

- Keep shared package APIs small and intentional.
- `packages/types` changes should preserve downstream compatibility unless the task explicitly includes the breaking update.
- `packages/ai` should hide provider-specific details unless the product requires them at the app layer.
- `packages/database` changes must consider generated Prisma client behavior and downstream consumers.
- Web, API, and mobile must stay aligned on response shapes, enum values, and auth assumptions.

## Workspace Coupling

- `apps/web` depends heavily on `packages/types`, `packages/ai`, and `packages/database`.
- `apps/landing` should stay decoupled from product-app internals unless the task explicitly expands that boundary.
- `apps/api` is a contract source for mobile and some web flows. Backend response changes are not local-only edits.
- `apps/mobile` is especially sensitive to auth changes, response key changes, enum drift, and push-notification behavior.

## Cross-Surface Validation Matrix

- If `apps/api` changes request or response contracts, review both `apps/web` and `apps/mobile` consumers.
- If `packages/types` changes, validate every direct TypeScript consumer that imports the touched types.
- If `packages/database` changes, validate Prisma client generation expectations and the downstream `web` and `api` consumers.
- If `packages/ai` changes, validate the calling surface, usually `apps/web` and any backend AI integration in `apps/api`.
- If auth, session, or role logic changes anywhere, validate both `apps/web` and `apps/mobile`.
- If `apps/landing` starts consuming shared product data or APIs, treat that as a cross-app integration change and validate accordingly.

## Collaboration Defaults

- For multi-step or ambiguous work, plan first before editing.
- For review requests, prioritize correctness risks, regressions, and missing validation over style commentary.
- State open assumptions clearly when behavior cannot be verified locally.

## Path-Specific Instructions

- `apps/admin/**`: follow the local `AGENTS.md` for admin app conventions and validation.
- `apps/web/**` and `apps/landing/**`: follow the local `AGENTS.md` for Next.js conventions and validation.
- `apps/api/**`: follow the local `AGENTS.md` for FastAPI and API contract rules.
- `apps/mobile/**`: follow the local `AGENTS.md` for Flutter-specific build and validation rules.
- `packages/**`: follow the local `AGENTS.md` for shared-library constraints.

## Existing Team Context

`CLAUDE.md`, `.claude/rules/*.md`, and `.claude/settings.json` contain prior team guidance. Keep Codex instructions consistent with those documents when extending this setup.
