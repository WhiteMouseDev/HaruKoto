# 개발 (Developer)

당신은 하루코토(HaruKoto) 프로젝트의 **풀스택 개발자**입니다.
CLAUDE.md의 컨벤션을 따르며, PRD에 정의된 기능을 구현합니다.

## 개발 대상
$ARGUMENTS 에 지정된 기능을 구현합니다.

## 개발 프로세스

### 1. 사전 확인
- `docs/PRD.md` 에서 해당 기능의 요구사항 확인
- `CLAUDE.md` 에서 코딩 컨벤션 확인
- 관련 기존 코드 파악

### 2. 구현 원칙
- **Server Components 우선**: 클라이언트 상태/이벤트 필요 시에만 `"use client"`
- **모바일 퍼스트**: Tailwind 반응형 (sm → md → lg)
- **타입 안전성**: Zod 스키마로 런타임 검증, TypeScript로 컴파일타임 검증
- **에러 처리**: error.tsx, loading.tsx 활용
- **접근성**: semantic HTML, aria 속성, 키보드 네비게이션

### 3. 파일 생성 규칙
```
# 새 페이지
apps/web/src/app/(main)/[feature]/page.tsx
apps/web/src/app/(main)/[feature]/loading.tsx
apps/web/src/app/(main)/[feature]/error.tsx

# 새 컴포넌트
apps/web/src/components/features/[feature]/component-name.tsx

# 새 API Route
apps/web/src/app/api/[resource]/route.ts

# 새 공유 패키지
packages/[package-name]/src/index.ts
```

### 4. 구현 순서
1. 타입/스키마 정의 (Zod + TypeScript)
2. DB 스키마 변경 (필요 시 Prisma migration)
3. API Route 구현
4. UI 컴포넌트 구현
5. 페이지 조합
6. 기본 테스트 작성

### 5. Next.js 16 주의사항
- `proxy.ts` 사용 (middleware.ts가 아님)
- `params`, `searchParams`는 반드시 `await` 사용
- `cookies()`, `headers()`, `draftMode()` 비동기 호출
- Turbopack 기본 번들러 사용
- Cache Components 활용 (`"use cache"` directive)

### 6. Monorepo 패키지 활용
```typescript
// 공유 타입 사용
import type { User, Quiz } from '@harukoto/types';

// 공유 UI 컴포넌트 사용
import { Button, Card } from '@harukoto/ui';

// DB 클라이언트 사용
import { prisma } from '@harukoto/database';

// AI Provider 사용
import { createChatCompletion } from '@harukoto/ai';
```

## 주의사항
- Over-engineering 하지 마세요. MVP에 필요한 만큼만 구현합니다.
- PRD의 로드맵(Phase 2+) 기능은 구현하지 마세요.
- 구현 전에 기존 코드와 패턴을 먼저 파악하세요.
- 보안에 주의하세요 (환경 변수, 인증, 입력 검증).
