# Milestones

## v1.1 Quality & Polish (Shipped: 2026-04-23)

**Phases completed:** 3 phases, 6 plans, 10 tasks

**Key accomplishments:**

- Alembic migration adds field column to tts_audio with 4-col UniqueConstraint; API returns per-field audio map and does field-scoped regeneration
- Per-field audio state in TtsPlayer using audios map from backend, grammar example_sentences field, and mixed-state Vitest coverage
- One-liner:
- All 12 admin .tsx files purged of hardcoded CJK strings — column headers, toast messages, Zod errors, placeholders, aria-labels, and relative time now all use useTranslations() calls
- One-liner:
- One-liner:

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
