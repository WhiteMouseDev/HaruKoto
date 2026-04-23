---
created: 2026-04-23
author: previous-session-handoff
status: pending
resume_command: null
---

# 다음 세션 브리프 — Admin ↔ API 일치성 감사

> `/clear` 후 새 세션이 읽고 이어갈 작업. 세션 시작 시 이 파일 읽고 진행.

## 목적

**apps/admin (Next.js 어드민)이 apps/api (FastAPI)와 실제로 일치하는지, 모든 기능이 작동하는지, 설계·구현 잘못된 부분이 있는지 전수 점검.**

배경: 지난 며칠 동안 AI 하네스 구축 + 검증에 집중했고, 그 과정에서 **모바일 ↔ API 드리프트는 `validate_mobile_contracts.py`로 자동화**했지만 **어드민은 같은 수준으로 점검한 적 없음**. 어드민은 1-3명 원어민 친구들이 학습 데이터 검증에 쓰는 프로덕션 도구 — 조용히 깨진 기능이 있으면 데이터 품질에 직접 영향.

## 스코프

### 기본 체크 (필수)

1. **엔드포인트 일치성**
   - `apps/admin/src/**` 에서 호출하는 모든 API 경로 추출
   - `apps/api/openapi/openapi.json` 대조
   - orphaned 호출 (존재하지 않는 엔드포인트) 발견
   - 모바일과 동일한 패턴 — 새 `validate_admin_contracts.py` 스크립트 필요할 수도

2. **요청/응답 스키마 일치성**
   - Admin이 보내는 페이로드 vs FastAPI Pydantic 스키마
   - Admin이 기대하는 응답 타입 vs FastAPI 응답 모델
   - `@harukoto/types` 생성 타입 활용 여부 확인 (현재 수동 타입이면 드리프트 리스크)

3. **기능 작동성**
   - 각 어드민 페이지 별로 핵심 흐름이 실제 돌아가는지
   - Placeholder 또는 "준비 중" 상태 UI 식별 (subscription/subscribe 케이스 같은 dead code)
   - 권한 체크: reviewer role 없는 계정이 접근 시 정상 차단

4. **에러 처리 일관성**
   - Admin이 처리하는 에러 코드/메시지 vs API가 실제 반환하는 것
   - 한국어 사용자 메시지 vs 영어 로그 분리 지켜지는지
   - Toast/modal 에러 UI가 실제 에러 시나리오에서 작동

5. **Admin 전용 엔드포인트 검증**
   - FastAPI의 `/api/v1/admin/**` 라우트가 모두 어드민에서 사용되는지
   - 사용 안 되는 관리자 엔드포인트는 dead code일 가능성 (backend 정리 대상)

### 확장 체크 (선택)

- 인증 플로우: Supabase reviewer claim → FastAPI JWT 검증 → admin UI 권한 분기
- RLS (Row Level Security) 정책 vs admin이 기대하는 데이터 범위
- CORS 설정 (admin 도메인 화이트리스트)
- Rate limit이 admin 엔드포인트에도 걸리는지 / 걸리지 말아야 하는지

## 산출물

**Report**: `.planning/audits/2026-04-23-admin-api-consistency.md` (새 경로)

구조:
1. Orphaned endpoint 리스트
2. 스키마 드리프트 리스트 (필드별)
3. 작동 안 하는 기능 / dead code UI
4. 에러 처리 불일치
5. Admin-only 엔드포인트 중 사용 안 되는 것
6. 권장 수정 작업 (P0/P1/P2 분류)

**혹은** — 발견되는 게 적으면 단순 체크리스트 마크다운 한 장.

## 관련 파일/참고

### 코드
- `apps/admin/src/app/` — Next.js App Router 페이지
- `apps/admin/src/hooks/` — API 호출 훅 (TanStack Query)
- `apps/admin/src/lib/api.ts` 또는 유사 — HTTP 클라이언트
- `apps/api/app/routers/` — FastAPI 엔드포인트, 특히 `admin*` 파일
- `apps/api/openapi/openapi.json` — SSOT

### 이미 있는 도구
- `apps/api/scripts/validate_mobile_contracts.py` — 모바일용 드리프트 검증기. 어드민용으로 포팅 가능한 참고 구현
- `packages/types/src/generated/api.ts` — OpenAPI에서 생성된 TypeScript 타입. 어드민이 이걸 얼마나 쓰는지 확인할 것

### 도메인 에이전트
- `web-agent` (apps/admin 담당) — 실제 수정 필요 시 이 에이전트에게 위임
- `backend-agent` — API 쪽 수정 필요 시
- `shared-packages-agent` — 공유 타입 조정 필요 시

### 교차 검증
- 작업 중간/마무리에 Codex에게 감사 결과 교차 검증 요청 (`mcp__codex__codex`)
- 어제 `f9c5aab` 커밋에서 subscription drift 케이스처럼 실제 버그 나오면 그 패턴대로 처리

## 프로세스 제안

1. **조사** (30~60분): web-agent와 backend-agent의 read-only 모드 활용하거나, 메인 세션에서 직접. Grep으로 admin의 API 호출 전수 추출 + OpenAPI와 교차 대조
2. **분류** (15~30분): 발견 사항을 P0 (유저 영향 있는 bug) / P1 (드리프트, 작동은 함) / P2 (cosmetic) 분류
3. **사용자 승인 게이트**: 발견 사항 목록 제시 → 어떤 것부터 고칠지 사용자 결정
4. **실행** (가변): 수정은 도메인 에이전트에게 위임. 크로스 도메인 작업이면 GSD phase로 승격
5. **재검증**: 수정 후 auditor 재실행 → drift 0 확인
6. **commit + push + CI**

## 시작 명령 (새 세션에서)

```
이 파일 읽고 작업 이어가줘: .planning/next-session-brief.md
```

또는 GSD 사용 시:
```
/gsd:discuss-phase admin-api-consistency-audit
(이 브리프 내용 참고해서 phase 만들어줘)
```

## 주의사항 및 컨텍스트

- **하네스가 완비된 상태**. 도메인 에이전트 4개, skills, hooks, PR 템플릿, gitleaks 모두 작동 중. 하네스 재구축 금지.
- **CI는 green, 미해결 UAT/TODO/에스컬레이션 0건**. 밤새 Codex가 모바일 리팩토링 8건 수행했지만 하네스가 경계 지켜줌.
- **Contract Sync 체크리스트** 적용: 이 감사 중 백엔드 수정이 생기면 `export_openapi.py` + `gen:api` + `validate_mobile_contracts.py` 필수
- 이전 세션 관련 커밋: `f9c5aab` (subscription drift fix — 비슷한 패턴), `8efd767` (contract pipeline), `8ef9f96` (Phase-2 hardening), `33b0bb0` (블로그 드래프트)

## 완료 시 처리

- 이 파일(`.planning/next-session-brief.md`) 삭제 또는 `resolved/` 로 이동
- 산출물 report 커밋
- MEMORY.md에서 pending-audit 엔트리 제거 (다음 단계 참고)
