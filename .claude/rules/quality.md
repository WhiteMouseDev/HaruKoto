---
alwaysApply: true
---

# 코드 품질 규칙

## TypeScript
- strict 모드 필수
- `any` 타입 사용 금지 (불가피한 경우 주석으로 이유 명시)
- interface보다 type alias 선호 (확장 필요 시 interface)
- 파일명: kebab-case (`user-profile.tsx`)
- 컴포넌트명: PascalCase (`UserProfile`)
- 함수/변수명: camelCase (`getUserData`)
- 상수: UPPER_SNAKE_CASE (`MAX_RETRY_COUNT`)

## 테스트
- 모든 유틸 함수: 단위 테스트 필수
- 주요 컴포넌트: 통합 테스트
- 핵심 사용자 플로우: E2E 테스트
- 테스트 파일: `__tests__/` 또는 `*.test.ts(x)`
- 네이밍: `describe('기능명')` → `it('should 동작')` 패턴

## 커밋 전 필수
- 변경된 앱의 lint 실행 후 에러 없음 확인
- TypeScript workspace 변경 시 `pnpm typecheck`
- Backend: `cd apps/api && uv run ruff check app/ tests/ && uv run ruff format --check app/ tests/`
- Frontend/Admin/Landing: `pnpm lint && pnpm typecheck`
- Mobile: `cd apps/mobile && dart format --set-exit-if-changed lib/ test/ && flutter analyze`
