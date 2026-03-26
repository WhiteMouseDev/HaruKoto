# Domain Pitfalls

**Domain:** Language learning data admin tool (non-technical users, existing monorepo, dual ORM, Supabase Auth RBAC, TTS cost exposure, 3-language i18n)
**Researched:** 2026-03-26
**Project:** HaruKoto Admin (apps/admin)

---

## Critical Pitfalls

Mistakes that cause rewrites, data corruption, or runaway costs.

---

### Pitfall 1: Dual ORM Schema Drift on Admin Writes

**What goes wrong:** The admin tool writes data through Prisma (Next.js API routes), but the same tables are owned/migrated by SQLAlchemy/Alembic. If a new column is added via Alembic but `prisma db pull` is not re-run, Prisma silently ignores the new column. Worse: if the admin PATCH saves a partial model, it can overwrite the SQLAlchemy-managed column with NULL.

**Why it happens:** Alembic owns DDL; Prisma uses introspection (`db pull` + `db sync`). The existing CI schema-drift check (`.github/workflows/ci.yml` line 160+) only catches structural mismatch, not semantic mismatch in mutation payloads. The `CONCERNS.md` flags this as High severity but notes CI only partially mitigates it.

**Consequences:**
- Silent data corruption: columns added by Alembic disappear on next Prisma save
- TTS metadata fields (provider, model, speed in `tts_audio`) are particularly fragile — they are Alembic-managed and not yet in Prisma schema

**Prevention:**
- Make every admin API route a PATCH with explicit field selection (never `update` the full model)
- After any Alembic migration, run `prisma db pull` immediately and treat it as a required PR step
- Add a CI check that runs `prisma db pull --print` and diffs against the committed schema — fail if there is a diff
- For the `tts_audio` table specifically: proxy all TTS-related writes through the existing FastAPI endpoint rather than writing directly from Next.js

**Warning signs:**
- Admin saves a record, and a field that was set via seed/migration becomes NULL
- `prisma db pull` produces a non-empty diff after an Alembic migration

**Phase:** Address in Phase 1 (foundation) — establish the schema sync rule before any write API is built.

---

### Pitfall 2: Stale Role Claims After Reviewer Role Revocation

**What goes wrong:** Supabase JWTs have a default expiry of 1 hour. When a reviewer role is revoked from a user (row deleted from `user_roles` table, custom claim removed), the user's existing JWT still carries the `reviewer` claim until it expires. During that window, the user retains admin access.

**Why it happens:** JWTs are signed at issuance time. The Custom Access Token Hook adds claims at token creation, but those claims are baked into the token. Supabase has no built-in token revocation list. The `CONCERNS.md` notes the current system has no role system at all — the entire role infrastructure must be built from scratch.

**Consequences:**
- Revoked reviewer continues to access admin app for up to 1 hour
- For 1-3 user small team this is low operational risk, but the architectural gap silently persists if the team grows

**Prevention:**
- Implement role check at two layers: JWT claim (fast path) AND a live database lookup on sensitive mutation endpoints (`/api/admin/tts/regenerate`, data PATCH routes)
- For the small 1-3 user team: accept the 1-hour stale window for read endpoints; always do live DB role lookup before any write or TTS trigger
- Document the revocation window explicitly in admin onboarding docs

**Warning signs:**
- Admin revokes a user but that user can still POST to mutation endpoints within the same session
- Middleware only reads `session.user.app_metadata` without verifying the claim against the DB

**Phase:** Address in Phase 1 (auth setup). The dual-layer check must be in place before TTS endpoints are exposed.

---

### Pitfall 3: TTS Regeneration Without Cost Guard = Runaway ElevenLabs Charges

**What goes wrong:** The existing `tts.py` uses an in-memory `_generating` set to prevent duplicate concurrent generation, but this does NOT persist across server restarts (Vercel serverless: cold starts reset all in-process state). A non-technical user who clicks "Regenerate" five times in quick succession — or refreshes the page — can trigger five separate ElevenLabs API calls for the same audio. At ElevenLabs Pro pricing, a single regeneration costs credits proportional to character count. For a full vocabulary corpus (JLPT N5–N1 words), this can be expensive.

**Why it happens:** The existing rate limit is per-user via Redis (`rate_limit.py`), which does work in FastAPI. But the admin TTS endpoint will be a new endpoint — if it reuses the same pattern naively, the rate limit bucket key would need to be per-vocabulary item (not per user), otherwise one reviewer can exhaust another reviewer's bucket. The in-memory deduplication guard (`_generating: set[str]`) does not survive across Vercel function instances.

**Consequences:**
- ElevenLabs charges for every duplicate regeneration request
- No audit trail to know who regenerated what and when

**Prevention:**
- Add a per-vocabulary-item regeneration cooldown persisted in the database: a `last_regenerated_at` column on `tts_audio` — reject requests where `last_regenerated_at > now() - interval '10 minutes'`
- Require explicit confirmation dialog in the UI before triggering regeneration ("This will call ElevenLabs and use credits. Are you sure?")
- Display current cached audio in the admin UI with a "Preview" button that plays the existing audio BEFORE offering a "Regenerate" button — so users do not regenerate audio that is already correct
- Add an audit log table: `tts_regeneration_log(id, item_type, item_id, triggered_by, triggered_at, provider, status)`
- Block regeneration behind `reviewer` role on both the Next.js API route AND the FastAPI endpoint

**Warning signs:**
- "Regenerate" button is directly clickable without previewing existing audio
- No confirmation step before calling FastAPI TTS endpoint
- Rate limit key is per-user rather than per-item

**Phase:** Address in Phase 2 (TTS feature). The cooldown column must be in Alembic migration before building the UI.

---

### Pitfall 4: apps/admin Vercel Deployment Missing outputFileTracingRoot

**What goes wrong:** When `apps/admin` is deployed to Vercel with `output: 'standalone'` (required for monorepo deployments), Next.js traces file dependencies relative to the app directory by default. Shared packages (`@harukoto/database`, `@harukoto/types`, `@harukoto/ui`) live outside `apps/admin/` at the monorepo root. Without `outputFileTracingRoot` pointing to the monorepo root, the standalone build silently excludes these packages, causing runtime `MODULE_NOT_FOUND` errors only visible after deployment.

**Why it happens:** The existing `apps/web` does not use `output: 'standalone'` (the current `next.config.ts` does not set it), suggesting the current deployment relies on Vercel's native Next.js build integration rather than standalone output. When `apps/admin` is added to the same Vercel organization, it must be configured as a separate Vercel project pointing to `apps/admin` as the root directory. Turborepo's `globalEnv` in `turbo.json` must be updated to include all admin-specific env vars, otherwise Turborepo cache busting will not work correctly.

**Consequences:**
- Deploy succeeds locally, crashes in production with missing module errors
- Admin app can accidentally be served from the wrong Vercel project if root directory is misconfigured

**Prevention:**
- Add `outputFileTracingRoot: path.join(__dirname, '../../')` to `apps/admin/next.config.ts`
- Configure a dedicated Vercel project for `apps/admin` with `Root Directory = apps/admin`
- Add admin-specific env vars to `turbo.json` globalEnv (e.g., `ADMIN_ALLOWED_ORIGINS`, any new role-related vars)
- Verify the build locally with `turbo build --filter=admin` before first deployment

**Warning signs:**
- `next build` succeeds in monorepo root but `node .next/standalone/server.js` throws `Cannot find module '@harukoto/database'`
- Vercel deployment logs show "Module not found" errors in the Function runtime

**Phase:** Address in Phase 1 (project scaffold). Get a green Vercel deploy before building any features.

---

### Pitfall 5: Prisma Client Shared Between main app and admin app Causes Version Conflicts

**What goes wrong:** Both `apps/web` and `apps/admin` depend on `@harukoto/database` (the shared Prisma package). If `apps/admin` requires a schema change for RBAC (e.g., adding a `user_roles` table), `prisma generate` in `packages/database` regenerates the client for ALL consumers. If `apps/web` is mid-deployment and the generated client is temporarily inconsistent, it can break the main app build.

**Why it happens:** There is one Prisma schema, one generated client, shared across all apps. Schema changes for the admin tool (reviewer roles, audit log table) touch the same schema file as the main app's models.

**Consequences:**
- Main app (`apps/web`) build failure triggered by admin-related schema changes
- Turborepo cache invalidation cascades across all apps on every `prisma generate`

**Prevention:**
- Alembic owns DDL — all new tables for admin (user_roles, tts_regeneration_log) MUST be created by Alembic first
- Add new Prisma models to schema in a separate PR from feature implementation — separate the schema PR from the feature PR
- Use Prisma's `@@ignore` pragma on purely admin-side tables that `apps/web` does not need, to avoid polluting the main app's generated types

**Warning signs:**
- `packages/database` has a Prisma model that is only referenced by `apps/admin`
- `turbo build --filter=web` fails after a schema change intended only for admin

**Phase:** Address in Phase 1 (foundation). Establish the schema change workflow before any DDL additions.

---

## Moderate Pitfalls

---

### Pitfall 6: i18n Translation Key Drift Across 3 Languages (한/日/英)

**What goes wrong:** With Japanese native speakers (日), Korean developers (한), and English as fallback, three message JSON files must stay in sync. When a developer adds a new UI string in Korean only (the development language), the Japanese translation is silently missing. `next-intl` falls back to the key name instead of a readable string — native Japanese reviewers see raw key strings like `vocabulary.edit.saveButton` instead of "保存".

**Why it happens:** There is no CI enforcement that all three locale files contain the same keys. Translation work is manually coordinated. With 1-3 non-developer native Japanese users, there is no translation process in place at all.

**Consequences:**
- Japanese reviewers see untranslated key strings in production
- Building the entire UI in Korean first, then translating after, is the most common pattern — but it means the admin tool is unusable in Japanese until a translation pass is done

**Prevention:**
- Establish `ja.json` as the canonical translation file (since Japanese reviewers are the primary users) and require all keys to exist in `ja.json` at merge time
- Add a CI script that diffs locale files: `node scripts/check-i18n.js` that fails if `ja.json` has missing keys relative to `ko.json`
- Use `next-intl` TypeScript strict mode with the default locale (`ja`) as the type source — any missing key is a TypeScript compile error
- Keep admin UI strings minimal: label fields with the database column name where possible (e.g., "word / 単語") rather than creating elaborate UI copy that requires full translation

**Warning signs:**
- A PR adds a new page but only modifies `ko.json`
- The Japanese reviewer reports seeing "vocabulary.edit.placeholder" in the input field

**Phase:** Address in Phase 1 (i18n foundation). Set up the three locale files and CI check before building any UI screens.

---

### Pitfall 7: Role Check Missing on FastAPI TTS Endpoint — Admin Bypasses Via Direct API Call

**What goes wrong:** The admin app's Next.js API route checks for the `reviewer` role before calling FastAPI's `/api/v1/vocab/tts`. But the FastAPI endpoint itself only checks `get_current_user` (any authenticated user). A regular app user who discovers the admin UI's API call pattern can bypass the admin app entirely and trigger TTS regeneration directly.

**Why it happens:** The existing `get_current_user` dependency in `dependencies.py` extracts the user from JWT but does not check any role claim. There is no `require_reviewer` dependency in the current codebase.

**Consequences:**
- Any authenticated HaruKoto user (learner app users) can trigger ElevenLabs TTS regeneration
- The in-app `POST /api/v1/vocab/tts` endpoint already exists and is accessible to regular users (it is rate-limited but not role-restricted)

**Prevention:**
- Create a new FastAPI dependency `require_admin_role` that reads a `user_role` column from the `users` table or checks a `user_roles` junction table
- Apply `require_admin_role` to ALL admin-facing FastAPI endpoints (new routes under `/api/v1/admin/*`)
- Do NOT reuse the existing `/api/v1/vocab/tts` endpoint for admin regeneration — create a separate admin endpoint at `/api/v1/admin/tts/regenerate` with role enforcement
- The `reviewer` role claim in the JWT (from Supabase Custom Access Token Hook) is a fast-path hint; the FastAPI dependency must still do a live DB lookup for the authoritative check

**Warning signs:**
- Admin Next.js route checks role but the underlying FastAPI route does not
- The FastAPI TTS route is used by both the learner app AND the admin tool without path separation

**Phase:** Address in Phase 1 (auth) and Phase 2 (TTS feature). The `require_admin_role` dependency must exist before Phase 2 begins.

---

### Pitfall 8: Optimistic Updates on Vocabulary/Grammar Edits Cause Divergence With Mobile App Cache

**What goes wrong:** When the admin updates a vocabulary record (corrects a `reading` field or `meaning_ko`), the change is committed to PostgreSQL. But the mobile Flutter app (and the main Next.js app) have TanStack Query / Riverpod caches for that vocabulary. If a learner is mid-session, they see the old data until their cache TTL expires or they restart the app.

This is expected behavior — but the admin tool creates a specific risk: if a reviewer regenerates TTS BEFORE correcting the text field, the new audio does not match the corrected text. The sequence matters.

**Why it happens:** TTS regeneration uses the current value of `vocabulary.reading` (or `vocabulary.word`) as the TTS input text. If the admin UI allows audio regeneration and text editing in any order without clear workflow guidance, mismatches accumulate.

**Prevention:**
- Enforce edit-then-regenerate order in the UI: show a banner "Audio was generated from an older text. Save your text changes first, then regenerate audio."
- Compare `tts_audio.text` against the current `vocabulary.reading` — if they differ, flag the entry in the list view with a visual indicator
- Add a server-side check in the TTS regeneration endpoint: before generating, read the current `vocabulary.reading` and compare with `tts_audio.text` — if they match, return the cached audio and refuse to regenerate

**Warning signs:**
- Admin UI shows "Regenerate" button even when the text field has unsaved changes
- `tts_audio.text` and `vocabulary.reading` are out of sync in the database

**Phase:** Address in Phase 2 (TTS feature) and Phase 3 (vocabulary editing).

---

### Pitfall 9: Non-Technical Users Accidentally Edit Wrong Records Due to Lack of Search/Filter

**What goes wrong:** With thousands of vocabulary entries (JLPT N5–N1 corpus), a native Japanese reviewer scrolling a paginated list without filtering by JLPT level or search will find it nearly impossible to locate specific words. The frustration of navigation leads to either editing the wrong record or abandoning the tool entirely.

This is not a technical bug but a UX failure that negates the entire value of the admin tool.

**Why it happens:** Admin tools built by developers default to "show all records with pagination," which works for developers debugging data but fails for non-developer workflow users.

**Prevention:**
- Filter by JLPT level (N5/N4/N3/N2/N1) as the primary navigation — not an optional filter but a required first step
- Add a search field that searches across `word`, `reading`, and `meaning_ko`
- Show TTS status inline in the list: green (has audio), yellow (text was updated after audio), red (no audio) — reviewers can scan the list visually
- Add a "Needs Review" queue: entries flagged during seed import as low-confidence, or entries where `tts_audio` is missing

**Warning signs:**
- The list view shows all vocabulary sorted by `created_at` with no filter UI
- Reviewers report they cannot find the word they want to check

**Phase:** Address in Phase 3 (vocabulary UI). Invest in filtering before building editing forms.

---

## Minor Pitfalls

---

### Pitfall 10: pnpm workspace:* Dependency Not Installed in apps/admin

**What goes wrong:** When `apps/admin/package.json` declares `"@harukoto/database": "workspace:*"`, pnpm resolves this correctly. But if a developer runs `npm install` or `yarn` inside `apps/admin/` (not from the monorepo root), the workspace symlinks are not created and imports fail with `Cannot find module`.

**Prevention:**
- Add a `.npmrc` or `package.json` `engines` field that warns against running npm/yarn directly in app subdirectories
- Document in the admin app's README: "Always run pnpm from the monorepo root"

**Phase:** Address in Phase 1 (scaffold).

---

### Pitfall 11: Admin URL Not Protected by Vercel Authentication

**What goes wrong:** The admin app deployed to Vercel at `admin.harukoto.app` is publicly accessible by URL. While app-level auth guards the data routes, unauthenticated users can still reach the login page and attempt credential stuffing.

**Prevention:**
- Enable Vercel Password Protection or Vercel's Deployment Protection (IP allowlist) as a first layer
- Alternatively, deploy to a non-public Vercel URL (e.g., `harukoto-admin.vercel.app` without a custom domain) and share URL only with reviewers
- Do not advertise the admin URL in any public documentation

**Phase:** Address in Phase 1 (deployment).

---

### Pitfall 12: Audio Preview Requires CORS Headers on GCS Bucket

**What goes wrong:** The admin app on `admin.harukoto.app` will use `<audio>` elements to preview TTS files stored in GCS (`harukoto-tts` bucket). GCS buckets do not serve CORS headers by default. Audio playback from a different origin than the main app will fail silently (audio element shows no error, just never plays).

**Why it happens:** The main app serves TTS URLs to the mobile app (which does not enforce CORS), so the bucket may not have CORS configured for web origins.

**Prevention:**
- Verify the GCS bucket's CORS configuration before building the audio preview UI
- Add `https://admin.harukoto.app` to the GCS CORS allowed origins in the bucket's CORS JSON config
- Test audio playback from the admin domain explicitly during Phase 2

**Warning signs:**
- Browser console shows "No 'Access-Control-Allow-Origin' header is present" when loading audio
- Audio element `onError` fires but no network error is shown in DevTools

**Phase:** Address in Phase 2 (TTS feature, first playback implementation).

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Phase 1: apps/admin scaffold | Missing `outputFileTracingRoot` breaks Vercel deploy | Add to `next.config.ts` before first deploy attempt |
| Phase 1: Supabase Auth + reviewer role | Stale JWT claims after revocation | Two-layer check: JWT claim + live DB lookup on all writes |
| Phase 1: i18n foundation | Japanese locale missing keys from day one | Set `ja.json` as TypeScript type source, CI key diff check |
| Phase 1: Alembic user_roles table | Admin schema changes break main app's Prisma build | Separate schema PR, use `@@ignore` for admin-only models |
| Phase 2: TTS regeneration UI | Non-technical user triggers duplicate/accidental ElevenLabs charges | Confirmation dialog + per-item cooldown in DB + audit log |
| Phase 2: FastAPI TTS endpoint | Regular learners can bypass admin role check | New `/api/v1/admin/tts/regenerate` endpoint with `require_admin_role` |
| Phase 2: GCS audio preview | CORS blocks audio playback in admin browser | Verify and update GCS CORS config before building audio UI |
| Phase 3: Vocabulary editing | Edit-then-regenerate order mismatch | UI workflow enforcement: save text before enabling regenerate |
| Phase 3: Record navigation | Non-technical users cannot find records | JLPT-level filter as required first navigation step, not optional |
| Phase 4: Grammar/Quiz data | Dual ORM partial save overwrites Alembic-managed columns | PATCH with explicit field list, never full model update |

---

## Sources

- Supabase Custom Access Token Hook docs: https://supabase.com/docs/guides/auth/auth-hooks/custom-access-token-hook
- Supabase Custom Claims RBAC guide: https://supabase.com/docs/guides/database/postgres/custom-claims-and-role-based-access-control-rbac
- Turborepo Next.js deployment guide: https://turborepo.dev/docs/guides/frameworks/nextjs
- Turborepo internal packages docs: https://turborepo.dev/docs/core-concepts/internal-packages
- TypeScript path alias conflicts in Turborepo (community): https://github.com/vercel/turborepo/discussions/620
- next-intl rendering translations: https://next-intl.dev/docs/usage/translations
- next-intl 2025 best practices: https://eastondev.com/blog/en/posts/dev/20251225-nextjs-i18n-complete-guide/
- UX guide to destructive actions: https://medium.com/design-bootcamp/a-ux-guide-to-destructive-actions-their-use-cases-and-best-practices-f1d8a9478d03
- Managing dangerous actions in UIs (Smashing Magazine): https://www.smashingmagazine.com/2024/09/how-manage-dangerous-actions-user-interfaces/
- Prisma read-only schema discussion: https://github.com/prisma/prisma/discussions/19512
- ElevenLabs regeneration policy: https://elevenlabs.io/docs/overview/capabilities/text-to-speech
- Project codebase analysis: `/Users/kimkunwoo/WhiteMouseDev/japanese/.planning/codebase/CONCERNS.md`
