# Technology Stack

**Analysis Date:** 2026-03-26

## Languages

**Primary:**
- TypeScript ^5.8+ - Web app (`apps/web`), landing page (`apps/landing`), shared packages (`packages/*`)
- Dart (SDK ^3.6.0) - Mobile app (`apps/mobile`)
- Python >=3.12 - Backend API (`apps/api`)

**Secondary:**
- SQL - Database migrations (`apps/api/alembic/versions/`), Prisma schema (`packages/database/prisma/schema.prisma`)

## Runtime

**Environment:**
- Node.js >=20.9.0 (CI uses Node 22)
- Python 3.12
- Flutter stable channel (Dart SDK ^3.6.0)

**Package Managers:**
- pnpm 10.19.0 - Node.js monorepo (lockfile: `pnpm-lock.yaml`)
- uv (latest) - Python deps (`apps/api/uv.lock`)
- Flutter pub - Dart deps (`apps/mobile/pubspec.lock`)

## Frameworks

**Core:**
- Next.js 16.1.6 - Web app + landing page (App Router, Turbopack, React Compiler enabled)
- React 19.2.3 - UI rendering
- FastAPI >=0.115 - Python backend API
- Flutter 3.x (stable) - Cross-platform mobile app

**Testing:**
- Vitest ^4.0.18 - Web unit/integration tests (`apps/web/vitest.config.ts`)
- Testing Library (React ^16.3.2, jest-dom ^6.9.1) - Component testing
- pytest >=8.3 + pytest-asyncio >=0.25 - Python API tests
- Flutter test - Mobile unit tests

**Build/Dev:**
- Turborepo ^2.5.0 - Monorepo orchestration (`turbo.json`)
- Turbopack - Next.js dev bundler (default in Next.js 16)
- Hatchling - Python package build backend
- Docker - API containerization (`apps/api/Dockerfile`)

## Key Dependencies

**Critical (Web - `apps/web/package.json`):**
- `@supabase/supabase-js` ^2.98.0 - Auth + database client
- `@supabase/ssr` ^0.8.0 - Server-side Supabase for Next.js
- `ai` ^4.3.19 (Vercel AI SDK) - AI streaming/chat abstraction
- `@google/genai` ^1.0.0 - Google Gemini direct SDK (TTS, STT)
- `@tanstack/react-query` ^5.90.21 - Server state management
- `zustand` ^5.0.11 - Client state management
- `zod` ^3.25.76 - Schema validation
- `react-hook-form` ^7.71.2 + `@hookform/resolvers` ^5.2.2 - Form handling
- `@sentry/nextjs` ^10.42.0 - Error monitoring
- `@portone/browser-sdk` ^0.1.3 - Payment integration (Korean payment gateway)
- `web-push` ^3.6.7 - Web push notifications

**Critical (API - `apps/api/pyproject.toml`):**
- `sqlalchemy[asyncio]` >=2.0 - Async ORM
- `asyncpg` >=0.30 - PostgreSQL async driver
- `alembic` >=1.14 - Database migrations (DDL authority)
- `pydantic` >=2.10 + `pydantic-settings` >=2.7 - Data validation/settings
- `google-genai` >=1.0 - Google AI SDK
- `elevenlabs` >=2.39.0 - Text-to-speech service
- `redis` >=5.2 - Rate limiting / caching
- `pyjwt[crypto]` >=2.9 - JWT verification (Supabase auth)
- `sentry-sdk[fastapi]` >=2.54.0 - Error monitoring
- `fsrs` >=6.3.1 - Spaced repetition scheduling algorithm
- `lameenc` >=1.7 - MP3 encoding (audio processing)
- `httpx` >=0.28 - HTTP client

**Critical (Mobile - `apps/mobile/pubspec.yaml`):**
- `supabase_flutter` ^2.8.0 - Auth + backend
- `flutter_riverpod` ^3.0.0 - State management
- `dio` ^5.7.0 - HTTP client
- `go_router` ^14.6.0 - Navigation
- `sentry_flutter` ^8.12.0 - Error monitoring
- `google_sign_in` ^6.2.2 - Google OAuth
- `kakao_flutter_sdk_user` ^1.9.5 - Kakao OAuth
- `sign_in_with_apple` ^7.0.1 - Apple Sign In
- `record` ^5.2.1 - Audio recording (voice call feature)
- `web_socket_channel` ^3.0.2 - WebSocket for real-time
- `audioplayers` ^6.1.0 - Audio playback

**UI Libraries (Web):**
- `radix-ui` ^1.4.3 - Headless UI primitives (via shadcn)
- `framer-motion` ^12.34.3 - Animations
- `lucide-react` ^0.575.0 - Icons
- `class-variance-authority` ^0.7.1 - Variant styling
- `tailwind-merge` ^3.5.0 - Tailwind class merging
- `clsx` ^2.1.1 - Conditional classes
- `sonner` ^2.0.7 - Toast notifications
- `next-themes` ^0.4.6 - Theme switching
- `sharp` ^0.34.5 - Image optimization

**Infrastructure:**
- `@prisma/client` ^6.5.0 - Type-safe database client (web runtime)
- `prisma` ^6.5.0 - Schema management + code generation

## Shared Packages (Monorepo)

| Package | Path | Purpose |
|---------|------|---------|
| `@harukoto/database` | `packages/database` | Prisma schema + client + seed scripts |
| `@harukoto/ai` | `packages/ai` | AI provider abstraction (OpenAI/Google), TTS, STT |
| `@harukoto/types` | `packages/types` | Shared TypeScript type definitions |
| `@harukoto/config` | `packages/config` | Shared tsconfig presets (base, nextjs, library) |

## Configuration

**TypeScript:**
- Strict mode enabled (`packages/config/tsconfig.base.json`)
- `noUncheckedIndexedAccess: true`
- `isolatedModules: true`
- Shared base configs in `packages/config/`

**Linting/Formatting:**
- ESLint 9 + eslint-config-next 16.1.6 (web, landing)
- Prettier ^3.5.0 + prettier-plugin-tailwindcss ^0.7.2 (root)
- ruff >=0.9 (Python: lint + format, line-length 140, target py312)
- dart format + flutter analyze (mobile)
- mypy >=1.14 strict mode with pydantic plugin (Python type checking)

**Build:**
- `next.config.ts` - React Compiler enabled, Sentry integration, static asset caching
- `turbo.json` - Task pipeline with Turborepo caching
- `apps/api/Dockerfile` - Python 3.12-slim base, uv for deps

## Platform Requirements

**Development:**
- Node.js >=20.9.0 (recommend 22 per CI)
- pnpm 10.19.0
- Python 3.12 + uv
- Flutter stable channel (SDK ^3.6.0)
- PostgreSQL 16 (via Supabase or local)
- Redis (for API rate limiting)

**Production:**
- Web + Landing: Vercel (Next.js deployment)
- API: Google Cloud Run (asia-northeast3 region, 512Mi/1CPU, min 1 - max 10 instances)
- Database: Supabase PostgreSQL (with PgBouncer connection pooling)
- Container Registry: Google Artifact Registry (asia-northeast3)

---

*Stack analysis: 2026-03-26*
