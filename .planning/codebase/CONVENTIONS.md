# Coding Conventions

**Analysis Date:** 2026-03-26

## Naming Patterns

**Files (Web/TypeScript):**
- Use kebab-case for all files: `use-quiz.ts`, `cloze-quiz.tsx`, `chat-message.tsx`
- Component files: `kebab-case.tsx` (e.g., `feedback-scores.tsx`)
- Hook files: `use-{feature}.ts` (e.g., `use-quiz.ts`, `use-voice-call.ts`)
- Test files: `{name}.test.ts` or `{name}.test.tsx` in `src/__tests__/`
- Utility files: `kebab-case.ts` in `src/lib/` (e.g., `spaced-repetition.ts`, `query-keys.ts`)

**Files (API/Python):**
- Use snake_case for all files: `quiz.py`, `chat_data.py`, `kana_tts.py`
- Router files: `{domain}.py` in `app/routers/`
- Test files: `test_{domain}.py` in `tests/`
- Model files: `{domain}.py` in `app/models/`

**Files (Mobile/Flutter):**
- Use snake_case for all files: `character_model.dart`, `quiz_session_provider.dart`
- Model files: `{name}_model.dart`
- Provider files: `{name}_provider.dart`
- Test files mirror source path: `test/features/{feature}/data/models/{name}_model_test.dart`

**Components (Web):**
- PascalCase exports: `export function ClozeQuiz(...)`, `export function ChatMessage(...)`
- One exported component per file

**Functions/Variables (TypeScript):**
- camelCase for functions and variables: `calculateLevel`, `updateStreak`, `apiFetch`
- Use `type` alias over `interface` for props/data shapes: `type ClozeQuizProps = { ... }`

**Functions/Variables (Python):**
- snake_case for functions and variables: `get_current_user`, `check_and_grant_achievements`
- PascalCase for Pydantic models and SQLAlchemy models: `User`, `QuizType`

**Constants (TypeScript):**
- UPPER_SNAKE_CASE: `ACHIEVEMENTS`, `MAX_RETRY_COUNT`

**Types (TypeScript):**
- PascalCase for type aliases: `QuizQuestion`, `StartQuizParams`, `AnswerState`
- Define types locally in the file that uses them (co-located types)
- Use string literal union types for state: `type AnswerState = 'idle' | 'correct' | 'incorrect'`

## Code Style

**Formatting (Web/TypeScript):**
- Prettier (v3.5+) with config at `.prettierrc`
- `semi: true` - always use semicolons
- `singleQuote: true` - single quotes for strings
- `tabWidth: 2` - 2 space indentation
- `trailingComma: "es5"` - trailing commas in ES5 positions
- `printWidth: 80` - max line width
- Tailwind CSS class sorting via `prettier-plugin-tailwindcss`
- Run: `pnpm format` (root level)

**Formatting (API/Python):**
- Ruff (v0.9+) for both linting and formatting
- `line-length: 140`
- `target-version: "py312"`
- Run: `cd apps/api && uv run ruff format app/ tests/`

**Formatting (Mobile/Flutter):**
- `dart format` with default settings
- Run: `cd apps/mobile && dart format lib/ test/`

**Linting (Web/TypeScript):**
- ESLint 9 flat config at `apps/web/eslint.config.mjs`
- Extends `eslint-config-next/core-web-vitals` and `eslint-config-next/typescript`
- Run: `pnpm lint` (via Turborepo)

**Linting (API/Python):**
- Ruff rules: `["E", "F", "I", "N", "W", "UP", "B", "A", "SIM"]`
- Ignored: `B008` (FastAPI Depends pattern), `E402` (import order in main.py), `UP042` (StrEnum migration deferred)
- Per-file ignores: `app/main.py` ignores `E402`, `F401`
- mypy strict mode with `pydantic.mypy` plugin
- Run: `cd apps/api && uv run ruff check app/ tests/`

**Linting (Mobile/Flutter):**
- Config at `apps/mobile/analysis_options.yaml`
- Base: `package:flutter_lints/flutter.yaml`
- Key rules enforced: `avoid_print`, `cancel_subscriptions`, `close_sinks`, `unawaited_futures`, `prefer_const_constructors`, `prefer_final_locals`, `prefer_single_quotes`, `always_declare_return_types`, `avoid_dynamic_calls`
- Run: `cd apps/mobile && flutter analyze`

## Import Organization

**TypeScript (Web):**
1. React/Next.js framework imports: `import { useState, useCallback } from 'react'`
2. Third-party libraries: `import { motion, AnimatePresence } from 'framer-motion'`
3. Monorepo packages: `import type { User } from '@harukoto/types'`
4. Internal UI components: `import { Button } from '@/components/ui/button'`
5. Internal feature modules: `import { cn } from '@/lib/utils'`

**Path Aliases (Web):**
- `@/*` maps to `./src/*` (configured in `apps/web/tsconfig.json`)

**Python (API):**
- Standard library first, then third-party, then local app imports
- Ruff `I` rules enforce import sorting automatically

**Dart (Mobile):**
- Dart/Flutter SDK imports first
- Package imports second
- Relative project imports last

## Error Handling

**Web (TypeScript):**
- `apiFetch` wrapper throws `Error` with server error message or fallback `API error: {status}`
- Use `try/catch` in hooks; display errors via `toast()` from `sonner`
- TanStack Query `onError` callbacks for query/mutation error handling

**API (Python):**
- FastAPI `HTTPException` with `detail` string for API errors
- Korean error messages for user-facing errors: `"세션을 찾을 수 없습니다"` (Session not found)
- Pydantic validation errors return 422 automatically

**Mobile (Flutter):**
- `ApiException` class with `fromResponse` factory for HTTP error parsing
- `userMessage` property provides localized Korean messages per status code
- Status code mapping: 400 -> "잘못된 요청입니다.", 401 -> "로그인이 필요합니다.", etc.

## Logging

**Web:** `console` (no structured logging framework detected)

**API:** Sentry SDK (`sentry-sdk[fastapi]`) for error tracking; standard Python logging

**Mobile:** Sentry Flutter (`sentry_flutter`) for crash reporting; `debugPrint` enforced over `print` via lint rule `avoid_print`

## Comments

**When to Comment:**
- Complex algorithm explanations (e.g., XP calculation formulas in test comments)
- Korean-language comments for domain logic explanation
- Ruff ignore comments include reason: `"B008",   # Depends() in function defaults — FastAPI 패턴`

**JSDoc/TSDoc:**
- Not widely used in web codebase; types serve as documentation
- Python docstrings used in test functions: `"""Test POST /api/v1/quiz/start creates a quiz session."""`

## Function Design

**Size:** Keep functions focused. Components extract logic into hooks (`use-quiz.ts`, `use-voice-call.ts`).

**Parameters (Web Components):**
- Destructured props with explicit type: `export function ClozeQuiz({ questions, onAnswer, onComplete }: ClozeQuizProps)`
- Callback props prefixed with `on`: `onSend`, `onHint`, `onComplete`, `onSelect`

**Return Values:**
- Hooks return object with named properties (TanStack Query pattern)
- Utility functions return typed objects: `calculateLevel(xp) => { level, currentXp, xpForNext }`

## Module Design

**Exports (Web):**
- Named exports preferred: `export function ClozeQuiz(...)`, `export function apiFetch(...)`
- No barrel files (`index.ts`) observed in feature directories
- Direct file imports: `import { ChatMessage } from '@/components/features/chat/chat-message'`

**Exports (API/Python):**
- FastAPI router instances: `router = APIRouter()`
- Service functions imported directly from service modules

## Component Patterns (Web)

**Server vs Client Components:**
- `'use client'` directive at top of file when needed (hooks, state, event handlers)
- Server Components are the default (no directive needed)

**State Management:**
- Server state: TanStack Query with centralized query keys in `src/lib/query-keys.ts`
- Client state: Zustand stores in `src/stores/` (minimal usage - only `onboarding.ts` observed)
- Form state: React Hook Form + Zod validation

**UI Components:**
- shadcn/ui components in `src/components/ui/` (Radix-based)
- Feature components in `src/components/features/{feature}/`
- Utility: `cn()` helper combining `clsx` + `tailwind-merge` in `src/lib/utils.ts`
- Animations: Framer Motion with `motion.div` wrappers

## Component Patterns (Mobile/Flutter)

**State Management:**
- Riverpod 3.x with `flutter_riverpod`
- Providers in `features/{feature}/providers/` directory
- Repository pattern: `features/{feature}/data/{feature}_repository.dart`

**Architecture:**
- Feature-first directory structure: `features/{feature}/{data,providers,presentation}/`
- Core utilities in `lib/core/`: auth, constants, network, router, services, settings, theme
- Shared widgets in `lib/shared/`

---

*Convention analysis: 2026-03-26*
