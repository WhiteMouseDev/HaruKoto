# CLAUDE.md

@AGENTS.md
@.claude/rules/workflow.md
@.claude/rules/quality.md
@.claude/rules/security.md

## Purpose

- This file is a thin Claude Code index. Keep durable repo rules in `AGENTS.md` and durable product/domain knowledge in `docs/`.
- Domain-specific patterns are now packaged as skills — the relevant domain sub-agent auto-loads its skill at startup:
  - `web-next16` (apps/web · apps/admin · apps/landing) → loaded by `web-agent`
  - `fastapi-patterns` (apps/api) → loaded by `backend-agent`
  - `flutter-riverpod` (apps/mobile) → loaded by `mobile-agent`
  - `api-plane-governance` (DDL authority + BFF routing) → loaded by `backend-agent`, `web-agent`, `shared-packages-agent`
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
- Keep this file short. If a rule needs long explanation, move it into `AGENTS.md`, `docs/`, or `.claude/skills/<skill>/SKILL.md`.
