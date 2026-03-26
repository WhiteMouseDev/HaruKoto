# Testing Patterns

**Analysis Date:** 2026-03-26

## Test Frameworks

### Web (Next.js)

**Runner:**
- Vitest v4.0.18
- Config: `apps/web/vitest.config.ts`
- Environment: `jsdom`
- Globals: `true` (no need to import `describe`/`it` but codebase explicitly imports them)

**Assertion Library:**
- Vitest built-in `expect`
- `@testing-library/jest-dom/vitest` for DOM matchers (`.toBeInTheDocument()`, `.toBeDisabled()`)

**Component Testing:**
- `@testing-library/react` v16.3.2 (`render`, `screen`, `fireEvent`)

**Run Commands:**
```bash
cd apps/web && pnpm test        # Run all tests (vitest run)
cd apps/web && pnpm test:watch  # Watch mode (vitest)
cd apps/web && pnpm test:coverage  # Coverage (vitest run --coverage)
pnpm test                       # Run all via Turborepo
```

### API (FastAPI/Python)

**Runner:**
- pytest v8.3+
- pytest-asyncio v0.25+ with `asyncio_mode = "auto"`
- Config: `apps/api/pyproject.toml` `[tool.pytest.ini_options]`

**Coverage:**
- pytest-cov v6.0+

**HTTP Client:**
- httpx `AsyncClient` with `ASGITransport` for testing FastAPI app directly

**Run Commands:**
```bash
cd apps/api && uv run pytest tests/ -v --tb=short     # Run all tests
cd apps/api && uv run pytest tests/ --cov=app          # With coverage
```

### Mobile (Flutter)

**Runner:**
- `flutter_test` (built-in)
- `flutter_riverpod` for provider testing via `ProviderContainer`

**Run Commands:**
```bash
cd apps/mobile && flutter test          # Run all tests
cd apps/mobile && flutter test --coverage  # With coverage
```

## Test File Organization

### Web

**Location:** Centralized in `apps/web/src/__tests__/`

**Setup File:** `apps/web/src/__tests__/setup.ts`
```typescript
import '@testing-library/jest-dom/vitest';
```

**Test Files (8 files):**
- `apps/web/src/__tests__/api.test.ts` - API fetch utility tests
- `apps/web/src/__tests__/chat-components.test.tsx` - Chat UI component tests
- `apps/web/src/__tests__/stats-components.test.tsx` - Stats UI component tests
- `apps/web/src/__tests__/game-icon.test.tsx` - Game icon component tests
- `apps/web/src/__tests__/gamification.test.ts` - Gamification logic unit tests
- `apps/web/src/__tests__/spaced-repetition.test.ts` - SRS algorithm tests
- `apps/web/src/__tests__/constants.test.ts` - Constants validation tests
- `apps/web/src/__tests__/show-events.test.ts` - Event display logic tests

**Naming:** `{feature-name}.test.ts` or `{feature-name}.test.tsx`

**Include pattern (vitest.config.ts):** `src/**/*.test.{ts,tsx}`

### API

**Location:** `apps/api/tests/`

**Setup:** `apps/api/tests/conftest.py` (shared fixtures)

**Test Files (17 files):**
- `apps/api/tests/test_health.py` - Health endpoint
- `apps/api/tests/test_auth.py` - Authentication/onboarding
- `apps/api/tests/test_quiz.py` - Quiz session CRUD
- `apps/api/tests/test_smart_quiz.py` - Smart quiz generation
- `apps/api/tests/test_chat.py` - Chat/conversation endpoints
- `apps/api/tests/test_user.py` - User profile
- `apps/api/tests/test_wordbook.py` - Wordbook management
- `apps/api/tests/test_kana.py` - Kana learning
- `apps/api/tests/test_gamification.py` - XP/achievements
- `apps/api/tests/test_missions.py` - Daily missions
- `apps/api/tests/test_cron.py` - Cron jobs
- `apps/api/tests/test_subscription_service.py` - Subscription service
- `apps/api/tests/test_subscription_router.py` - Subscription endpoints
- `apps/api/tests/test_webhook.py` - Payment webhooks
- `apps/api/tests/test_utils.py` - Utility functions

**Naming:** `test_{domain}.py`

### Mobile

**Location:** `apps/mobile/test/` mirroring `lib/` structure

**Test Files (48 files):**
- Model tests: `test/features/{feature}/data/models/{name}_model_test.dart` (20+ files)
- Provider tests: `test/features/{feature}/providers/{name}_provider_test.dart` (7 files)
- Presentation tests: `test/features/{feature}/presentation/{name}_test.dart` (4 files)
- Core tests: `test/core/{area}/{name}_test.dart` (5 files)
- Widget test: `test/widget_test.dart`

**Naming:** `{source_file_name}_test.dart`

## Test Structure

### Web - Unit Tests (utility functions)

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { calculateLevel } from '@/lib/gamification';

describe('calculateLevel', () => {
  it('should return level 1 for 0 XP', () => {
    const result = calculateLevel(0);
    expect(result.level).toBe(1);
    expect(result.currentXp).toBe(0);
    expect(result.xpForNext).toBe(100);
  });
});
```

### Web - Component Tests

```typescript
import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';

// Mock framer-motion before importing components
vi.mock('framer-motion', () => ({
  motion: {
    div: (props: React.ComponentProps<'div'>) => <div {...props} />,
  },
  AnimatePresence: ({ children }: React.PropsWithChildren) => <>{children}</>,
}));

describe('ChatMessage', () => {
  // Lazy-load component after mocks are set up
  async function loadChatMessage() {
    const mod = await import('@/components/features/chat/chat-message');
    return mod.ChatMessage;
  }

  it('should render AI message with translation', async () => {
    const ChatMessage = await loadChatMessage();
    render(<ChatMessage role="ai" messageJa="こんにちは" messageKo="안녕하세요" showTranslation={true} />);
    expect(screen.getByText('こんにちは')).toBeInTheDocument();
  });
});
```

**Key Pattern:** Components are dynamically imported (`await import(...)`) inside each test to ensure mocks are registered before module loading.

### API - Endpoint Tests

```python
import pytest
from unittest.mock import AsyncMock, MagicMock

@pytest.mark.asyncio
async def test_onboarding_success(client, mock_user):
    """Test successful onboarding with all fields."""
    response = await client.post(
        "/api/v1/auth/onboarding",
        json={
            "nickname": "하루학생",
            "jlptLevel": "N4",
            "dailyGoal": 15,
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert "profile" in data
    assert mock_user.nickname == "하루학생"
```

### Mobile - Model Tests

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/models/character_model.dart';

void main() {
  group('CharacterListItem', () {
    test('fromJson parses complete data', () {
      final json = { 'id': 'char-1', 'name': 'Yuki', ... };
      final model = CharacterListItem.fromJson(json);
      expect(model.id, 'char-1');
      expect(model.name, 'Yuki');
    });
  });
}
```

### Mobile - Provider Tests

```dart
void main() {
  group('QuizSessionController', () {
    test('initializes a standard quiz session', () async {
      final repository = _FakeStudyRepository();
      final container = ProviderContainer(
        overrides: [
          studyRepositoryProvider.overrideWith((ref) => repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(quizSessionProvider.notifier).initialize(...);
      final state = container.read(quizSessionProvider);
      expect(state.sessionId, 'start-session');
    });
  });
}
```

## Mocking

### Web (Vitest)

**Framework:** Vitest built-in `vi.mock()`, `vi.spyOn()`, `vi.fn()`

**Patterns:**

Global fetch mocking:
```typescript
vi.spyOn(globalThis, 'fetch').mockResolvedValue(
  new Response(JSON.stringify(mockData), { status: 200 })
);
```

Framer Motion mock (required for component tests):
```typescript
vi.mock('framer-motion', () => ({
  motion: {
    div: (props: React.ComponentProps<'div'>) => <div {...props} />,
  },
  AnimatePresence: ({ children }: React.PropsWithChildren) => <>{children}</>,
}));
```

**What to Mock:**
- `globalThis.fetch` for API calls
- `framer-motion` for animation components
- External libraries that depend on browser APIs

**What NOT to Mock:**
- Utility functions under test (test directly)
- React rendering (use Testing Library)

### API (Python)

**Framework:** `unittest.mock` (`AsyncMock`, `MagicMock`, `patch`)

**Patterns:**

FastAPI dependency override:
```python
async def override_get_db():
    mock_session = AsyncMock()
    yield mock_session

app.dependency_overrides[get_db] = override_get_db
app.dependency_overrides[get_current_user] = override_get_current_user
```

SQLAlchemy mock chain:
```python
mock_result = MagicMock()
mock_result.scalars.return_value.all.return_value = [mock_vocab]
mock_session.execute = AsyncMock(side_effect=[result1, result2, ...])
```

Decorator-based mocking:
```python
@patch("app.routers.quiz.check_and_grant_achievements")
async def test_complete_quiz(mock_achievements, client, ...):
    mock_achievements.return_value = []
```

**What to Mock:**
- Database sessions via FastAPI dependency overrides
- Authentication via `get_current_user` override
- External service calls (`patch`)

**What NOT to Mock:**
- Request/response serialization (test through full HTTP round-trip)
- Pydantic validation (let it run)

### Mobile (Flutter)

**Framework:** Fake implementations (no mockito observed)

**Patterns:**
```dart
final repository = _FakeStudyRepository();  // Hand-rolled fake
final container = ProviderContainer(
  overrides: [
    studyRepositoryProvider.overrideWith((ref) => repository),
  ],
);
addTearDown(container.dispose);
```

## Fixtures and Factories

### API (conftest.py)

**Shared fixtures at `apps/api/tests/conftest.py`:**

```python
@pytest.fixture
def test_user_id():
    return uuid.UUID("00000000-0000-0000-0000-000000000001")

@pytest.fixture
def mock_user(test_user_id):
    user = User(
        id=test_user_id,
        email="test@example.com",
        nickname="테스터",
        jlpt_level="N5",
        ...
    )
    return user

@pytest_asyncio.fixture
async def client(mock_user):
    # AsyncClient with dependency overrides
    ...
```

**Pattern:** Fixtures compose - `client` depends on `mock_user`, `mock_user` depends on `test_user_id`. Test-specific fixtures are defined in individual test files.

### Web

No shared fixture files. Test data is defined inline within each test or at describe-block scope:
```typescript
const defaultProps = {
  overallScore: 80,
  fluency: 75,
  accuracy: 85,
  ...
};
```

## Coverage

**Requirements:** No enforced coverage thresholds detected in any app.

**View Coverage:**
```bash
cd apps/web && pnpm test:coverage         # Web (Vitest)
cd apps/api && uv run pytest --cov=app    # API (pytest-cov)
cd apps/mobile && flutter test --coverage  # Mobile (Flutter)
```

## Test Types

### Unit Tests
- **Web:** Utility function tests (`gamification.test.ts`, `spaced-repetition.test.ts`, `api.test.ts`)
- **API:** Endpoint-level tests that mock DB (all test files)
- **Mobile:** Model `fromJson` parsing tests, `ApiException` tests, provider state tests

### Integration Tests
- **Web:** Component tests with Testing Library (`chat-components.test.tsx`, `stats-components.test.tsx`)
- **API:** Full request/response cycle through FastAPI app (ASGI transport, mocked DB)
- **Mobile:** Provider tests with `ProviderContainer` overrides

### E2E Tests
- **Not present.** Playwright is mentioned in CLAUDE.md as planned but no config or test files exist.

## CI Test Configuration

**File:** `.github/workflows/ci.yml`

**Change detection:** Uses `dorny/paths-filter@v4` to run only affected jobs.

**Frontend job:**
- Runs on `apps/web/**`, `packages/**`, `pnpm-lock.yaml`, `turbo.json` changes
- Steps: install -> lint -> build (no `pnpm test` step in CI currently)

**Backend job:**
- Runs on `apps/api/**`, `packages/database/**` changes
- Steps: install -> ruff check -> ruff format --check -> `uv run pytest tests/ -v --tb=short`

**Mobile job:**
- Runs on `apps/mobile/**` changes
- Steps: pub get -> dart format check -> flutter analyze -> `flutter test` -> build debug APK

**Additional CI jobs:**
- `api-contract`: OpenAPI breaking change detection with `oasdiff` (warning mode, `continue-on-error: true`)
- `schema-drift`: Alembic vs Prisma schema drift check against live PostgreSQL

## Common Patterns

### Async Testing (Web)

```typescript
it('should throw Error with server error message', async () => {
  vi.spyOn(globalThis, 'fetch').mockResolvedValue(
    new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
  );
  await expect(apiFetch('/api/test')).rejects.toThrow('Unauthorized');
});
```

### Async Testing (API)

```python
@pytest.mark.asyncio
async def test_health_check():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        response = await client.get("/health")
        assert response.status_code == 200
```

Note: `asyncio_mode = "auto"` in pytest config means `@pytest.mark.asyncio` is applied automatically, but existing tests still use the explicit decorator.

### Error Testing (Web)

```typescript
it('should throw Error with status code when error body is not JSON', async () => {
  vi.spyOn(globalThis, 'fetch').mockResolvedValue(
    new Response('not json', { status: 500 })
  );
  await expect(apiFetch('/api/test')).rejects.toThrow('Unknown error');
});
```

### Error Testing (API)

```python
async def test_answer_question_session_not_found(client, mock_user, test_user_id):
    mock_session = AsyncMock()
    mock_session.get = AsyncMock(return_value=None)
    # ... override dependency ...
    response = await client.post("/api/v1/quiz/answer", json={...})
    assert response.status_code == 404
    assert response.json()["detail"] == "세션을 찾을 수 없습니다"
```

## Notable Gaps

1. **Web tests not run in CI:** The frontend CI job runs lint and build but does NOT execute `pnpm test`. Tests exist but are not validated in CI.

2. **No E2E tests:** Playwright is listed as a planned tool but no configuration or test files exist.

3. **No web hook tests:** 28 custom hooks in `apps/web/src/hooks/` have zero test coverage. These contain critical business logic (quiz flows, voice calls, subscriptions).

4. **Limited web component test coverage:** Only chat and stats components are tested. Quiz components (`cloze-quiz.tsx`, `matching-pair.tsx`, etc.) have no tests.

5. **No coverage thresholds:** No minimum coverage enforced in any app.

6. **API contract check is non-blocking:** `continue-on-error: true` on the oasdiff step means breaking API changes do not fail CI.

---

*Testing analysis: 2026-03-26*
