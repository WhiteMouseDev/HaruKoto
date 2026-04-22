---
name: web-next16
description: Next.js 16.1 App Router conventions, server components, Turbopack, shared 패턴 for apps/web (learner), apps/admin (reviewer), apps/landing (marketing). Use when editing anything under apps/web, apps/admin, or apps/landing.
---

# Web / Admin / Landing — Next.js 16 Skill

Next.js 16.1 App Router 기반 3개 surface(apps/web, apps/admin, apps/landing)의 공통 패턴 + surface별 고유 UX 차이점을 정리합니다.

## App Router (공통)

- **Server Components 기본**. 상태/이벤트 필요 시에만 `"use client"`
- **`proxy.ts` 사용** (middleware.ts 아님 — Next.js 16 변경사항)
- `params`, `searchParams`는 반드시 `await`
- `cookies()`, `headers()`, `draftMode()` 비동기 호출
- Turbopack 기본 번들러
- Cache Components 활용 (`"use cache"` directive)

## 컴포넌트 (공통)

- 하나의 파일에 하나의 exported 컴포넌트
- 모바일 퍼스트 반응형 (sm → md → lg)
- semantic HTML + aria 속성 + 키보드 네비게이션
- 에러/로딩 처리: `error.tsx`, `loading.tsx`
- learner web과 marketing landing은 공통 UI 복사보다 **각 surface 목적에 맞는 정보 구조** 우선

## 디렉토리 구조 (apps/web 기준, admin/landing도 동일 패턴)

```
src/
├── app/
│   ├── (auth)/           # 인증 그룹 (web)
│   ├── (main)/           # 메인 앱 그룹 (web)
│   └── api/              # BFF API Routes (BFF만 허용 — api-plane-governance 참고)
├── components/
│   ├── ui/               # 기본 UI (shadcn)
│   ├── features/         # 기능별 컴포넌트
│   └── layouts/
├── hooks/                # 커스텀 훅 (use-*.ts)
├── lib/
├── stores/               # Zustand
├── styles/
└── types/                # 앱 전용 타입
```

## 상태 관리

- 서버 상태: TanStack Query (`src/hooks/use-*.ts` + `src/lib/query-keys.ts`)
- 클라이언트 상태: Zustand (`src/stores/`, 최소 사용)
- 폼: React Hook Form + Zod

## 성능

- 이미지: Next.js Image 컴포넌트
- 번들: dynamic import 활용
- 렌더링: ISR/SSG 우선, 필요 시 SSR
- landing은 정적 우선, web은 auth/data 경계 고려한 server-first

## Monorepo 임포트

```typescript
import type { User, Quiz } from '@harukoto/types';
import { prisma } from '@harukoto/database';
import { createChatCompletion } from '@harukoto/ai';
```

## Surface별 UX 차이 (admin 전용)

- reviewer/admin 흐름은 **인증 실패, 권한 부족, 빈 상태를 명시적으로** 드러낼 것
- reviewer 도구는 속도보다 **정확성** 우선
- queue navigation, approve/reject, audit trail은 키보드 접근성 + 로딩 상태 항상 제공
- destructive action은 낙관적 UI보다 **확인 가능한 결과와 에러 복구** 우선
- `next-intl` 번역 키는 기능 단위로 응집, 문자열 fallback을 코드에 흩뿌리지 말 것
- admin 전용 컴포넌트에서 **학습자-facing web 패턴을 복사하지 말고** reviewer workflow에 맞게 단순화
- admin의 공유 도메인 타입은 `@harukoto/types`, DB 접근은 `@harukoto/database` 우선

## 검증 커맨드

```bash
pnpm --filter @harukoto/<app> lint
pnpm --filter @harukoto/<app> typecheck
pnpm --filter @harukoto/<app> test
# route/auth/shared package contract 변경 시:
pnpm --filter @harukoto/<app> build
```
