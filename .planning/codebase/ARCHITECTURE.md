# Architecture

**Analysis Date:** 2026-03-26

## Pattern Overview

**Overall:** Turborepo monorepo with three application frontends (Next.js web, Flutter mobile, Next.js landing) and a Python/FastAPI backend, sharing a PostgreSQL database via dual ORM strategy (Prisma + SQLAlchemy).

**Key Characteristics:**
- Monorepo managed by Turborepo + pnpm workspaces
- Dual-ORM database access: Prisma (web runtime + static seeding) and SQLAlchemy (API runtime + lesson seeding)
- DDL authority belongs exclusively to Alembic (Python migrations); Prisma syncs via `pnpm db:sync`
- Supabase for authentication (JWT tokens) across all clients
- AI features powered by Vercel AI SDK + Google Gemini / OpenAI, abstracted in `@harukoto/ai` package
- Mobile app communicates with FastAPI backend; web app uses both Next.js API routes (BFF) and FastAPI

## Layers

**Presentation (Web):**
- Purpose: Next.js 16.1 App Router with Server Components by default, `"use client"` where needed
- Location: `apps/web/src/app/`
- Contains: Pages, layouts, API route handlers
- Depends on: `@harukoto/database`, `@harukoto/ai`, Supabase client
- Used by: End users via browser/PWA

**Presentation (Mobile):**
- Purpose: Flutter app with feature-based architecture using Riverpod for state management
- Location: `apps/mobile/lib/`
- Contains: Features (home, study, chat, kana, subscription, my, auth), core services
- Depends on: FastAPI backend via Dio HTTP client, Supabase Flutter SDK
- Used by: End users via iOS/Android

**BFF Layer (Next.js API Routes):**
- Purpose: Browser cookie/session bridge, web-platform-specific features
- Location: `apps/web/src/app/api/v1/`
- Contains: Route handlers for quiz, chat, wordbook, payments, user, missions, auth
- Depends on: `@harukoto/database` (Prisma), `@harukoto/ai`, Supabase server client
- Used by: Web frontend only
- **Policy:** No new domain logic here; use FastAPI. BFF-only for auth bridging, web push, cron

**Backend API (FastAPI):**
- Purpose: Primary backend for business logic, shared by mobile and (increasingly) web
- Location: `apps/api/app/`
- Contains: Routers, services, models (SQLAlchemy), schemas (Pydantic), middleware
- Depends on: PostgreSQL via SQLAlchemy async, Supabase JWT verification, external APIs
- Used by: Mobile app, web app (migrating)

**Shared Packages:**
- `packages/database/`: Prisma client + schema + seed data
- `packages/ai/`: AI provider abstraction (OpenAI/Gemini), TTS, STT
- `packages/types/`: Shared TypeScript type definitions
- `packages/config/`: Shared ESLint, TS, Tailwind configs

## Data Flow

**Web Quiz Flow:**
1. User starts quiz → client calls `POST /api/v1/quiz/start` (Next.js API route)
2. Route handler queries Prisma for questions based on JLPT level and quiz type
3. User answers → `POST /api/v1/quiz/answer` → updates `QuizAnswer` + `UserVocabProgress`/`UserGrammarProgress`
4. Quiz complete → `POST /api/v1/quiz/complete` → updates `QuizSession`, `DailyProgress`, XP

**Mobile Study Flow:**
1. Mobile app fetches lessons from `GET /api/v1/lessons/` (FastAPI)
2. FastAPI queries SQLAlchemy models for `chapters`, `lessons`, `lesson_item_links`
3. User completes lesson → `POST /api/v1/lessons/{id}/complete` → updates `user_lesson_progress`
4. SRS items registered → `user_vocab_progress` / `user_grammar_progress` updated with FSRS fields

**AI Chat Flow:**
1. User selects character + scenario → `POST /api/v1/chat/start` creates `Conversation`
2. Each message → `POST /api/v1/chat/message` → AI SDK generates response using system prompt
3. Live feedback → `POST /api/v1/chat/live-feedback` for grammar correction during chat
4. TTS → `POST /api/v1/chat/tts` → Gemini TTS or ElevenLabs generates audio
5. Voice call → Gemini Live API via ephemeral tokens (`/api/v1/chat/live-token`)

**Authentication Flow:**
1. Web: Supabase Auth with Google/Kakao OAuth → session stored in cookies via `@supabase/ssr`
2. Mobile: Supabase Flutter SDK + Kakao native SDK → JWT stored locally
3. FastAPI: Validates Supabase JWT via JWKS (ES256) or legacy HS256 secret
4. Auto-provisioning: First API call with valid JWT creates user record if not exists

**State Management:**
- Web server state: TanStack Query with custom hooks in `apps/web/src/hooks/`
- Web client state: Zustand store (currently only `apps/web/src/stores/onboarding.ts`)
- Mobile state: Riverpod providers in `lib/features/*/providers/`

## Key Abstractions

**AI Provider (`@harukoto/ai`):**
- Purpose: Abstract AI model selection between OpenAI and Google Gemini
- Files: `packages/ai/src/provider.ts`, `packages/ai/src/prompts.ts`
- Pattern: Factory function `getAIProvider()` returns `LanguageModelV1` based on `AI_PROVIDER` env var
- Also exposes `generateTTS()` and `transcribeAudio()` for voice features

**Database Client (`@harukoto/database`):**
- Purpose: Singleton Prisma client with dev-mode hot-reload protection
- Files: `packages/database/src/client.ts`
- Pattern: Global singleton pattern to prevent multiple Prisma instances in development

**Supabase Auth Helpers:**
- Purpose: Server-side and client-side Supabase client creation for Next.js
- Files: `apps/web/src/lib/supabase/server.ts`, `apps/web/src/lib/supabase/client.ts`, `apps/web/src/lib/supabase/admin.ts`, `apps/web/src/lib/supabase/auth.ts`
- Pattern: `getUser()` and `requireUser()` wrappers for server components/route handlers

**Mobile Network Layer:**
- Purpose: Authenticated HTTP client with token refresh
- Files: `apps/mobile/lib/core/network/dio_client.dart`, `apps/mobile/lib/core/network/auth_interceptor.dart`, `apps/mobile/lib/core/network/auth_refresh_client.dart`
- Pattern: Dio HTTP client with auth interceptor for automatic JWT injection

**Custom React Hooks (Web):**
- Purpose: Encapsulate TanStack Query logic per domain
- Files: `apps/web/src/hooks/use-quiz.ts`, `apps/web/src/hooks/use-user.ts`, `apps/web/src/hooks/use-chat-history.ts`, etc. (28 hooks total)
- Pattern: Each hook manages server state for a specific feature using TanStack Query

## Entry Points

**Web App:**
- Location: `apps/web/src/app/layout.tsx`
- Triggers: Browser request
- Responsibilities: Root layout with ThemeProvider, QueryProvider, PWA registration, Google Analytics, Toaster

**Web App (Authenticated):**
- Location: `apps/web/src/app/(app)/layout.tsx`
- Triggers: Navigation to app routes
- Responsibilities: App shell with BottomNav, MainContent, ErrorBoundary

**Mobile App:**
- Location: `apps/mobile/lib/main.dart`
- Triggers: App launch
- Responsibilities: Kakao SDK init, Supabase init, local notifications, sound/haptic services, Riverpod ProviderScope

**FastAPI Backend:**
- Location: `apps/api/app/main.py`
- Triggers: HTTP requests
- Responsibilities: CORS middleware, Sentry init, router registration (21 routers)

**Landing Page:**
- Location: `apps/landing/src/app/`
- Triggers: Browser request to landing domain
- Responsibilities: Static marketing pages, privacy/terms

## Error Handling

**Strategy:** Multi-layered with platform-specific approaches

**Patterns:**
- Web: `ErrorBoundary` component wraps app content; `error.tsx` files per route; `apiFetch()` in `apps/web/src/lib/api.ts` throws on non-OK responses
- Mobile: `api_exception.dart` in `apps/mobile/lib/core/network/` for HTTP error handling
- FastAPI: HTTPException with status codes; Sentry integration for unhandled errors
- Form validation: Zod schemas (web), Pydantic schemas (API)

## Cross-Cutting Concerns

**Logging:**
- Web: Console-based (no structured logging framework)
- API: Python `logging` module; SQLAlchemy query logging in development
- Mobile: Sentry for error tracking
- Prisma: Query logging in development mode

**Validation:**
- Web forms: React Hook Form + Zod
- API input: Pydantic BaseModel schemas in `apps/api/app/schemas/`
- Database: Prisma schema constraints + PostgreSQL check constraints

**Authentication:**
- Provider: Supabase Auth (Google OAuth, Kakao OAuth)
- Web: Cookie-based sessions via `@supabase/ssr`
- Mobile: Supabase Flutter SDK with local token storage
- API: JWT verification via `apps/api/app/dependencies.py` (`get_current_user`)

**Rate Limiting:**
- Web: `apps/web/src/lib/rate-limit.ts`
- API: `apps/api/app/middleware/rate_limit.py`

**Spaced Repetition:**
- FSRS algorithm implementation in `apps/api/app/services/fsrs_shadow.py` and `apps/api/app/services/srs.py`
- Web fallback in `apps/web/src/lib/spaced-repetition.ts`
- Feature-flagged via `FSRS_ENABLED` setting

**Gamification:**
- XP/Level system in `apps/api/app/services/gamification.py` and `apps/web/src/lib/gamification.ts`
- Daily missions, streaks, achievements tracked in database

**Payments:**
- PortOne V2 integration for Korean payment processing
- Webhook handling at `apps/web/src/app/api/v1/webhook/portone/`
- Subscription management in `apps/api/app/services/subscription.py`

---

*Architecture analysis: 2026-03-26*
