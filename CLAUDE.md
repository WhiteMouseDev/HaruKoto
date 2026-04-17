# CLAUDE.md

@AGENTS.md
@.claude/rules/workflow.md
@.claude/rules/quality.md
@.claude/rules/security.md

## Purpose

- This file is a thin Claude Code index. Keep durable repo rules in `AGENTS.md` and durable product/domain knowledge in `docs/`.
- Use `.claude/rules/web.md`, `.claude/rules/api.md`, and `.claude/rules/mobile.md` only when working in those surfaces.
- Slash commands live in `.claude/commands/*.md`.

## Repo Map

- `apps/admin`: internal reviewer/admin Next.js app
- `apps/web`: learner-facing Next.js app
- `apps/landing`: marketing site
- `apps/api`: FastAPI backend
- `apps/mobile`: Flutter client
- `packages/ai`, `packages/database`, `packages/types`, `packages/config`: shared workspace packages

## Planning

- Feature plans and implementation notes: `docs/operations/plans/`
- GSD roadmap, milestones, and phase state: `.planning/`
- Product context and architecture index: `docs/README.md`

## Working Norms

- Prefer reading nearby code, tests, and local AGENTS files before proposing changes.
- Keep this file short. If a rule needs long explanation, move it into `AGENTS.md`, `docs/`, or `.claude/rules/*.md`.
