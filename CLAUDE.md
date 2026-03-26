# 하루코토 (HaruKoto / ハルコト) - 일본어 학습 앱

## 프로젝트 개요

한국인을 위한 재미있는 일본어 학습 앱. JLPT 시험 대비 + AI 실전 회화 연습.

- **하루**: 한국어 "하루"(1일) + 일본어 "春"(봄)
- **코토**: 일본어 "言"(말/단어)
- 상세 기획: `docs/product/prd.md`
- 문서 인덱스: `docs/README.md`

## 기술 스택

- **Monorepo**: Turborepo + pnpm workspace
- **Framework**: Next.js 16.1 (App Router, Turbopack)
- **Language**: TypeScript (strict mode)
- **Styling**: Tailwind CSS
- **UI**: shadcn/ui (Radix 기반)
- **서버 상태**: TanStack Query
- **클라이언트 상태**: Zustand
- **폼**: React Hook Form + Zod
- **테마**: next-themes (라이트 봄 테마 기본 / 다크 모드 지원)
- **애니메이션**: Framer Motion
- **DB/Auth**: Supabase (PostgreSQL + Auth)
- **ORM**: Prisma
- **AI**: Vercel AI SDK (초기: OpenAI/Gemini, 추후: Claude)
- **배포**: Vercel
- **테스트**: Vitest + Testing Library + Playwright (E2E)

## 프로젝트 구조 (Turborepo Monorepo)

```
harukoto/
├── apps/
│   ├── web/                  # Next.js 16.1 메인 학습 앱
│   ├── mobile/               # Flutter 모바일 앱
│   ├── api/                  # Python/FastAPI 백엔드
│   └── landing/              # 랜딩 페이지
├── packages/
│   ├── ui/                   # 공유 UI 컴포넌트 (shadcn 기반)
│   ├── types/                # 공유 타입 정의
│   ├── database/             # Prisma 스키마 + 클라이언트
│   ├── ai/                   # AI Provider 추상화 레이어
│   └── config/               # ESLint, TS, Tailwind 공유 설정
├── turbo.json
├── pnpm-workspace.yaml
└── package.json
```

## 팀 역할 (Claude Session Team)

| 역할 | 커맨드 | 설명 |
|---|---|---|
| PM | `/pm-review` | 기획 의도 감독, PRD 대비 체크 |
| Frontend Dev | `/develop` | UI, 페이지, 인터랙션 구현 |
| Backend Dev | `/develop` | API, DB, AI 통합 |
| QA | `/qa-test` | 단위/통합/E2E 테스트 |
| Code Reviewer | `/code-review` | 코드 품질, 보안 검토 |
| Codex Review | `/codex-review` | 교차 검증 (API 계약, 타입, 런타임) |
| CI Watch | `/ci-watch` | 푸시 후 CI 감시 + 자동 수정 |
| Sprint Plan | `/sprint-plan` | 스프린트 계획 |

## Git 브랜치 전략

- `main`: 프로덕션 배포 브랜치
- `develop`: 개발 통합 브랜치
- `feature/*`: 기능 개발 브랜치
- `fix/*`: 버그 수정 브랜치
- `hotfix/*`: 긴급 수정 브랜치

## 커밋 컨벤션 (Conventional Commits)

```
feat: 새로운 기능 추가
fix: 버그 수정
docs: 문서 변경
style: 코드 포맷팅 (기능 변경 없음)
refactor: 코드 리팩토링
test: 테스트 추가/수정
chore: 빌드, 설정 변경
```

## 핵심 개발 원칙

1. **올바른 접근법 우선**: 빠른 해결(quick fix)보다 근본 원인을 파악하고 올바른 방법으로 해결한다. 임시 우회 시 반드시 TODO + 근본 해결 계획을 문서화한다.
2. **Codex 교차 검증 필수**: 기능 구현/버그 수정 커밋 전에 Codex 교차 검증을 실행하고, P0/P1 피드백은 반드시 수정 후 커밋한다.

## 세부 규칙 참조

경로별/주제별 세부 규칙은 `.claude/rules/`에 분리되어 있습니다:

- `web.md` — Next.js 16.1, App Router, 컴포넌트, 상태 관리, 성능
- `mobile.md` — Flutter 빌드, 시트 안정화, device ID
- `api.md` — Python/FastAPI, ruff, API 계약
- `quality.md` — TypeScript 컨벤션, 테스트 패턴, lint 규칙
- `security.md` — 시크릿 관리, 입력 검증, 접근 제어
- `workflow.md` — Claude+Codex 협업 워크플로우, 리뷰 규칙

<!-- GSD:project-start source:PROJECT.md -->
## Project

**HaruKoto Admin — 학습 데이터 관리 도구**

하루코토(HaruKoto) 일본어 학습 앱의 학습 데이터를 원어민이 검증·수정·TTS 재생성할 수 있는 어드민 웹 앱.
1-3명의 일본인 원어민 친구들이 단어, 문법, 퀴즈, 회화 시나리오 데이터의 품질을 관리한다.
apps/admin으로 메인 앱과 분리된 독립 Next.js 앱, Vercel 배포.

**Core Value:** 원어민이 학습 데이터를 쉽고 빠르게 검증·수정할 수 있어야 한다. 비개발자도 직관적으로 사용 가능해야 한다.

### Constraints

- **Tech Stack**: Next.js + Tailwind + shadcn/ui — 모노레포 내 기존 스택 통일
- **배포**: Vercel — 기존 인프라 활용
- **DB**: 기존 PostgreSQL(Supabase) 공유, DDL 변경은 Alembic만
- **인증**: Supabase Auth 활용, reviewer role 추가
- **TTS**: 기존 FastAPI TTS 엔드포인트 재사용
- **사용자 수**: 1-3명 소규모, 과도한 확장성 설계 불필요
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- TypeScript ^5.8+ - Web app (`apps/web`), landing page (`apps/landing`), shared packages (`packages/*`)
- Dart (SDK ^3.6.0) - Mobile app (`apps/mobile`)
- Python >=3.12 - Backend API (`apps/api`)
- SQL - Database migrations (`apps/api/alembic/versions/`), Prisma schema (`packages/database/prisma/schema.prisma`)
## Runtime
- Node.js >=20.9.0 (CI uses Node 22)
- Python 3.12
- Flutter stable channel (Dart SDK ^3.6.0)
- pnpm 10.19.0 - Node.js monorepo (lockfile: `pnpm-lock.yaml`)
- uv (latest) - Python deps (`apps/api/uv.lock`)
- Flutter pub - Dart deps (`apps/mobile/pubspec.lock`)
## Frameworks
- Next.js 16.1.6 - Web app + landing page (App Router, Turbopack, React Compiler enabled)
- React 19.2.3 - UI rendering
- FastAPI >=0.115 - Python backend API
- Flutter 3.x (stable) - Cross-platform mobile app
- Vitest ^4.0.18 - Web unit/integration tests (`apps/web/vitest.config.ts`)
- Testing Library (React ^16.3.2, jest-dom ^6.9.1) - Component testing
- pytest >=8.3 + pytest-asyncio >=0.25 - Python API tests
- Flutter test - Mobile unit tests
- Turborepo ^2.5.0 - Monorepo orchestration (`turbo.json`)
- Turbopack - Next.js dev bundler (default in Next.js 16)
- Hatchling - Python package build backend
- Docker - API containerization (`apps/api/Dockerfile`)
## Key Dependencies
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
- `radix-ui` ^1.4.3 - Headless UI primitives (via shadcn)
- `framer-motion` ^12.34.3 - Animations
- `lucide-react` ^0.575.0 - Icons
- `class-variance-authority` ^0.7.1 - Variant styling
- `tailwind-merge` ^3.5.0 - Tailwind class merging
- `clsx` ^2.1.1 - Conditional classes
- `sonner` ^2.0.7 - Toast notifications
- `next-themes` ^0.4.6 - Theme switching
- `sharp` ^0.34.5 - Image optimization
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
- Strict mode enabled (`packages/config/tsconfig.base.json`)
- `noUncheckedIndexedAccess: true`
- `isolatedModules: true`
- Shared base configs in `packages/config/`
- ESLint 9 + eslint-config-next 16.1.6 (web, landing)
- Prettier ^3.5.0 + prettier-plugin-tailwindcss ^0.7.2 (root)
- ruff >=0.9 (Python: lint + format, line-length 140, target py312)
- dart format + flutter analyze (mobile)
- mypy >=1.14 strict mode with pydantic plugin (Python type checking)
- `next.config.ts` - React Compiler enabled, Sentry integration, static asset caching
- `turbo.json` - Task pipeline with Turborepo caching
- `apps/api/Dockerfile` - Python 3.12-slim base, uv for deps
## Platform Requirements
- Node.js >=20.9.0 (recommend 22 per CI)
- pnpm 10.19.0
- Python 3.12 + uv
- Flutter stable channel (SDK ^3.6.0)
- PostgreSQL 16 (via Supabase or local)
- Redis (for API rate limiting)
- Web + Landing: Vercel (Next.js deployment)
- API: Google Cloud Run (asia-northeast3 region, 512Mi/1CPU, min 1 - max 10 instances)
- Database: Supabase PostgreSQL (with PgBouncer connection pooling)
- Container Registry: Google Artifact Registry (asia-northeast3)
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Naming Patterns
- Use kebab-case for all files: `use-quiz.ts`, `cloze-quiz.tsx`, `chat-message.tsx`
- Component files: `kebab-case.tsx` (e.g., `feedback-scores.tsx`)
- Hook files: `use-{feature}.ts` (e.g., `use-quiz.ts`, `use-voice-call.ts`)
- Test files: `{name}.test.ts` or `{name}.test.tsx` in `src/__tests__/`
- Utility files: `kebab-case.ts` in `src/lib/` (e.g., `spaced-repetition.ts`, `query-keys.ts`)
- Use snake_case for all files: `quiz.py`, `chat_data.py`, `kana_tts.py`
- Router files: `{domain}.py` in `app/routers/`
- Test files: `test_{domain}.py` in `tests/`
- Model files: `{domain}.py` in `app/models/`
- Use snake_case for all files: `character_model.dart`, `quiz_session_provider.dart`
- Model files: `{name}_model.dart`
- Provider files: `{name}_provider.dart`
- Test files mirror source path: `test/features/{feature}/data/models/{name}_model_test.dart`
- PascalCase exports: `export function ClozeQuiz(...)`, `export function ChatMessage(...)`
- One exported component per file
- camelCase for functions and variables: `calculateLevel`, `updateStreak`, `apiFetch`
- Use `type` alias over `interface` for props/data shapes: `type ClozeQuizProps = { ... }`
- snake_case for functions and variables: `get_current_user`, `check_and_grant_achievements`
- PascalCase for Pydantic models and SQLAlchemy models: `User`, `QuizType`
- UPPER_SNAKE_CASE: `ACHIEVEMENTS`, `MAX_RETRY_COUNT`
- PascalCase for type aliases: `QuizQuestion`, `StartQuizParams`, `AnswerState`
- Define types locally in the file that uses them (co-located types)
- Use string literal union types for state: `type AnswerState = 'idle' | 'correct' | 'incorrect'`
## Code Style
- Prettier (v3.5+) with config at `.prettierrc`
- `semi: true` - always use semicolons
- `singleQuote: true` - single quotes for strings
- `tabWidth: 2` - 2 space indentation
- `trailingComma: "es5"` - trailing commas in ES5 positions
- `printWidth: 80` - max line width
- Tailwind CSS class sorting via `prettier-plugin-tailwindcss`
- Run: `pnpm format` (root level)
- Ruff (v0.9+) for both linting and formatting
- `line-length: 140`
- `target-version: "py312"`
- Run: `cd apps/api && uv run ruff format app/ tests/`
- `dart format` with default settings
- Run: `cd apps/mobile && dart format lib/ test/`
- ESLint 9 flat config at `apps/web/eslint.config.mjs`
- Extends `eslint-config-next/core-web-vitals` and `eslint-config-next/typescript`
- Run: `pnpm lint` (via Turborepo)
- Ruff rules: `["E", "F", "I", "N", "W", "UP", "B", "A", "SIM"]`
- Ignored: `B008` (FastAPI Depends pattern), `E402` (import order in main.py), `UP042` (StrEnum migration deferred)
- Per-file ignores: `app/main.py` ignores `E402`, `F401`
- mypy strict mode with `pydantic.mypy` plugin
- Run: `cd apps/api && uv run ruff check app/ tests/`
- Config at `apps/mobile/analysis_options.yaml`
- Base: `package:flutter_lints/flutter.yaml`
- Key rules enforced: `avoid_print`, `cancel_subscriptions`, `close_sinks`, `unawaited_futures`, `prefer_const_constructors`, `prefer_final_locals`, `prefer_single_quotes`, `always_declare_return_types`, `avoid_dynamic_calls`
- Run: `cd apps/mobile && flutter analyze`
## Import Organization
- `@/*` maps to `./src/*` (configured in `apps/web/tsconfig.json`)
- Standard library first, then third-party, then local app imports
- Ruff `I` rules enforce import sorting automatically
- Dart/Flutter SDK imports first
- Package imports second
- Relative project imports last
## Error Handling
- `apiFetch` wrapper throws `Error` with server error message or fallback `API error: {status}`
- Use `try/catch` in hooks; display errors via `toast()` from `sonner`
- TanStack Query `onError` callbacks for query/mutation error handling
- FastAPI `HTTPException` with `detail` string for API errors
- Korean error messages for user-facing errors: `"세션을 찾을 수 없습니다"` (Session not found)
- Pydantic validation errors return 422 automatically
- `ApiException` class with `fromResponse` factory for HTTP error parsing
- `userMessage` property provides localized Korean messages per status code
- Status code mapping: 400 -> "잘못된 요청입니다.", 401 -> "로그인이 필요합니다.", etc.
## Logging
## Comments
- Complex algorithm explanations (e.g., XP calculation formulas in test comments)
- Korean-language comments for domain logic explanation
- Ruff ignore comments include reason: `"B008",   # Depends() in function defaults — FastAPI 패턴`
- Not widely used in web codebase; types serve as documentation
- Python docstrings used in test functions: `"""Test POST /api/v1/quiz/start creates a quiz session."""`
## Function Design
- Destructured props with explicit type: `export function ClozeQuiz({ questions, onAnswer, onComplete }: ClozeQuizProps)`
- Callback props prefixed with `on`: `onSend`, `onHint`, `onComplete`, `onSelect`
- Hooks return object with named properties (TanStack Query pattern)
- Utility functions return typed objects: `calculateLevel(xp) => { level, currentXp, xpForNext }`
## Module Design
- Named exports preferred: `export function ClozeQuiz(...)`, `export function apiFetch(...)`
- No barrel files (`index.ts`) observed in feature directories
- Direct file imports: `import { ChatMessage } from '@/components/features/chat/chat-message'`
- FastAPI router instances: `router = APIRouter()`
- Service functions imported directly from service modules
## Component Patterns (Web)
- `'use client'` directive at top of file when needed (hooks, state, event handlers)
- Server Components are the default (no directive needed)
- Server state: TanStack Query with centralized query keys in `src/lib/query-keys.ts`
- Client state: Zustand stores in `src/stores/` (minimal usage - only `onboarding.ts` observed)
- Form state: React Hook Form + Zod validation
- shadcn/ui components in `src/components/ui/` (Radix-based)
- Feature components in `src/components/features/{feature}/`
- Utility: `cn()` helper combining `clsx` + `tailwind-merge` in `src/lib/utils.ts`
- Animations: Framer Motion with `motion.div` wrappers
## Component Patterns (Mobile/Flutter)
- Riverpod 3.x with `flutter_riverpod`
- Providers in `features/{feature}/providers/` directory
- Repository pattern: `features/{feature}/data/{feature}_repository.dart`
- Feature-first directory structure: `features/{feature}/{data,providers,presentation}/`
- Core utilities in `lib/core/`: auth, constants, network, router, services, settings, theme
- Shared widgets in `lib/shared/`
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## Pattern Overview
- Monorepo managed by Turborepo + pnpm workspaces
- Dual-ORM database access: Prisma (web runtime + static seeding) and SQLAlchemy (API runtime + lesson seeding)
- DDL authority belongs exclusively to Alembic (Python migrations); Prisma syncs via `pnpm db:sync`
- Supabase for authentication (JWT tokens) across all clients
- AI features powered by Vercel AI SDK + Google Gemini / OpenAI, abstracted in `@harukoto/ai` package
- Mobile app communicates with FastAPI backend; web app uses both Next.js API routes (BFF) and FastAPI
## Layers
- Purpose: Next.js 16.1 App Router with Server Components by default, `"use client"` where needed
- Location: `apps/web/src/app/`
- Contains: Pages, layouts, API route handlers
- Depends on: `@harukoto/database`, `@harukoto/ai`, Supabase client
- Used by: End users via browser/PWA
- Purpose: Flutter app with feature-based architecture using Riverpod for state management
- Location: `apps/mobile/lib/`
- Contains: Features (home, study, chat, kana, subscription, my, auth), core services
- Depends on: FastAPI backend via Dio HTTP client, Supabase Flutter SDK
- Used by: End users via iOS/Android
- Purpose: Browser cookie/session bridge, web-platform-specific features
- Location: `apps/web/src/app/api/v1/`
- Contains: Route handlers for quiz, chat, wordbook, payments, user, missions, auth
- Depends on: `@harukoto/database` (Prisma), `@harukoto/ai`, Supabase server client
- Used by: Web frontend only
- **Policy:** No new domain logic here; use FastAPI. BFF-only for auth bridging, web push, cron
- Purpose: Primary backend for business logic, shared by mobile and (increasingly) web
- Location: `apps/api/app/`
- Contains: Routers, services, models (SQLAlchemy), schemas (Pydantic), middleware
- Depends on: PostgreSQL via SQLAlchemy async, Supabase JWT verification, external APIs
- Used by: Mobile app, web app (migrating)
- `packages/database/`: Prisma client + schema + seed data
- `packages/ai/`: AI provider abstraction (OpenAI/Gemini), TTS, STT
- `packages/types/`: Shared TypeScript type definitions
- `packages/config/`: Shared ESLint, TS, Tailwind configs
## Data Flow
- Web server state: TanStack Query with custom hooks in `apps/web/src/hooks/`
- Web client state: Zustand store (currently only `apps/web/src/stores/onboarding.ts`)
- Mobile state: Riverpod providers in `lib/features/*/providers/`
## Key Abstractions
- Purpose: Abstract AI model selection between OpenAI and Google Gemini
- Files: `packages/ai/src/provider.ts`, `packages/ai/src/prompts.ts`
- Pattern: Factory function `getAIProvider()` returns `LanguageModelV1` based on `AI_PROVIDER` env var
- Also exposes `generateTTS()` and `transcribeAudio()` for voice features
- Purpose: Singleton Prisma client with dev-mode hot-reload protection
- Files: `packages/database/src/client.ts`
- Pattern: Global singleton pattern to prevent multiple Prisma instances in development
- Purpose: Server-side and client-side Supabase client creation for Next.js
- Files: `apps/web/src/lib/supabase/server.ts`, `apps/web/src/lib/supabase/client.ts`, `apps/web/src/lib/supabase/admin.ts`, `apps/web/src/lib/supabase/auth.ts`
- Pattern: `getUser()` and `requireUser()` wrappers for server components/route handlers
- Purpose: Authenticated HTTP client with token refresh
- Files: `apps/mobile/lib/core/network/dio_client.dart`, `apps/mobile/lib/core/network/auth_interceptor.dart`, `apps/mobile/lib/core/network/auth_refresh_client.dart`
- Pattern: Dio HTTP client with auth interceptor for automatic JWT injection
- Purpose: Encapsulate TanStack Query logic per domain
- Files: `apps/web/src/hooks/use-quiz.ts`, `apps/web/src/hooks/use-user.ts`, `apps/web/src/hooks/use-chat-history.ts`, etc. (28 hooks total)
- Pattern: Each hook manages server state for a specific feature using TanStack Query
## Entry Points
- Location: `apps/web/src/app/layout.tsx`
- Triggers: Browser request
- Responsibilities: Root layout with ThemeProvider, QueryProvider, PWA registration, Google Analytics, Toaster
- Location: `apps/web/src/app/(app)/layout.tsx`
- Triggers: Navigation to app routes
- Responsibilities: App shell with BottomNav, MainContent, ErrorBoundary
- Location: `apps/mobile/lib/main.dart`
- Triggers: App launch
- Responsibilities: Kakao SDK init, Supabase init, local notifications, sound/haptic services, Riverpod ProviderScope
- Location: `apps/api/app/main.py`
- Triggers: HTTP requests
- Responsibilities: CORS middleware, Sentry init, router registration (21 routers)
- Location: `apps/landing/src/app/`
- Triggers: Browser request to landing domain
- Responsibilities: Static marketing pages, privacy/terms
## Error Handling
- Web: `ErrorBoundary` component wraps app content; `error.tsx` files per route; `apiFetch()` in `apps/web/src/lib/api.ts` throws on non-OK responses
- Mobile: `api_exception.dart` in `apps/mobile/lib/core/network/` for HTTP error handling
- FastAPI: HTTPException with status codes; Sentry integration for unhandled errors
- Form validation: Zod schemas (web), Pydantic schemas (API)
## Cross-Cutting Concerns
- Web: Console-based (no structured logging framework)
- API: Python `logging` module; SQLAlchemy query logging in development
- Mobile: Sentry for error tracking
- Prisma: Query logging in development mode
- Web forms: React Hook Form + Zod
- API input: Pydantic BaseModel schemas in `apps/api/app/schemas/`
- Database: Prisma schema constraints + PostgreSQL check constraints
- Provider: Supabase Auth (Google OAuth, Kakao OAuth)
- Web: Cookie-based sessions via `@supabase/ssr`
- Mobile: Supabase Flutter SDK with local token storage
- API: JWT verification via `apps/api/app/dependencies.py` (`get_current_user`)
- Web: `apps/web/src/lib/rate-limit.ts`
- API: `apps/api/app/middleware/rate_limit.py`
- FSRS algorithm implementation in `apps/api/app/services/fsrs_shadow.py` and `apps/api/app/services/srs.py`
- Web fallback in `apps/web/src/lib/spaced-repetition.ts`
- Feature-flagged via `FSRS_ENABLED` setting
- XP/Level system in `apps/api/app/services/gamification.py` and `apps/web/src/lib/gamification.ts`
- Daily missions, streaks, achievements tracked in database
- PortOne V2 integration for Korean payment processing
- Webhook handling at `apps/web/src/app/api/v1/webhook/portone/`
- Subscription management in `apps/api/app/services/subscription.py`
<!-- GSD:architecture-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
