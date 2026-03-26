# Codebase Structure

**Analysis Date:** 2026-03-26

## Directory Layout

```
harukoto/
├── apps/
│   ├── web/                    # Next.js 16.1 main learning app (PWA)
│   ├── mobile/                 # Flutter iOS/Android app
│   ├── api/                    # Python/FastAPI backend
│   └── landing/                # Next.js static landing page
├── packages/
│   ├── database/               # Prisma schema, client, seed data
│   ├── types/                  # Shared TypeScript type definitions
│   ├── ai/                     # AI provider abstraction (OpenAI/Gemini)
│   └── config/                 # Shared ESLint, TS, Tailwind configs
├── docs/                       # Product docs, architecture decisions, domain specs
├── .claude/                    # Claude Code rules and commands
├── .github/workflows/          # CI/CD pipelines
├── .planning/                  # GSD planning documents
├── turbo.json                  # Turborepo task configuration
├── pnpm-workspace.yaml         # Workspace definition
├── package.json                # Root scripts and dev dependencies
└── CLAUDE.md                   # Project overview for Claude
```

## Web App (`apps/web/`)

```
apps/web/
├── src/
│   ├── app/                    # Next.js App Router
│   │   ├── layout.tsx          # Root layout (ThemeProvider, QueryProvider, PWA)
│   │   ├── (app)/              # Authenticated app route group
│   │   │   ├── layout.tsx      # App shell (BottomNav, MainContent, ErrorBoundary)
│   │   │   ├── home/           # Dashboard/home page
│   │   │   ├── study/          # Study features
│   │   │   │   ├── quiz/       # Quiz sessions
│   │   │   │   ├── kana/       # Kana learning (hiragana/katakana)
│   │   │   │   │   ├── [type]/ # Dynamic: hiragana or katakana
│   │   │   │   │   │   ├── quiz/
│   │   │   │   │   │   └── stage/[number]/
│   │   │   │   │   └── chart/  # Kana chart reference
│   │   │   │   ├── wordbook/   # User's wordbook
│   │   │   │   ├── learned-words/
│   │   │   │   ├── wrong-answers/
│   │   │   │   └── result/     # Study result page
│   │   │   ├── chat/           # AI conversation
│   │   │   │   ├── [conversationId]/  # Active conversation
│   │   │   │   │   └── feedback/      # Conversation feedback
│   │   │   │   └── call/              # Voice call feature
│   │   │   │       ├── contacts/      # Character selection
│   │   │   │       └── analyzing/     # Post-call analysis
│   │   │   ├── subscription/   # Subscription management
│   │   │   │   ├── checkout/
│   │   │   │   └── success/
│   │   │   ├── pricing/        # Pricing page
│   │   │   ├── my/             # User profile
│   │   │   │   └── payments/   # Payment history
│   │   │   └── stats/          # Learning statistics
│   │   ├── auth/               # Authentication routes
│   │   │   ├── google/         # Google OAuth flow
│   │   │   │   └── complete/
│   │   │   ├── kakao/          # Kakao OAuth flow
│   │   │   │   ├── callback/
│   │   │   │   └── complete/
│   │   │   ├── callback/       # Supabase auth callback
│   │   │   └── signout/
│   │   └── api/v1/             # API route handlers (BFF)
│   │       ├── auth/onboarding/
│   │       ├── quiz/           # start, answer, complete, resume, stats, wrong-answers, recommendations, incomplete
│   │       ├── chat/           # start, message, end, tts, voice/transcribe, live-feedback, live-token, history, scenarios, characters, [conversationId]
│   │       ├── user/           # profile, avatar
│   │       ├── wordbook/[id]/
│   │       ├── study/          # learned-words, wrong-answers
│   │       ├── missions/       # today, claim
│   │       ├── payments/
│   │       └── webhook/portone/
│   ├── components/
│   │   ├── ui/                 # shadcn/ui primitives (button, card, dialog, tabs, etc.)
│   │   ├── features/           # Feature-specific components
│   │   │   ├── chat/           # Chat UI components
│   │   │   ├── quiz/           # Quiz UI components
│   │   │   ├── kana/           # Kana learning components
│   │   │   ├── dashboard/      # Home dashboard components
│   │   │   ├── stats/          # Statistics components
│   │   │   ├── subscription/   # Subscription UI
│   │   │   ├── wordbook/       # Wordbook components
│   │   │   ├── learned-words/  # Learned words components
│   │   │   ├── my/             # Profile/settings components
│   │   │   └── notifications/  # Notification components
│   │   ├── layout/             # Layout components (BottomNav, MainContent)
│   │   ├── providers/          # Context providers (ThemeProvider, QueryProvider, GoogleAnalytics)
│   │   └── brand/              # Brand/logo components
│   ├── hooks/                  # Custom React hooks (28 hooks)
│   ├── lib/                    # Utilities and services
│   │   ├── supabase/           # Supabase clients (server, client, admin, auth)
│   │   ├── api.ts              # Generic fetch wrapper
│   │   ├── query-keys.ts       # TanStack Query key constants
│   │   ├── gamification.ts     # XP/level calculations
│   │   ├── spaced-repetition.ts # SRS algorithm
│   │   ├── sounds.ts           # Sound effects
│   │   ├── rate-limit.ts       # Rate limiting utility
│   │   ├── subscription-service.ts
│   │   ├── subscription-constants.ts
│   │   ├── portone.ts          # Payment integration
│   │   ├── flutter-bridge.ts   # Mobile WebView bridge
│   │   ├── gcs.ts              # Google Cloud Storage
│   │   ├── web-push.ts         # Push notification utility
│   │   └── utils.ts            # General utilities
│   ├── stores/                 # Zustand stores
│   │   └── onboarding.ts       # Onboarding state
│   ├── types/                  # App-specific TypeScript types
│   └── __tests__/              # Test files
├── public/
│   ├── images/                 # Static images
│   ├── sounds/                 # Sound effect files
│   └── icons/                  # App icons (PWA)
└── package.json
```

## Mobile App (`apps/mobile/`)

```
apps/mobile/
├── lib/
│   ├── main.dart               # App entry point
│   ├── app.dart                # HarukotoApp widget
│   ├── core/                   # Shared infrastructure
│   │   ├── auth/               # Auth state management
│   │   ├── constants/          # App config, API URLs
│   │   ├── network/            # HTTP client (Dio), auth interceptor
│   │   ├── providers/          # Core Riverpod providers
│   │   ├── router/             # GoRouter configuration
│   │   ├── services/           # Local notifications, haptic, sound
│   │   ├── settings/           # Device settings repository
│   │   └── theme/              # App theme definitions
│   └── features/               # Feature modules (each has data/providers/presentation)
│       ├── home/               # Dashboard
│       ├── study/              # Study features
│       ├── chat/               # AI conversation
│       ├── auth/               # Login/registration
│       ├── kana/               # Kana learning
│       ├── subscription/       # Subscription management
│       ├── my/                 # User profile
│       ├── practice/           # Practice mode
│       ├── legal/              # Terms/privacy
│       ├── notifications/      # Notification management
│       └── stats/              # Learning statistics
├── test/                       # Test files (mirrors lib/ structure)
│   ├── core/                   # Core tests (settings, auth, network)
│   ├── features/               # Feature tests
│   └── shared/                 # Shared test utilities
├── ios/                        # iOS native project
├── android/                    # Android native project
└── pubspec.yaml                # Flutter dependencies
```

**Mobile Feature Module Pattern:**
Each feature in `lib/features/` follows a consistent structure:
```
feature_name/
├── data/
│   └── models/                 # Data models (fromJson/toJson)
├── providers/                  # Riverpod providers (state + API calls)
└── presentation/
    ├── feature_screen.dart     # Main screen widget
    └── widgets/                # Feature-specific widgets
```

## API Backend (`apps/api/`)

```
apps/api/
├── app/
│   ├── main.py                 # FastAPI app entry, router registration
│   ├── config.py               # Settings (Pydantic BaseSettings)
│   ├── dependencies.py         # Shared deps (get_current_user, JWT decode)
│   ├── routers/                # API route handlers (21 routers)
│   │   ├── auth.py             # Authentication, Kakao token exchange
│   │   ├── quiz.py             # Quiz endpoints
│   │   ├── chat.py             # AI chat endpoints
│   │   ├── chat_data.py        # Chat data (characters, scenarios)
│   │   ├── study.py            # Study progress
│   │   ├── lessons.py          # Lesson/chapter CRUD
│   │   ├── kana.py             # Kana learning
│   │   ├── kana_tts.py         # Kana TTS generation
│   │   ├── tts.py              # General TTS
│   │   ├── user.py             # User profile
│   │   ├── stats.py            # Statistics
│   │   ├── missions.py         # Daily missions
│   │   ├── achievements.py     # Achievement tracking
│   │   ├── wordbook.py         # Wordbook CRUD
│   │   ├── subscription.py     # Subscription management
│   │   ├── payments.py         # Payment processing
│   │   ├── webhook.py          # PortOne webhooks
│   │   ├── notifications.py    # Notifications
│   │   ├── push.py             # Push notifications
│   │   ├── cron.py             # Scheduled tasks
│   │   └── health.py           # Health check
│   ├── services/               # Business logic
│   │   ├── ai.py               # AI/LLM integration
│   │   ├── srs.py              # Spaced repetition (SM-2)
│   │   ├── fsrs_shadow.py      # FSRS algorithm (feature-flagged)
│   │   ├── gamification.py     # XP/level calculations
│   │   ├── distractor.py       # Quiz distractor generation
│   │   ├── portone.py          # Payment service
│   │   └── subscription.py     # Subscription logic
│   ├── models/                 # SQLAlchemy ORM models (16 files)
│   │   ├── user.py
│   │   ├── content.py          # Vocabulary, Grammar
│   │   ├── quiz.py
│   │   ├── conversation.py
│   │   ├── lesson.py
│   │   ├── stage.py
│   │   ├── progress.py         # User progress tracking
│   │   ├── kana.py
│   │   ├── gamification.py     # Missions, achievements
│   │   ├── subscription.py
│   │   ├── notification.py
│   │   ├── social.py           # AI characters
│   │   ├── tts.py
│   │   └── enums.py
│   ├── schemas/                # Pydantic request/response schemas
│   ├── seeds/                  # Database seeding scripts
│   ├── db/
│   │   └── session.py          # SQLAlchemy async engine + session factory
│   ├── middleware/
│   │   └── rate_limit.py       # Rate limiting
│   └── utils/                  # Utility functions
├── alembic/                    # Database migrations (DDL authority)
│   └── versions/               # Migration files
├── tests/                      # Pytest test files
├── openapi/                    # OpenAPI spec exports
├── scripts/                    # Utility scripts
└── pyproject.toml              # Python dependencies (uv)
```

## Shared Packages

**`packages/database/`:**
- Exports: Prisma client singleton, Prisma-generated types
- Key files: `src/client.ts`, `src/index.ts`, `prisma/schema.prisma`, `prisma/seed.ts`
- Data directory: `data/` contains JSON seed files for vocabulary, grammar, kana, scenarios, lessons, characters
- Import: `import { prisma } from '@harukoto/database'`

**`packages/types/`:**
- Exports: Shared TypeScript interfaces and types
- Key files: `src/index.ts`, `src/user.ts`, `src/quiz.ts`, `src/conversation.ts`, `src/content.ts`, `src/api.ts`, `src/gamification.ts`, `src/subscription.ts`
- Import: `import type { User, Quiz } from '@harukoto/types'`

**`packages/ai/`:**
- Exports: AI model provider factory, TTS, STT, prompts
- Key files: `src/provider.ts` (getAIProvider, generateTTS, transcribeAudio), `src/prompts.ts`, `src/index.ts`
- Import: `import { getAIProvider, generateTTS } from '@harukoto/ai'`

**`packages/config/`:**
- Exports: Shared configuration files for ESLint, TypeScript, Tailwind

## Key File Locations

**Entry Points:**
- `apps/web/src/app/layout.tsx`: Web root layout
- `apps/web/src/app/(app)/layout.tsx`: Authenticated app shell
- `apps/mobile/lib/main.dart`: Mobile app entry
- `apps/api/app/main.py`: FastAPI backend entry
- `apps/landing/src/app/layout.tsx`: Landing page layout

**Configuration:**
- `turbo.json`: Turborepo task definitions
- `pnpm-workspace.yaml`: Workspace packages
- `package.json`: Root scripts, postinstall Prisma generate
- `apps/web/package.json`: Web dependencies
- `apps/api/pyproject.toml`: Python dependencies
- `apps/mobile/pubspec.yaml`: Flutter dependencies
- `apps/api/app/config.py`: API settings (env vars)

**Database:**
- `packages/database/prisma/schema.prisma`: Full database schema (40+ models, 15+ enums)
- `apps/api/alembic/`: Migration files (DDL authority)
- `apps/api/app/models/`: SQLAlchemy ORM models
- `apps/api/app/db/session.py`: Async DB session factory

**Authentication:**
- `apps/web/src/lib/supabase/server.ts`: Server-side Supabase client
- `apps/web/src/lib/supabase/client.ts`: Client-side Supabase client
- `apps/web/src/lib/supabase/auth.ts`: Auth helpers (getUser, requireUser)
- `apps/api/app/dependencies.py`: JWT decode + get_current_user
- `apps/mobile/lib/core/auth/`: Mobile auth state

**AI Integration:**
- `packages/ai/src/provider.ts`: AI model factory, TTS, STT
- `packages/ai/src/prompts.ts`: System prompts for AI conversations
- `apps/api/app/services/ai.py`: Backend AI service

## Naming Conventions

**Files:**
- TypeScript/React: kebab-case (`use-quiz.ts`, `bottom-nav.tsx`, `query-keys.ts`)
- Python: snake_case (`chat_data.py`, `rate_limit.py`)
- Dart/Flutter: snake_case (`app_router.dart`, `dio_client.dart`)
- Components: kebab-case file, PascalCase export (`bottom-nav.tsx` → `BottomNav`)

**Directories:**
- Web routes: kebab-case matching URL segments (`learned-words/`, `wrong-answers/`)
- Web components: kebab-case feature folders (`features/chat/`, `features/quiz/`)
- Mobile: snake_case feature folders (`features/home/`, `features/study/`)
- API: snake_case (`routers/`, `services/`, `models/`)

## Where to Add New Code

**New Web Page:**
- Route: `apps/web/src/app/(app)/{feature-name}/page.tsx`
- Components: `apps/web/src/components/features/{feature-name}/`
- Hook: `apps/web/src/hooks/use-{feature-name}.ts`
- API route (if BFF needed): `apps/web/src/app/api/v1/{feature-name}/route.ts`

**New Mobile Feature:**
- Feature directory: `apps/mobile/lib/features/{feature_name}/`
- Data models: `apps/mobile/lib/features/{feature_name}/data/models/`
- Providers: `apps/mobile/lib/features/{feature_name}/providers/`
- Screens: `apps/mobile/lib/features/{feature_name}/presentation/`
- Tests: `apps/mobile/test/features/{feature_name}/`

**New API Endpoint:**
- Router: `apps/api/app/routers/{domain}.py`
- Schema: `apps/api/app/schemas/{domain}.py`
- Service (if complex logic): `apps/api/app/services/{domain}.py`
- Model (if new table): `apps/api/app/models/{domain}.py`
- Migration: `apps/api/alembic/versions/` (via `alembic revision --autogenerate`)

**New Shared Type:**
- TypeScript: `packages/types/src/{domain}.ts` and re-export from `packages/types/src/index.ts`

**New UI Component:**
- Primitive (shadcn): `apps/web/src/components/ui/{component-name}.tsx`
- Feature-specific: `apps/web/src/components/features/{feature}/`

**New Utility:**
- Web: `apps/web/src/lib/{utility-name}.ts`
- API: `apps/api/app/utils/`
- Mobile: `apps/mobile/lib/core/services/` or `apps/mobile/lib/core/`

## Special Directories

**`packages/database/data/`:**
- Purpose: JSON seed data for vocabulary, grammar, kana, scenarios, lessons, characters
- Generated: No (manually curated content)
- Committed: Yes

**`apps/api/alembic/`:**
- Purpose: Database migration files (sole DDL authority)
- Generated: Via `alembic revision --autogenerate`
- Committed: Yes

**`apps/web/public/`:**
- Purpose: Static assets (images, sounds, icons, PWA manifest)
- Generated: No
- Committed: Yes

**`apps/landing/out/`:**
- Purpose: Static export of landing page
- Generated: Yes (via `next build`)
- Committed: Yes (for deployment)

**`docs/`:**
- Purpose: Product docs, architecture decisions, domain specifications, operational docs
- Contains: `product/` (PRD, features, screens), `architecture/` (platform, voice, API, data), `domain/` (gamification, learning, content, billing), `decisions/`, `operations/`
- Committed: Yes

---

*Structure analysis: 2026-03-26*
