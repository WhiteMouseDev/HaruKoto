# Project Research Summary

**Project:** HaruKoto Admin — 학습 데이터 관리 도구 (Learning Data Review Tool)
**Domain:** Internal content management admin for language learning data (vocabulary, grammar, quizzes, conversation scenarios)
**Researched:** 2026-03-26
**Confidence:** HIGH

## Executive Summary

HaruKoto Admin is a purpose-built internal CRUD tool for 1-3 non-developer Japanese native reviewers plus one Korean developer. The recommended approach is to build `apps/admin` as a standalone Next.js 16.1 app inside the existing Turborepo monorepo — sharing packages but deployed independently — rather than adopting any admin framework (Refine, React-Admin). All existing monorepo primitives (shadcn/ui, TanStack Query, React Hook Form + Zod, Supabase Auth) compose into the full feature set without a single new heavy dependency. The only new libraries needed are `next-intl` for 3-language i18n and `@tanstack/react-table` for data tables.

The core architecture is straightforward: Server Components read content via Prisma (`@harukoto/database`), mutations go through Server Actions or API Route handlers guarded by a `reviewer` role claim embedded in the Supabase JWT, and all TTS operations are proxied to FastAPI's existing TTS service. The dual ORM situation (Prisma for content tables, SQLAlchemy/Alembic for DDL authority) is the single most important constraint to respect — admin must use explicit PATCH semantics with named fields only, never full model updates, and every Alembic migration must be followed by `prisma db pull`.

The biggest risks are not architectural but operational: TTS regeneration can generate runaway ElevenLabs charges without a per-item cooldown guard, the Vercel standalone build breaks silently if `outputFileTracingRoot` is not configured, and Japanese reviewers will be blocked by untranslated UI strings if `ja.json` is not established as the TypeScript type source from day one. All three of these risks are preventable with specific, concrete actions in Phase 1 before any feature work begins.

---

## Key Findings

### Recommended Stack

The admin app reuses the full existing monorepo stack with only two net-new package additions. React-Admin and Refine were evaluated and rejected — React-Admin requires disabling SSR entirely, and Refine adds abstraction overhead for an app with 4 CRUD types and 1-3 users. The right call is a custom build with existing primitives: less code to write, zero new abstractions to learn, and patterns the codebase already follows.

The one genuinely new setup is `next-intl` in "without routing" mode — locale stored in a cookie, no `[locale]/` URL segments, flat `app/` directory. This is the correct pattern for a preference-driven internal tool where Japanese native speakers are the primary users.

**Core technologies:**
- `next-intl ^4.8.3` (without routing mode): 3-language i18n (ja/ko/en) — only new library needed; cookie-based locale, Server Component support
- `@tanstack/react-table ^8.21.3` + shadcn data-table pattern: sortable/filterable/paginated data tables — headless, 15KB, design-system consistent
- `React Hook Form + Zod` (already pinned): edit/create forms — reused as-is from `apps/web`
- `@supabase/ssr + app_metadata reviewer claim`: auth + role gate — simpler than Custom Access Token Hook for 1-3 users, no new DB table
- `packages/database` (Prisma): content reads and CRUD writes — established DML boundary
- `apps/api` (FastAPI): TTS regeneration proxy only — keeps TTS logic in one place

### Expected Features

The feature dependency graph is clear: list views are foundational; status workflow requires edit forms; TTS regeneration requires status workflow to be meaningful; productivity features (bulk ops, review queue) layer on top of a working status workflow.

**Must have (table stakes):**
- Data list views (Vocabulary, Grammar, Quiz, Scenario) with search, filter by status, sort, pagination
- Status workflow: `needs_review` / `approved` / `rejected` with comment on reject
- Full edit form per content type (React Hook Form + Zod + Prisma UPDATE)
- TTS audio playback (HTML `<audio>` against GCS pre-signed URL)
- TTS single-item regeneration (via new FastAPI `/api/v1/admin/tts/regenerate` endpoint)
- Reviewer role gate on all routes (Supabase `app_metadata.reviewer`)
- Multilingual UI: Japanese primary, Korean secondary, English fallback
- Toast feedback on save + unsaved-changes guard

**Should have (productivity differentiators):**
- Review queue with next/prev navigation and keyboard shortcuts (`a` approve, `r` reject, `→`/`←`)
- Bulk status change: checkbox multi-select + floating action bar
- Review comment/annotation on reject (stored as `review_note` column)
- Content-type dashboard summary (status counts per content type)
- Change history / audit log (last 5 changes per item)
- Audio waveform missing/present badge (not a real waveform — just a status indicator)

**Defer to later milestone:**
- TTS batch regeneration (entire filtered set) — high complexity, job queue awareness required
- Keyboard shortcut help overlay (`?` key) — polish item
- CSV/Excel import — explicitly out of scope per PROJECT.md
- User/account management — main app concern
- Real-time collaborative editing — overkill for 1-3 users
- AI-assisted content suggestions — separate milestone

### Architecture Approach

`apps/admin` is a standard Turborepo app node that shares `@harukoto/database`, `@harukoto/ui`, `@harukoto/types`, and `@harukoto/config`. Server Components handle content reads via Prisma. Client Components handle TanStack Query mutations and form submission. A thin API Routes layer is used only for the Supabase Auth cookie bridge. TTS regeneration is the only cross-service call — it goes from a Next.js Server Action to FastAPI's new admin endpoint, which then writes back to GCS and PostgreSQL. The admin app never writes `tts_audio` rows directly.

**Major components:**
1. `apps/admin` Next.js app — renders content management UI, enforces reviewer role gate, executes content CRUD via Prisma
2. `packages/database` (Prisma) — single source of truth for TypeScript DB access; DML authority for content tables
3. `apps/api` FastAPI — new `POST /api/v1/admin/tts/regenerate` endpoint; TTS generation logic stays in one place
4. Supabase Auth — reviewer role via `app_metadata.reviewer` set by service-role Admin API (no Custom Access Token Hook needed at 1-3 user scale)
5. GCS `harukoto-tts` bucket — audio file storage; needs CORS configured for admin origin before audio preview works

**What admin does NOT do:**
- No new domain business logic in Next.js API Routes
- No DDL via Prisma — all new columns/tables go through Alembic first, then `prisma db pull`
- No direct `tts_audio` table writes from Next.js
- No Supabase service role key for general content writes — only for reviewer provisioning

### Critical Pitfalls

1. **Dual ORM partial save corrupts Alembic-managed columns** — every admin API route must use explicit PATCH with named fields only; never pass the full model to `prisma.update()`; run `prisma db pull` after every Alembic migration; add CI diff check. Address in Phase 1 before any write route is built.

2. **Missing `outputFileTracingRoot` breaks Vercel standalone build silently** — add `outputFileTracingRoot: path.join(__dirname, '../../')` to `apps/admin/next.config.ts` before first deploy; verify with `turbo build --filter=admin` locally. Address in Phase 1 scaffold.

3. **TTS regeneration without per-item cooldown = runaway ElevenLabs charges** — add `last_regenerated_at` column (Alembic) with a 10-minute cooldown server-side check; require a confirmation dialog in the UI; show existing audio preview before offering regenerate. Address in Phase 2 before building the regenerate button.

4. **FastAPI TTS endpoint missing role check = any authenticated user can trigger regeneration** — create a dedicated `POST /api/v1/admin/tts/regenerate` endpoint with a `require_admin_role` FastAPI dependency that does a live DB lookup (JWT claim alone is insufficient). Address in Phase 1 (auth) and Phase 2 (endpoint).

5. **Japanese locale keys missing from day one = Japanese reviewers see raw key strings** — set `ja.json` as the `next-intl` TypeScript type source; add CI script to diff locale files; establish all three locale files at project init. Address in Phase 1 before building any screen.

---

## Implications for Roadmap

Based on combined research, the correct phase structure is bottom-up: security and deployment infrastructure before content reads, content reads before writes, writes before workflow features, workflow before productivity features. The dependency graph from FEATURES.md and the phase warnings from PITFALLS.md converge on the same ordering.

### Phase 1: Foundation — Scaffold, Auth, and Deployment

**Rationale:** Every other phase depends on correct auth, a deployable app, and a working monorepo integration. Getting auth wrong means silently exposing admin to non-reviewers. Getting the Vercel config wrong means features that work locally fail in production. Getting i18n setup wrong means Japanese reviewers are blocked from day one.

**Delivers:**
- `apps/admin` Turborepo package scaffolded (package.json, tsconfig, next.config.ts with `outputFileTracingRoot`, turbo task inheritance)
- Supabase Auth login page + `requireReviewer()` server-side guard using `app_metadata.reviewer`
- Reviewer role provisioned on test account via Supabase Admin API (no migration needed)
- `next-intl` installed with `ja.json`, `ko.json`, `en.json` — TypeScript strict mode with `ja` as type source; CI key-diff check
- Green Vercel deploy (shell only, no content pages yet)
- Schema sync rule documented: Alembic → `prisma db pull` → PR required

**Avoids:** Pitfalls 2 (stale JWT — two-layer check established), 4 (outputFileTracingRoot), 5 (shared Prisma client version conflicts), 6 (i18n translation drift), 10 (pnpm workspace misuse), 11 (admin URL exposure)

### Phase 2: Content List Views (Read-Only)

**Rationale:** Read before write. Vocabulary and Grammar list views share identical patterns (TanStack Table + Server Component Prisma read). Implementing one and replicating to Grammar, Quiz, Scenario reduces risk. Search, filter by JLPT level, and sort are non-negotiable table-stakes features — build them here, not later.

**Delivers:**
- Vocabulary, Grammar, Quiz, ConversationScenario list pages (Server Component, Prisma read)
- TanStack Table with sort, search, filter by status and JLPT level, pagination (server-side)
- TTS audio badge (has audio / missing / text-changed-since-generation) in list rows
- Content-type dashboard summary (status counts per type)

**Uses:** `@tanstack/react-table` + shadcn data-table pattern; `@harukoto/database` Prisma reads

**Avoids:** Pitfall 9 (non-technical users cannot find records — JLPT filter as required first navigation)

### Phase 3: Content Editing and Status Workflow

**Rationale:** Full edit forms per content type are the core value delivery. Status workflow (`needs_review` / `approved` / `rejected`) is what makes the tool produce output. These belong together because the review comment field and status transition are part of the same UX action.

**Delivers:**
- Full edit forms: VocabularyForm, GrammarForm, QuizQuestionForm, ConversationScenarioForm (React Hook Form + Zod + Prisma PATCH with explicit field list)
- Alembic migration: add `review_status` enum, `reviewed_at`, `reviewer_id`, `review_note` columns to content tables
- `prisma db pull` after migration as part of same PR
- Status workflow UI: approve/reject buttons, comment textarea on reject
- Toast feedback (sonner) + unsaved-changes guard (`beforeunload`)
- Inline edit for short text fields (reading, meaning) with optimistic update

**Avoids:** Pitfall 1 (dual ORM partial save — explicit PATCH fields only; never full model update)

### Phase 4: TTS Audio Playback and Regeneration

**Rationale:** TTS features require the content editing phase to be stable first — edit-then-regenerate order enforcement means text fields must exist and be saveable before the regenerate button appears. The new FastAPI endpoint must be built before the admin UI button.

**Delivers:**
- `POST /api/v1/admin/tts/regenerate` FastAPI endpoint with `require_admin_role` dependency (live DB role lookup, not just JWT claim)
- Admin UI: `<audio>` player reading `tts_audio.audio_url` from Prisma (no API call for cache hits)
- Admin UI: Regenerate button behind confirmation dialog; spinner during generation; audio replaced on success
- `last_regenerated_at` Alembic migration + 10-minute cooldown server-side check
- GCS CORS configuration for admin origin verified/updated
- Edit-then-regenerate workflow: "Save text changes before regenerating" banner when `tts_audio.text` differs from current `vocabulary.reading`

**Avoids:** Pitfall 3 (runaway ElevenLabs charges), Pitfall 7 (FastAPI TTS endpoint missing role check), Pitfall 8 (text/audio mismatch from wrong operation order), Pitfall 12 (GCS CORS blocks audio playback)

### Phase 5: Productivity and Reviewer Workflow

**Rationale:** Status workflow must be working and validated with real reviewers before building productivity features on top. Review queue navigation is only valuable when reviewers have understood the basic approve/reject loop. Bulk operations are only safe after single-item operations are confirmed correct.

**Delivers:**
- Review queue: next/prev navigation with URL-based state (`?queue=needs_review&index=3`)
- Keyboard shortcuts: `→` next, `←` prev, `a` approve, `r` reject; `?` help overlay
- Bulk status change: checkbox column, floating action bar, confirmation dialog for bulk reject
- Change history / audit log (last 5 changes per item in collapsible panel)

### Phase Ordering Rationale

- Auth and deployment infrastructure cannot be deferred — they block everything else and must be correct before any content is exposed
- Read before write — list views validate data model understanding before mutation code is written
- Content editing before TTS — the edit-then-regenerate workflow dependency requires text fields to be stable before audio regeneration is wired up
- Core workflow before productivity — bulk operations and keyboard shortcuts should be built on a validated single-item workflow to avoid amplifying bugs
- i18n is cross-cutting but configuration-only in Phase 1; actual string translation happens incrementally as each screen is built

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 4 (TTS Regeneration):** FastAPI `require_admin_role` dependency design needs codebase-specific implementation research — the current `dependencies.py` structure and how to add a new dependency without breaking existing routes
- **Phase 3 (Alembic migration):** The exact columns to add to content tables need schema confirmation against current `schema.prisma` and SQLAlchemy models — there may be existing partial fields (e.g., `status`) that conflict

Phases with standard patterns (skip research-phase):
- **Phase 1 (Scaffold + Auth):** next-intl without-routing setup and Supabase `app_metadata` are well-documented with official docs
- **Phase 2 (List Views):** shadcn data-table + TanStack Table pattern is canonical and widely documented
- **Phase 5 (Productivity):** URL-based queue state and bulk selection are established UX patterns with no novel integration challenges

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All choices verified against npm registry and official docs (2026-03-26); only 2 new packages needed |
| Features | HIGH | Core patterns well-established from content management / admin tool domain; TTS workflow extrapolated from adjacent patterns but low uncertainty |
| Architecture | HIGH | Based on direct codebase analysis (`dependencies.py`, `schema.prisma`, `api-plane.md`); Supabase auth patterns verified against official docs |
| Pitfalls | HIGH | Critical pitfalls are concrete and specific; dual ORM risk confirmed by `CONCERNS.md`; Vercel standalone issue confirmed by official Turborepo docs |

**Overall confidence:** HIGH

### Gaps to Address

- **Current schema state of content tables:** Research assumes `review_status`, `review_note`, `reviewer_id` columns do not yet exist. Confirm against actual schema before writing Alembic migration to avoid duplicate column errors.
- **Existing rate limit key pattern for TTS:** The `rate_limit.py` per-user bucket must be verified before building the admin-scoped cooldown — if the existing rate limiter already covers admin TTS by accident, the per-item cooldown is still needed but the interaction must be designed carefully.
- **GCS CORS current config:** Unknown whether the `harukoto-tts` bucket already has any CORS rules. Needs a one-line `gcloud` check before Phase 4 begins to determine if this is a change or a new setup.
- **Vercel project structure:** Unclear if `apps/web` currently uses `output: 'standalone'`. If it does, `outputFileTracingRoot` may already be configured and the admin can follow the same pattern. If not, admin is the first standalone build in the monorepo and needs to be validated carefully.
- **Reviewer provisioning UX:** Option A (`app_metadata` via Admin API) is recommended for 1-3 users, but the exact flow for provisioning new reviewers (Supabase Dashboard vs. a one-time script) should be documented before Phase 1 ships, otherwise the first reviewer cannot be onboarded.

---

## Sources

### Primary (HIGH confidence)
- [next-intl official docs — App Router without i18n routing](https://next-intl.dev/docs/getting-started/app-router/without-i18n-routing)
- [TanStack Table v8 — npm](https://www.npmjs.com/package/@tanstack/react-table)
- [shadcn/ui Data Table docs](https://ui.shadcn.com/docs/components/radix/data-table)
- [Supabase Custom Access Token Hook](https://supabase.com/docs/guides/auth/auth-hooks/custom-access-token-hook)
- [Supabase Custom Claims and RBAC](https://supabase.com/docs/guides/database/postgres/custom-claims-and-role-based-access-control-rbac)
- [React-Admin Next.js integration](https://marmelab.com/react-admin/NextJs.html) — confirms SSR must be disabled
- [Turborepo Next.js guide](https://turborepo.dev/docs/guides/frameworks/nextjs)
- Codebase direct analysis: `apps/api/app/dependencies.py`, `packages/database/prisma/schema.prisma`, `.claude/rules/api-plane.md`, `.planning/codebase/CONCERNS.md`

### Secondary (MEDIUM confidence)
- [PatternFly Bulk Selection pattern](https://www.patternfly.org/patterns/bulk-selection/) — bulk action UX guidance
- [Content Review and Approval Best Practices — zipBoard](https://zipboard.co/blog/collaboration/content-review-and-approval-best-practices-tools-automation/)
- [Data Table UX: 5 Rules of Thumb](https://mannhowie.com/data-table-ux)
- [next-intl 2026 guide — intlpull.com](https://intlpull.com/blog/next-intl-complete-guide-2026)
- [ElevenLabs TTS capabilities](https://elevenlabs.io/docs/overview/capabilities/text-to-speech)

### Tertiary (MEDIUM-LOW confidence)
- Refine App Router friction — community reports, not official statement; recommend verifying if Refine is reconsidered
- TTS per-item cooldown pattern — extrapolated from rate limiting best practices, not an established admin tool pattern

---

*Research completed: 2026-03-26*
*Ready for roadmap: yes*
