# Architecture Patterns: HaruKoto Admin App

**Domain:** Internal content management tool within existing Turborepo monorepo
**Researched:** 2026-03-26
**Overall confidence:** HIGH (based on verified codebase analysis + Supabase official docs)

---

## Recommended Architecture

`apps/admin` is a standalone Next.js app inside the existing Turborepo. It shares `packages/database` (Prisma), `packages/ui`, `packages/types`, and `packages/config` with `apps/web`. For data mutations that require TTS regeneration it calls FastAPI directly. For read/write of content data it uses Prisma via `@harukoto/database`. Auth is Supabase with a `reviewer` custom claim embedded in the JWT via a Custom Access Token Hook.

```
Browser (admin reviewer)
        |
        | HTTPS
        v
apps/admin (Next.js 16.1, Vercel)
  ├── Server Components (read: Prisma via @harukoto/database)
  ├── API Routes (auth bridge only — cookie session)
  └── Client Components (TanStack Query, form submit)
        |
        |  Server-side: Prisma DML (content CRUD)
        v
packages/database (@harukoto/database)
        |
        v
Supabase PostgreSQL  ←──────────────────────────────────┐
                                                         |
        |  API Routes forward TTS requests               |
        v                                                |
apps/api (FastAPI, Cloud Run)                            |
  ├── POST /api/v1/admin/tts/regenerate  (new endpoint)  |
  └── existing TTS generation service                    |
        |                                                |
        v                                                |
GCS (harukoto-tts bucket)  ── audio_url written back ───┘
```

---

## Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `apps/admin` Next.js app | Render content management UI; enforce reviewer role gate; CRUD content via Prisma | `packages/database`, `apps/api` (TTS only), Supabase Auth |
| `apps/admin` API Routes | Cookie/session bridge for Supabase Auth; reviewer role verification on server | Supabase Auth (server SDK) |
| `packages/database` | Prisma client + schema; single source of truth for TypeScript DB access | PostgreSQL via PgBouncer |
| `apps/api` (FastAPI) | TTS generation + GCS upload + `tts_audio` cache write; expose new `/admin/tts/regenerate` endpoint | GCS, ElevenLabs, Gemini, PostgreSQL via SQLAlchemy |
| Supabase Auth | JWT issuance; Custom Access Token Hook embeds `reviewer` claim into JWT `app_metadata` | No new service — hook is a Postgres function |

**What admin does NOT do:**
- No new domain business logic in Next.js API Routes (consistent with `api-plane.md` policy)
- No new Alembic migrations for admin features (DDL authority stays in `apps/api/alembic/`)
- No direct SQLAlchemy access from admin (uses Prisma for all DB reads/writes)

---

## Data Flow

### Content Read (Vocabulary, Grammar, Quiz, Scenario)

```
1. Admin page load (Server Component)
2. Prisma query via @harukoto/database
   → SELECT from vocabularies / grammars / quiz_questions / conversation_scenarios
3. Render data table with edit controls
```

Content models `Vocabulary`, `Grammar`, `QuizQuestion`, `ConversationScenario` are all in the Prisma schema. Prisma has DML authority for these tables (seeding + web runtime). Admin CRUD for content fits cleanly inside this boundary — no ORM conflict.

### Content Write (text fields, reading, meaning, etc.)

```
1. Admin submits edit form (React Hook Form + Zod)
2. Server Action or API Route handler (server-side, reviewer-gated)
3. Prisma UPDATE via @harukoto/database
4. Revalidate cached page
```

DML via Prisma is correct here. SQLAlchemy does not own content table writes for the web plane.

### TTS Audio Play + Regenerate

```
Play:
1. Admin clicks "play" on vocab/kana row
2. Client reads audio_url from tts_audio table (fetched with content data)
3. Browser plays GCS URL directly (no API call needed for cache hit)

Regenerate (force refresh):
1. Admin clicks "regenerate TTS"
2. Server Action calls FastAPI:
   POST https://api.harukoto.com/api/v1/admin/tts/regenerate
   { "target_type": "vocabulary", "target_id": "uuid", "force": true }
   Authorization: Bearer <service-to-service token or reviewer JWT>
3. FastAPI deletes existing tts_audio record, runs generate_tts(), uploads to GCS
4. FastAPI returns new audio_url
5. Admin UI updates display
```

Rationale for calling FastAPI for TTS: TTS generation logic (ElevenLabs/Gemini fallback, GCS upload, `tts_audio` cache write) lives entirely in `apps/api`. Duplicating it in Next.js creates two maintenance paths and violates the `api-plane.md` "no new domain logic in BFF" policy.

### Authentication + Role Check

```
Login:
1. Admin user visits apps/admin → Supabase Auth (Google OAuth)
2. Custom Access Token Hook fires on token issue
3. Hook reads user_roles table (Postgres function)
4. Embeds { "reviewer": true } into JWT app_metadata
5. JWT stored in browser cookie via @supabase/ssr

Request guard:
1. Every admin page/action: server-side requireReviewer()
2. Reads supabase.auth.getUser() → checks user.app_metadata.reviewer === true
3. Rejects with 403 if claim absent
```

---

## Reviewer Role: Implementation Pattern

**Mechanism:** Supabase Custom Access Token Hook (official, HIGH confidence)

The `User` model in `apps/api/app/models/user.py` has no `role` column today. There are two valid approaches:

### Option A — app_metadata via Admin API (simpler, fewer moving parts)

Set `reviewer: true` in `app_metadata` manually using the Supabase service-role client. No new DB table needed for 1-3 users.

```typescript
// One-time setup script or Supabase Dashboard
await supabaseAdmin.auth.admin.updateUserById(userId, {
  app_metadata: { reviewer: true }
})
```

The claim is automatically included in the JWT. On the server, read it as:

```typescript
const user = await supabase.auth.getUser()
const isReviewer = user.data.user?.app_metadata?.reviewer === true
```

**Verdict: Use this for 1-3 users.** No database migration, no hook needed, manageable via Supabase Dashboard.

### Option B — Custom Access Token Hook + user_roles table (scalable, more setup)

Create a `user_roles` Postgres table and a hook function that queries it on every token issue. Appropriate if reviewer list will grow or role enforcement needs to be policy-level.

Given the constraint "1-3 users, no over-engineering," Option A is the right choice for this milestone.

**FastAPI: no change needed for auth.** The existing `get_current_user` dependency validates JWT and fetches the user from the `users` table. For the new admin TTS endpoint, add a `require_reviewer` dependency that additionally checks `payload.get("app_metadata", {}).get("reviewer")`.

---

## Prisma + SQLAlchemy Hybrid: Admin Interaction Model

The dual-ORM situation is documented but the admin boundary is clean:

| Operation | ORM to Use | Reason |
|-----------|-----------|--------|
| Read Vocabulary / Grammar / Quiz / Scenario | Prisma | These tables are in Prisma schema; DML ownership is web plane |
| Update content text fields | Prisma UPDATE | Same ownership boundary |
| Read tts_audio (audio_url for playback) | Prisma (tts_audio IS in Prisma schema as `tts_audio` model) | Confirmed in schema.prisma line 700 |
| Insert/update tts_audio after regeneration | FastAPI (SQLAlchemy) | TTS service owns this write; existing pattern in `tts.py` and `kana_tts.py` |
| DDL changes (new columns for review status, etc.) | Alembic ONLY, then `pnpm db:sync` | DDL authority policy |

**No ORM conflict** as long as admin does not write `tts_audio` directly. The regenerate flow delegates write-back to FastAPI, matching existing TTS service ownership.

---

## New FastAPI Endpoint Required

The existing `POST /api/v1/vocab/tts` is user-facing with rate limits per user. Admin needs a separate endpoint:

```
POST /api/v1/admin/tts/regenerate
```

Differences from user TTS endpoint:
- Authenticated by reviewer JWT claim (not regular user)
- `force: true` — deletes existing `tts_audio` record before regenerating
- No per-user rate limit (or a separate admin-scoped limit)
- Supports both `target_type: "vocabulary"` and `target_type: "kana"`

This endpoint must be added to `apps/api` before admin UI TTS regeneration can function.

---

## Monorepo Integration

`apps/admin` is a standard Turborepo app node. No special configuration needed beyond:

```json
// apps/admin/package.json dependencies
{
  "@harukoto/database": "workspace:*",
  "@harukoto/ui": "workspace:*",
  "@harukoto/types": "workspace:*",
  "@harukoto/config": "workspace:*"
}
```

`turbo.json` task pipeline requires no changes (build/dev/lint tasks are inherited).

Vercel deployment: add `apps/admin` as a second project in the same Vercel team, pointing to the monorepo root with `apps/admin` as the root directory.

CORS: add the admin Vercel URL to `CORS_ORIGINS` in the FastAPI Cloud Run environment.

---

## Suggested Build Order

Dependencies between components determine the order. Build bottom-up:

### Phase 1 — Auth Foundation (no UI yet)
1. Set reviewer `app_metadata` on test account via Supabase Admin API
2. Create `apps/admin` Next.js app scaffold (Turborepo package, shared configs)
3. Implement `requireReviewer()` server-side auth guard using `app_metadata.reviewer`
4. Stub login page + redirect gate

Dependency rationale: everything else gates on auth being correct. Getting this wrong means silently exposing admin to non-reviewers.

### Phase 2 — Content Read (Vocabulary + Grammar)
1. Implement vocabulary list page (Server Component, Prisma read)
2. Implement grammar list page
3. Inline edit form (React Hook Form + Zod + Prisma UPDATE)

Dependency rationale: read before write; vocabulary and grammar share the same list+edit pattern, implement one and replicate.

### Phase 3 — TTS Playback + Regenerate
1. Add FastAPI `POST /api/v1/admin/tts/regenerate` endpoint with reviewer auth
2. Admin UI: audio player component reading existing `audio_url`
3. Admin UI: regenerate button calling FastAPI via Server Action / fetch

Dependency rationale: FastAPI endpoint must exist before the UI button works. Audio playback (GCS URL) works independently of regeneration.

### Phase 4 — Quiz + Scenario Data
1. Quiz question list + edit
2. Conversation scenario list + edit

Dependency rationale: same CRUD pattern as Phase 2, lower risk, deferred until core content editing is validated.

### Phase 5 — i18n (한/日/English)
1. Add `next-intl` or `react-i18next`
2. Translate UI strings for all three languages

Dependency rationale: purely UI layer, no data model changes, safe to defer until core workflows are stable.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Reimplementing TTS in Next.js API Route
**What:** Copy ElevenLabs/Gemini generation + GCS upload into an admin API route
**Why bad:** Two independent implementations drift; GCS credentials duplicated; `tts_audio` cache table owned by SQLAlchemy writes becomes split-brained
**Instead:** Proxy TTS regeneration to the existing FastAPI endpoint

### Anti-Pattern 2: Granting Admin Direct Database Service Role for All Writes
**What:** Use `SUPABASE_SERVICE_ROLE_KEY` in admin to bypass RLS and write directly
**Why bad:** Bypasses all row-level policies; any bug in admin can corrupt any table; violates least privilege
**Instead:** Admin uses Prisma with `DATABASE_URL` (PgBouncer) and scoped Alembic-governed schema. Service role is only used for `auth.admin.updateUserById()` during reviewer provisioning.

### Anti-Pattern 3: Adding Domain Logic to Admin BFF API Routes
**What:** Build vocabulary validation, TTS retry logic, etc. in `apps/admin/src/app/api/`
**Why bad:** Violates `api-plane.md` policy; duplicates logic that lives (or should live) in FastAPI
**Instead:** Admin API routes are only for auth cookie bridge (`/api/auth/*`) and any Vercel-environment-specific needs

### Anti-Pattern 4: Separate Auth System for Admin
**What:** Implement a separate username/password or magic-link system for the admin
**Why bad:** Adds another credential store, another session mechanism, another attack surface
**Instead:** Reuse Supabase Auth with reviewer `app_metadata` claim. Same token, same JWKS verification path.

---

## Scalability Considerations

The 1-3 users constraint means scalability is not a concern for this milestone. The architecture is correct at any scale because it uses the same infrastructure the main app already runs. No special considerations needed.

---

## Sources

- [Supabase Custom Access Token Hook](https://supabase.com/docs/guides/auth/auth-hooks/custom-access-token-hook) — HIGH confidence (official docs)
- [Supabase Custom Claims and RBAC](https://supabase.com/docs/guides/database/postgres/custom-claims-and-role-based-access-control-rbac) — HIGH confidence (official docs)
- [Supabase JWT Claims Reference](https://supabase.com/docs/guides/auth/jwt-fields) — HIGH confidence (official docs)
- Codebase analysis: `apps/api/app/dependencies.py`, `apps/api/app/routers/tts.py`, `apps/api/app/models/user.py`, `packages/database/prisma/schema.prisma`, `.claude/rules/api-plane.md` — HIGH confidence (direct source)

---

*Architecture analysis: 2026-03-26*
