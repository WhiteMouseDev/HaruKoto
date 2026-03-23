---
paths:
  - "apps/web/**"
  - "apps/landing/**"
  - "packages/ui/**"
---

# Web (Next.js 16.1) 규칙

## App Router
- Server Components 기본, 필요 시에만 `"use client"`
- `proxy.ts` 사용 (middleware.ts 아님 — Next.js 16 변경사항)
- `params`, `searchParams`는 반드시 `await` 사용
- `cookies()`, `headers()`, `draftMode()` 비동기 호출
- Turbopack 기본 번들러
- Cache Components 활용 (`"use cache"` directive)

## 컴포넌트
- 하나의 파일에 하나의 exported 컴포넌트
- 모바일 퍼스트 반응형 (sm → md → lg)
- semantic HTML + aria 속성 + 키보드 네비게이션
- 에러/로딩 처리: `error.tsx`, `loading.tsx` 활용

## 디렉토리 구조
```
src/
├── app/                  # App Router 페이지
│   ├── (auth)/           # 인증 관련 그룹
│   ├── (main)/           # 메인 앱 그룹
│   └── api/              # API Route Handlers
├── components/
│   ├── ui/               # 기본 UI (shadcn)
│   ├── features/         # 기능별 컴포넌트
│   └── layouts/          # 레이아웃
├── hooks/                # 커스텀 훅
├── lib/                  # 유틸리티
├── stores/               # Zustand 스토어
├── styles/               # 글로벌 스타일
└── types/                # 앱 전용 타입
```

## 상태 관리
- 서버 상태: TanStack Query (캐싱 전략 활용)
- 클라이언트 상태: Zustand
- 폼: React Hook Form + Zod

## 성능
- 이미지: Next.js Image 컴포넌트
- 번들 크기: dynamic import 활용
- 렌더링: ISR/SSG 우선, 필요 시 SSR

## Monorepo 임포트
```typescript
import type { User, Quiz } from '@harukoto/types';
import { prisma } from '@harukoto/database';
import { createChatCompletion } from '@harukoto/ai';
```
