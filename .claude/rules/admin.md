---
paths:
  - "apps/admin/**"
---

# Admin (Next.js 16.1) 규칙

## App Router
- Server Components 기본, 필요 시에만 `"use client"`
- `proxy.ts` 사용 (middleware.ts 아님)
- `params`, `searchParams`는 반드시 `await` 사용
- `cookies()`, `headers()`, `draftMode()` 비동기 호출
- reviewer/admin 흐름은 인증 실패, 권한 부족, 빈 상태를 명시적으로 드러낼 것

## UX
- reviewer 도구는 속도보다 정확성을 우선
- queue navigation, approve/reject, audit trail은 키보드 접근성과 로딩 상태를 항상 제공
- destructive action은 낙관적 UI보다 확인 가능한 결과와 에러 복구를 우선
- `next-intl` 번역 키는 기능 단위로 응집시키고 문자열 fallback을 코드에 흩뿌리지 말 것

## 구조
- admin 전용 컴포넌트에서 학습자-facing web 패턴을 복사하지 말고 reviewer workflow에 맞게 단순화
- shared domain 타입은 `@harukoto/types`, DB 접근은 `@harukoto/database`를 우선 사용
- API contract parsing은 admin 전용 ad hoc shape보다 명시적 타입과 helper를 우선 사용

## 검증
- lint: `pnpm --filter @harukoto/admin lint`
- typecheck: `pnpm --filter @harukoto/admin typecheck`
- test: `pnpm --filter @harukoto/admin test`
- route/auth/shared package contract 변경 시 build: `pnpm --filter @harukoto/admin build`
