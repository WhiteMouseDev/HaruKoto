# Milestones

## v1.1 Quality & Polish (Shipped: 2026-04-23)

**Phases completed:** 3 phases (6-8), 6 plans, 10 tasks
**Timeline:** 2026-03-31 → 2026-04-02 (execution); 2026-04-23 archived after re-audit
**Git scope:** 34 files, +823/-267 across apps/admin + apps/api

**Key accomplishments:**

- **Per-field TTS storage** — Alembic migration adds `field` column to tts_audio with 4-col UniqueConstraint; API returns per-field audio map and does field-scoped regeneration (Phase 6-01)
- **Per-field TTS UI** — TtsPlayer renders independent state per field using backend map, grammar `example_sentences` field support, mixed-state Vitest coverage (Phase 6-02)
- **i18n locale coverage** — 173 keys per language across 3 locale files (ko/ja/en), locale-key-parity test + hardcoded-strings scanner to block regressions (Phase 7-01)
- **CJK hardcoding purge** — All 12 admin .tsx files converted from inline Japanese to `useTranslations()` calls (column headers, toasts, Zod errors, placeholders, aria-labels, relative time) (Phase 7-02)
- **Accessibility boost** — aria-current on sidebar, skip link, landmark aria-labels, search input explicit label (Phase 7-03)
- **Hook i18n gap closure** — useTtsPlayer ported to `useTranslations('tts')`; hardcoded-strings test scope extended to `.ts` (Phase 8-01)

**Post-milestone hardening (2026-04-23):**
- admin↔api consistency audit: 8 drifts closed (Quiz audit-logs routing, ScenarioCategory enum, reviewerEmail, list updatedAt, stats cache key, JLPT filter, audit action mapping, TTS error detail surfacing)
- `validate_admin_contracts.py` added and wired into CI
- P0-2 voice feedback silent-fail classified + structured logging (observability hardening)

---

## v1.0 HaruKoto Admin MVP (Shipped: 2026-03-30)

**Phases completed:** 10 phases, 22 plans, 21 tasks

**Key accomplishments:**

- One-liner:
- One-liner:
- Next-intl cookie-based locale switching with ja/ko/en support, admin shell header (logo/user/logout), and dashboard stub with 4 content-type placeholder cards
- Monorepo-aware Vercel deployment of apps/admin with pnpm + Turborepo, rootDirectory=apps/admin, and Supabase env vars — live at https://harukoto-admin.vercel.app
- One-liner:
- 1. [Rule 1 - Bug] Fixed pre-existing ESLint error in global.d.ts
- One-liner:
- 1. [Rule 3 - Blocking] Manual Alembic migration instead of autogenerate
- One-liner:
- One-liner:
- One-liner:
- 1. [Rule 1 - Bug] Fixed setState-in-effect lint error in useTtsPlayer
- One-liner:
- One-liner:
- One-liner:
- One-liner:
- Quiz list endpoint rewrite:
- One-liner:
- Sortable column headers with URL-synced sort state on all 4 content tables, plus quiz detail links fixed to include quiz type param

---
