# Codebase Concerns

**Analysis Date:** 2026-03-26

## Tech Debt

**Dual ORM Schema Maintenance (Prisma + SQLAlchemy):**
- Issue: Two ORMs model the same database -- Prisma (`packages/database/prisma/schema.prisma`, 850 lines) and SQLAlchemy (`apps/api/app/models/`). Every schema change must be synchronized across both. Alembic owns DDL, Prisma uses `db:sync`.
- Files: `packages/database/prisma/schema.prisma`, `apps/api/app/models/*.py`, `apps/api/alembic/`
- Impact: Schema drift between ORMs can cause runtime errors silently. CI has a schema-drift check (`.github/workflows/ci.yml` line 160+) but this adds friction to every DB change.
- Severity: **High**
- Fix approach: Long-term, consolidate to a single data access layer. Short-term, the CI drift check mitigates risk.

**Duplicated API Routes (Web + FastAPI):**
- Issue: Web API routes (`apps/web/src/app/api/v1/`) and FastAPI routers (`apps/api/app/routers/`) overlap significantly. Both have endpoints for quiz, chat, stats, missions, kana, wordbook, subscription, user, webhook, cron, notifications, payments, and push. The policy doc (`api-plane.md`) acknowledges this and says "existing duplicates are maintained for now."
- Files: `apps/web/src/app/api/v1/quiz/`, `apps/api/app/routers/quiz.py`, and 15+ other overlapping domains
- Impact: Bug fixes and feature changes must be applied in two places. Business logic divergence between platforms is likely.
- Severity: **High**
- Fix approach: Per `api-plane.md`, migrate Web routes to FastAPI proxy pattern. Prioritize quiz, stats, and chat routes (highest complexity).

**Repetitive Auth Boilerplate in Web API Routes:**
- Issue: 50 API route files each repeat the same Supabase auth pattern: `const supabase = await createClient(); const { data: { user } } = await supabase.auth.getUser(); if (!user) return 401;`
- Files: All files in `apps/web/src/app/api/v1/` (50 files, 57 occurrences)
- Impact: Code duplication, inconsistent error messages, no centralized auth middleware.
- Severity: **Medium**
- Fix approach: Create a shared `withAuth(handler)` wrapper or use Next.js proxy-level auth (already in `apps/web/src/proxy.ts`). This becomes less relevant as routes migrate to FastAPI.

**In-Memory Rate Limiting on Serverless:**
- Issue: `apps/web/src/lib/rate-limit.ts` uses a `Map` in process memory for rate limiting. On Vercel (serverless), each function invocation may be a fresh instance, making this ineffective.
- Files: `apps/web/src/lib/rate-limit.ts`
- Impact: Rate limits are not reliably enforced in production. AI endpoints (TTS, chat) could be abused.
- Severity: **High**
- Fix approach: Use Redis-based rate limiting (FastAPI already uses Redis via `apps/api/app/middleware/rate_limit.py`). The file itself notes "production scale should use Redis."

**FSRS Migration Not Complete:**
- Issue: The SRS algorithm is SM-2 with a TODO to switch to FSRS when `FSRS_ENABLED=True`. The code is commented out.
- Files: `apps/api/app/routers/quiz.py` line 78, `apps/api/app/config.py` line 62
- Impact: Feature flag exists but migration path is incomplete. FSRS package (`fsrs>=6.3.1`) is installed but unused in production.
- Severity: **Low**
- Fix approach: Complete the FSRS integration or remove the unused dependency.

**dispose() Provider Invalidation Workaround:**
- Issue: 6 Flutter pages use `Future(() => container.invalidate(...))` in `dispose()` to avoid mutating provider state during disposal. This is a known Riverpod anti-pattern.
- Files: `apps/mobile/lib/features/chat/presentation/conversation_page.dart:61`, `apps/mobile/lib/features/study/presentation/quiz_page.dart:60`, `apps/mobile/lib/features/study/presentation/lesson_page.dart:31`, `apps/mobile/lib/features/chat/presentation/voice_call_page.dart:64`, `apps/mobile/lib/features/chat/presentation/call_analyzing_page.dart:65`, `apps/mobile/lib/features/kana/presentation/kana_stage_page.dart:56`
- Impact: Potential race conditions if navigation is fast. State may leak between sessions.
- Severity: **Medium**
- Fix approach: Use Riverpod's `autoDispose` modifier or handle cleanup in the provider's `ref.onDispose` callback.

**`dependency_overrides` in pubspec.yaml:**
- Issue: `record_platform_interface: 1.2.0` is pinned as a dependency override in `apps/mobile/pubspec.yaml` line 60-61.
- Files: `apps/mobile/pubspec.yaml`
- Impact: Overrides mask version conflicts and can cause subtle bugs. May break when `record` package updates.
- Severity: **Low**
- Fix approach: Track the upstream issue and remove override when compatible versions are released.

**CI Breaking Change Detection is Non-Blocking:**
- Issue: The oasdiff breaking change check in CI uses `continue-on-error: true` (`.github/workflows/ci.yml` line 153-154). Breaking API changes can merge without notice.
- Files: `.github/workflows/ci.yml` line 153
- Impact: Mobile clients could break from undetected API contract changes.
- Severity: **Medium**
- Fix approach: Remove `continue-on-error` once oasdiff warning mode is stabilized (per the TODO comment).

## Security Considerations

**Conditional Webhook Signature Verification:**
- Risk: PortOne webhook signature is only verified if `PORTONE_WEBHOOK_SECRET` env var is set. If missing, any request is accepted as valid.
- Files: `apps/web/src/app/api/v1/webhook/portone/route.ts` line 17, `apps/api/app/config.py` line 39
- Current mitigation: Amount verification against DB (line 57-67) provides secondary defense.
- Severity: **High**
- Recommendations: Make `PORTONE_WEBHOOK_SECRET` required in production. Fail closed (reject if secret not configured).

**Conditional Cron Endpoint Authentication:**
- Risk: Cron endpoints in both Web and API skip auth when `CRON_SECRET` is empty string (default).
- Files: `apps/api/app/routers/cron.py` lines 22, 54, 106; `apps/api/app/config.py` line 53
- Current mitigation: None in development. Vercel cron protection helps in production.
- Severity: **High**
- Recommendations: Require `CRON_SECRET` in production environments. Add startup validation.

**Non-Null Assertions on Environment Variables:**
- Risk: 15+ uses of `process.env.VARIABLE!` (non-null assertion) without runtime validation. If env vars are missing, runtime crashes instead of clear error messages.
- Files: `apps/web/src/lib/gcs.ts` lines 3-4, 13-14; `apps/web/src/lib/supabase/server.ts` lines 8-9; `apps/web/src/lib/supabase/admin.ts` lines 5-6; `apps/web/src/lib/web-push.ts` lines 5-6
- Current mitigation: FastAPI side validates via Pydantic Settings. Web side has no validation.
- Severity: **Medium**
- Recommendations: Add a startup env validation module (e.g., `@t3-oss/env-nextjs` or a Zod schema).

**Inconsistent Input Validation (Web API):**
- Risk: Only 12 of 53 Web API route files use Zod validation. The rest use manual checks or none. Quiz start (`apps/web/src/app/api/v1/quiz/start/route.ts`) destructures request body without Zod.
- Files: Routes without Zod: `apps/web/src/app/api/v1/quiz/start/route.ts`, `apps/web/src/app/api/v1/quiz/complete/route.ts`, `apps/web/src/app/api/v1/chat/start/route.ts`, `apps/web/src/app/api/v1/auth/onboarding/route.ts`, `apps/web/src/app/api/v1/chat/end/route.ts`, and ~35 others
- Current mitigation: Most routes have basic null checks. FastAPI side uses Pydantic.
- Severity: **Medium**
- Recommendations: Add Zod schemas to all POST/PATCH/PUT routes. Prioritize routes that accept user text input.

**Type Suppression in Config:**
- Risk: `settings = Settings()  # type: ignore[call-arg]` suppresses Pydantic validation error at import time.
- Files: `apps/api/app/config.py` line 69
- Current mitigation: `.env` file provides values at runtime.
- Severity: **Low**
- Recommendations: This is a common Pydantic Settings pattern with `env_file`. Low risk but should be documented.

## Performance Concerns

**No Code Splitting for Framer Motion:**
- Problem: 70 component/page files import from `framer-motion`. This large library (~35KB gzipped) is bundled into every page's client JS.
- Files: All files importing from `framer-motion` across `apps/web/src/components/` and `apps/web/src/app/`
- Cause: No `next/dynamic` usage for heavy components. Only 1 production dynamic import exists (PortOne SDK in checkout page).
- Severity: **Medium**
- Improvement path: Use `next/dynamic` for heavy feature components. Create a `LazyMotion` wrapper to reduce initial bundle.

**Giant Route Handler (Quiz Start):**
- Problem: `apps/web/src/app/api/v1/quiz/start/route.ts` is 540 lines with 23 Prisma queries in a single request handler. Multiple sequential queries for different quiz types.
- Files: `apps/web/src/app/api/v1/quiz/start/route.ts`
- Cause: All quiz type logic (vocabulary, grammar, cloze, sentence-arrange, review modes) in one handler.
- Severity: **Medium**
- Improvement path: Extract quiz type handlers into separate functions/modules. Batch related queries with `Promise.all` where possible.

**Giant API Router (Quiz - FastAPI):**
- Problem: `apps/api/app/routers/quiz.py` is 1880 lines. Similar to the Web quiz route, it handles all quiz types in one file.
- Files: `apps/api/app/routers/quiz.py`
- Cause: All quiz modes and SRS logic consolidated in one router.
- Severity: **Medium**
- Improvement path: Split into sub-modules per quiz type.

**Giant Widget File (Lesson Page - Flutter):**
- Problem: `apps/mobile/lib/features/study/presentation/lesson_page.dart` is 2006 lines -- the largest source file in the project. Contains the 6-step lesson flow in a single widget.
- Files: `apps/mobile/lib/features/study/presentation/lesson_page.dart`
- Cause: All 6 lesson steps (preview, guided reading, comprehension, matching, reconstruction, result) in one file.
- Severity: **Medium**
- Improvement path: Extract each step into its own widget file under a `widgets/` directory.

**Missing Error Boundaries for Nested Routes:**
- Problem: Only 1 `error.tsx` exists at `apps/web/src/app/(app)/error.tsx`. 31 pages share this single boundary. A crash in study/quiz shows the same generic error as a crash in chat.
- Files: `apps/web/src/app/(app)/error.tsx`
- Cause: Error boundaries were not added per-feature.
- Severity: **Low**
- Improvement path: Add feature-specific `error.tsx` for study, chat, and stats route groups.

## Fragile Areas

**Broad Exception Handling in FastAPI:**
- Files: `apps/api/app/routers/chat.py` lines 406, 493, 504, 510; `apps/api/app/routers/cron.py` line 90; `apps/api/app/routers/lessons.py` lines 469, 502
- Why fragile: Bare `except Exception:` catches everything including programming errors. In chat.py, nested try/except blocks (gamification -> conversation save -> commit) mask the root cause of failures.
- Safe modification: Catch specific exception types. Add structured error logging with context.
- Severity: **Medium**

**Quiz Start Auto-Complete Logic:**
- Files: `apps/web/src/app/api/v1/quiz/start/route.ts` lines 29-60
- Why fragile: Starting a new quiz auto-completes ALL previous incomplete sessions and awards XP. If a bug creates orphaned sessions, this could grant unearned XP on every quiz start.
- Safe modification: Add a time limit for auto-completion (e.g., only sessions older than 1 hour). Log auto-completed sessions.
- Severity: **Medium**

## Test Coverage Gaps

**No E2E Tests:**
- What's not tested: No Playwright, Cypress, or any E2E test framework is configured despite CLAUDE.md listing "Playwright (E2E)" in the tech stack.
- Files: No `playwright.config.*`, no `e2e/` directory, no `*.e2e.*` files anywhere in the project.
- Risk: Core user flows (login -> onboarding -> quiz -> results) have no automated end-to-end verification.
- Severity: **High**
- Priority: High -- critical user flows should have E2E coverage before production launch.

**Web Tests are Shallow:**
- What's not tested: Only 8 test files exist for the web app (`apps/web/src/__tests__/`). No tests for API route handlers, no tests for hooks like `use-voice-call.ts` (458 lines), no tests for subscription/payment flows.
- Files: `apps/web/src/__tests__/` (8 files total: gamification, constants, chat-components, stats-components, api, game-icon, show-events, spaced-repetition)
- Risk: Payment and subscription routes (`apps/web/src/app/api/v1/webhook/portone/route.ts`, `apps/web/src/app/api/v1/subscription/`) have zero test coverage.
- Severity: **High**
- Priority: High -- payment-related code must have tests.

**Mobile Integration Tests Missing:**
- What's not tested: Mobile tests cover models and providers but no widget integration tests for complex flows (lesson 6-step flow, voice call).
- Files: `apps/mobile/test/` has model tests and provider tests, but `apps/mobile/test/features/study/presentation/` only has `quiz_launch_test.dart`, `study_entry_flow_test.dart`, `quiz_result_page_test.dart` -- no lesson flow test.
- Risk: The 2006-line lesson page has no integration test.
- Severity: **Medium**
- Priority: Medium

## Accessibility Gaps

**Low Accessibility Attribute Coverage:**
- Problem: Only 28 of 119 TSX component files include any `aria-*`, `role=`, or `alt=` attributes. Many interactive components lack proper labeling.
- Files: Components without accessibility: most files in `apps/web/src/components/features/dashboard/`, `apps/web/src/components/features/quiz/` (except cloze-quiz), `apps/web/src/components/features/subscription/`
- Impact: Screen reader users cannot use the quiz, dashboard, or subscription features effectively.
- Severity: **Medium**
- Fix approach: Audit all interactive components. Add `aria-label` to icon buttons, `role` to custom widgets, `alt` to decorative vs informative images.

## Dependencies at Risk

**Unused FSRS Dependency:**
- Risk: `fsrs>=6.3.1` is declared in `apps/api/pyproject.toml` but not used in production code (behind disabled feature flag).
- Impact: Adds to install size and potential supply chain risk for no benefit.
- Severity: **Low**
- Migration plan: Either complete the FSRS migration or remove the dependency.

## Missing Critical Features

**No Structured Logging in Web App:**
- Problem: Web API routes use `console.error()` for all error logging (40+ occurrences). No structured logging, no request correlation IDs, no log levels.
- Files: All route files in `apps/web/src/app/api/v1/`
- Blocks: Production debugging, error tracking correlation, log aggregation.
- Severity: **Medium**
- Fix approach: Sentry is integrated (`@sentry/nextjs`) which partially addresses this. Consider adding a structured logger for non-error logs.

**No Environment Variable Validation (Web):**
- Problem: FastAPI validates env vars via Pydantic Settings at startup. Web app uses raw `process.env` with non-null assertions everywhere.
- Files: `apps/web/src/lib/gcs.ts`, `apps/web/src/lib/supabase/*.ts`, `apps/web/src/lib/web-push.ts`
- Blocks: Clear error messages when deployment is misconfigured.
- Severity: **Medium**
- Fix approach: Add `apps/web/src/lib/env.ts` with Zod validation, imported by all server-side code.

---

*Concerns audit: 2026-03-26*
