# External Integrations

**Analysis Date:** 2026-03-26

## APIs & External Services

**AI / Language Models:**
- Google Gemini - Primary AI provider for chat, quiz generation, TTS, STT
  - SDK (Web): `@google/genai` ^1.0.0 + `@ai-sdk/google` ^1.2.0 via `packages/ai/src/provider.ts`
  - SDK (API): `google-genai` >=1.0 via `apps/api/app/config.py`
  - Models: `gemini-2.5-flash` (chat), `gemini-2.5-flash-preview-tts` (TTS)
  - Auth (Web): `GOOGLE_GENERATIVE_AI_API_KEY`
  - Auth (API): `GOOGLE_API_KEY`
- OpenAI - Secondary/fallback AI provider
  - SDK: `@ai-sdk/openai` ^1.3.0 via `packages/ai/src/provider.ts`
  - Model: `gpt-4o-mini`
  - Auth: `OPENAI_API_KEY`
  - Selection: `AI_PROVIDER` env var (`google` | `openai`, default: `openai`)
- ElevenLabs - Text-to-speech (API only)
  - SDK: `elevenlabs` >=2.39.0
  - Auth: `ELEVENLABS_API_KEY`, `ELEVENLABS_VOICE_ID`, `ELEVENLABS_MODEL_ID`
  - Model default: `eleven_flash_v2_5`

**AI Abstraction Layer:**
- `packages/ai/src/provider.ts` - Unified provider switching
  - `getAIProvider()` - Returns Vercel AI SDK `LanguageModelV1` (Google or OpenAI)
  - `generateTTS()` - Gemini-based TTS (PCM 24kHz, 16-bit, mono)
  - `transcribeAudio()` - Gemini-based STT (Japanese)
  - `getGoogleGenAIAlpha()` - v1alpha API for Live API ephemeral tokens

**Payment:**
- PortOne V2 - Korean payment gateway (card payments, billing)
  - SDK (Web): `@portone/browser-sdk` ^0.1.3
  - Auth (Web): `NEXT_PUBLIC_PORTONE_STORE_ID`, `PORTONE_CHANNEL_KEY`, `PORTONE_BILLING_CHANNEL_KEY`, `PORTONE_V2_SECRET_KEY`, `PORTONE_WEBHOOK_SECRET`
  - Auth (API): `PORTONE_API_SECRET`, `PORTONE_STORE_ID`, `PORTONE_CHANNEL_KEY`, `PORTONE_WEBHOOK_SECRET`
  - Routers: `apps/api/app/routers/payments.py`, `apps/api/app/routers/subscription.py`, `apps/api/app/routers/webhook.py`

**Analytics:**
- Google Analytics
  - Auth: `NEXT_PUBLIC_GA_ID` (e.g., `G-XXXXXXXXXX`)

## Data Storage

**Primary Database:**
- Supabase PostgreSQL 16
  - Connection (Web/Prisma): `DATABASE_URL` (via PgBouncer, port 6543), `DIRECT_URL` (direct, port 5432)
  - Connection (API/SQLAlchemy): `DATABASE_URL` (postgresql+asyncpg)
  - ORM (Web): Prisma ^6.5.0 - Schema at `packages/database/prisma/schema.prisma`
  - ORM (API): SQLAlchemy >=2.0 (asyncio) - Models at `apps/api/app/models/`
  - Migrations: Alembic >=1.14 (single DDL authority) - `apps/api/alembic/`
  - Prisma role: Read model + code generation + web runtime DML + seeding (NO DDL)
  - Schema sync: `pnpm db:sync` (pull from DB after Alembic migration)

**File Storage:**
- Google Cloud Storage (GCS)
  - SDK (Web): `@google-cloud/storage` ^7.19.0
  - Auth (Web): `GCS_BUCKET_NAME`, `GCS_CLIENT_EMAIL`, `GCS_PRIVATE_KEY`, `NEXT_PUBLIC_GCS_CDN_URL`
  - Auth (API): `GCS_BUCKET_NAME`, `GCS_CDN_BASE_URL`
  - Buckets: `harukoto-storage` (web), `harukoto-tts` (API TTS cache)
  - CDN URL: `https://storage.googleapis.com/harukoto-tts`

**Caching / Rate Limiting:**
- Redis >=5.2
  - Connection: `REDIS_URL` (default: `redis://localhost:6379`)
  - Used in API for rate limiting

## Authentication & Identity

**Auth Provider: Supabase Auth**
- Implementation: Multi-provider OAuth via Supabase
- Web client: `apps/web/src/lib/supabase/` (4 files: `client.ts`, `server.ts`, `admin.ts`, `auth.ts`)
- Mobile client: `supabase_flutter` ^2.8.0
- API verification: JWT validation via JWKS (ES256) at `{SUPABASE_URL}/auth/v1/.well-known/jwks.json`
- Fallback: Legacy HS256 via `SUPABASE_JWT_SECRET`

**OAuth Providers:**
- Google Sign-In
  - Web: Configured in Supabase dashboard
  - Mobile: `google_sign_in` ^6.2.2
- Kakao
  - Web: `NEXT_PUBLIC_KAKAO_JS_KEY`, `KAKAO_REST_API_KEY`, `KAKAO_CLIENT_SECRET`
  - Mobile: `kakao_flutter_sdk_user` ^1.9.5
  - API: `KAKAO_REST_API_KEY`, `KAKAO_CLIENT_SECRET` (for token exchange)
- Apple Sign-In
  - Mobile: `sign_in_with_apple` ^7.0.1
  - Web: Configured in Supabase dashboard

**Auth Env Vars:**
- `NEXT_PUBLIC_SUPABASE_URL` - Supabase project URL (public)
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` - Supabase anon key (public, row-level security)
- `SUPABASE_SERVICE_ROLE_KEY` - Admin access (server-side only)
- `SUPABASE_URL` (API) - For JWKS URL construction

## Push Notifications

**Web Push (VAPID):**
- SDK (Web): `web-push` ^3.6.7
- SDK (API): `pywebpush` >=2.0
- Auth: `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT`/`VAPID_EMAIL`
- Client-side: `NEXT_PUBLIC_VAPID_PUBLIC_KEY`
- Routes: `apps/web/src/app/api/v1/push/`, `apps/api/app/routers/push.py`

**Mobile Notifications:**
- `flutter_local_notifications` ^18.0.1 - Local scheduled notifications

## Monitoring & Observability

**Error Tracking: Sentry**
- Web: `@sentry/nextjs` ^10.42.0
  - Config: `apps/web/sentry.client.config.ts`
  - DSN: `NEXT_PUBLIC_SENTRY_DSN`
  - Traces sample rate: 0.1, Replay on error: 1.0
  - Source maps uploaded and deleted after build
  - Auth: `SENTRY_ORG`, `SENTRY_PROJECT`, `SENTRY_AUTH_TOKEN`
- API: `sentry-sdk[fastapi]` >=2.54.0
  - DSN: `SENTRY_DSN`
- Mobile: `sentry_flutter` ^8.12.0
  - DSN: via `--dart-define=SENTRY_DSN=`

**Logs:**
- No centralized logging service detected
- Console/stdout logging (API: uvicorn default, Web: Next.js default)

## CI/CD & Deployment

**Monorepo CI: GitHub Actions**
- Config: `.github/workflows/ci.yml`
- Change detection: `dorny/paths-filter@v4` (frontend, backend, mobile)
- Jobs:
  - `frontend` - pnpm install, lint, build (Node 22)
  - `backend` - uv sync, ruff check/format, pytest (Python 3.12)
  - `api-contract` - OpenAPI spec export + breaking change detection (`oasdiff`)
  - `schema-drift` - Alembic migrations vs Prisma schema consistency (PostgreSQL 16 service container)
  - `mobile` - flutter pub get, dart format, flutter analyze, flutter test, build debug APK
- Caching: Turborepo cache, pnpm cache, pub cache

**Web Hosting: Vercel**
- Auto-deploy from main branch (inferred from Next.js + Vercel AI SDK usage)
- Cron jobs: `apps/web/src/app/api/cron/` (authenticated via `CRON_SECRET`)

**API Deployment: Google Cloud Run**
- Config: `.github/workflows/deploy-api.yml`
- Region: asia-northeast3 (Seoul)
- Auth: GCP Workload Identity Federation (OIDC, no service account keys)
- Container: Python 3.12-slim + uv, port 8000
- Scaling: min 1, max 10 instances, 512Mi RAM, 1 CPU
- Secrets: Google Secret Manager (20+ secrets mapped)
- Registry: Google Artifact Registry (asia-northeast3)

**Mobile:**
- CI builds debug APK on GitHub Actions
- Production builds: Not automated (manual release assumed)

## Webhooks & Callbacks

**Incoming:**
- PortOne payment webhooks - `apps/api/app/routers/webhook.py`
  - Auth: `PORTONE_WEBHOOK_SECRET` for signature verification
- Vercel Cron - `apps/web/src/app/api/cron/`
  - Auth: `CRON_SECRET` header verification

**Outgoing:**
- Web Push notifications (VAPID) to browser subscription endpoints
- Google Gemini API calls (chat, TTS, STT)
- ElevenLabs API calls (TTS)
- PortOne API calls (payment verification, billing)

## Environment Configuration Summary

**Web (`apps/web/.env.example`) - Required:**
| Variable | Purpose |
|----------|---------|
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase project URL |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Supabase public key |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase admin key |
| `DATABASE_URL` | PostgreSQL via PgBouncer |
| `DIRECT_URL` | PostgreSQL direct connection |
| `AI_PROVIDER` | `google` or `openai` |
| `GOOGLE_GENERATIVE_AI_API_KEY` | Gemini API key |
| `NEXT_PUBLIC_KAKAO_JS_KEY` | Kakao JS SDK key |
| `VAPID_PUBLIC_KEY` / `VAPID_PRIVATE_KEY` | Web Push keys |
| `NEXT_PUBLIC_PORTONE_STORE_ID` | PortOne store ID |
| `PORTONE_V2_SECRET_KEY` | PortOne server secret |
| `GCS_BUCKET_NAME` / `GCS_CLIENT_EMAIL` / `GCS_PRIVATE_KEY` | Cloud Storage |
| `NEXT_PUBLIC_SENTRY_DSN` | Sentry error tracking |
| `CRON_SECRET` | Cron job authentication |

**API (`apps/api/.env.example`) - Required:**
| Variable | Purpose |
|----------|---------|
| `DATABASE_URL` | PostgreSQL (asyncpg) |
| `SUPABASE_URL` | JWKS endpoint base |
| `GOOGLE_API_KEY` | Gemini AI |
| `ELEVENLABS_API_KEY` | TTS service |
| `GCS_BUCKET_NAME` / `GCS_CDN_BASE_URL` | TTS audio storage |
| `PORTONE_API_SECRET` | Payment verification |
| `REDIS_URL` | Rate limiting |
| `VAPID_PRIVATE_KEY` / `VAPID_PUBLIC_KEY` | Push notifications |
| `CORS_ORIGINS` | Allowed origins |
| `SENTRY_DSN` | Error tracking |

**Mobile (dart-define at build time):**
| Variable | Purpose |
|----------|---------|
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_ANON_KEY` | Supabase public key |
| `API_BASE_URL` | FastAPI backend URL |
| `SENTRY_DSN` | Error tracking |

**Secrets Management:**
- Development: `.env` files (git-ignored)
- Production (API): Google Secret Manager (referenced in Cloud Run deploy)
- Production (Web): Vercel environment variables
- CI: GitHub Actions secrets

## Spaced Repetition

**FSRS (Free Spaced Repetition Scheduler):**
- SDK: `fsrs` >=6.3.1 (Python)
- Feature flag: `FSRS_ENABLED` (default: false)
- Location: `apps/api/app/config.py`

---

*Integration audit: 2026-03-26*
