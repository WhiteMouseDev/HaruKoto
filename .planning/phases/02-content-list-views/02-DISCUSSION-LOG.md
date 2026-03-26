# Phase 2: Content List Views - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-26
**Phase:** 02-content-list-views
**Areas discussed:** 데이터 소스 & API, 목록 레이아웃 & 네비게이션, 검증 상태 표시 & 대시보드, 검색 & 필터링 UX

---

## 데이터 소스 & API

### 검증 상태 저장 방식

| Option | Description | Selected |
|--------|-------------|----------|
| 기존 테이블에 컬럼 추가 | Vocabulary, Grammar 등 각 테이블에 review_status 컬럼 추가 (Alembic migration). 조회 시 JOIN 없이 바로 필터링 가능 | ✓ |
| 별도 content_reviews 테이블 | content_type + content_id 로 링크하는 별도 테이블. Phase 3 audit log와 통합 가능하지만 쿼리 복잡도 증가 | |
| Claude가 판단 | DB 설계는 기술 결정이므로 리서치/플래닝에서 최적 방안 결정 | |

**User's choice:** 기존 테이블에 컬럼 추가
**Notes:** 현재 DB에 review_status 필드가 없는 것을 확인한 후 결정

### 콘텐츠 데이터 조회 방식

| Option | Description | Selected |
|--------|-------------|----------|
| FastAPI 엔드포인트 | admin 전용 FastAPI 엔드포인트 새로 작성 (/api/v1/admin/content). DDL은 Alembic, 쿼리는 SQLAlchemy | ✓ |
| Supabase 직접 조회 | admin 앱에서 Supabase JS SDK로 DB 직접 조회. API 서버 불필요하지만 보안 정책(RLS) 필요 | |
| Prisma 직접 조회 | Next.js Server Component에서 Prisma로 직접 조회. 모노레포 내 @harukoto/database 패키지 활용 | |

**User's choice:** FastAPI 엔드포인트
**Notes:** api-plane.md 정책(도메인 로직은 FastAPI 우선)과 일치

---

## 목록 레이아웃 & 네비게이션

### 목록 표시 형식

| Option | Description | Selected |
|--------|-------------|----------|
| 테이블 | 행/열 테이블로 한 눈에 많은 데이터 확인. 어드민 도구에 적합 | ✓ |
| 카드 그리드 | 카드 형태로 보여주는 방식. 시각적이지만 정보 밀도가 낮음 | |
| 하이브리드 | 기본 테이블 + 선택시 카드 확장. 복잡도 높음 | |

**User's choice:** 테이블

### 사이드바 네비게이션 구조

| Option | Description | Selected |
|--------|-------------|----------|
| 컨텐츠 타입별 메뉴 | 사이드바에 단어/문법/퀴즈/회화 4개 메뉴 + 대시보드. Phase 1의 D-04 결정대로 사이드바 추가 | ✓ |
| 탭 기반 네비게이션 | 상단 탭으로 콘텐츠 타입 전환. 사이드바 없이 단순한 구조 | |

**User's choice:** 컨텐츠 타입별 메뉴

### 페이지네이션 방식

| Option | Description | Selected |
|--------|-------------|----------|
| 페이지 번호 | 1, 2, 3... 페이지 번호 + 페이지당 20건. 특정 범위 데이터를 정확히 찾을 수 있음 | ✓ |
| 무한 스크롤 | 스크롤 시 데이터 추가 로드. 탐색용으로는 좋지만 특정 위치 찾기 어려움 | |

**User's choice:** 페이지 번호

---

## 검증 상태 표시 & 대시보드

### 검증 상태 뱃지 디자인

| Option | Description | Selected |
|--------|-------------|----------|
| 색상 뱃지 | needs_review=노란, approved=초록, rejected=빨간. 테이블 행에서 즉시 식별 가능 | ✓ |
| 아이콘+텍스트 | 색상 외에 아이콘도 함께 표시 (✓ ✗ ○). 색각 접근성 높음 | |

**User's choice:** 색상 뱃지

### 대시보드 통계 표시 방식

| Option | Description | Selected |
|--------|-------------|----------|
| 컨텐츠 타입별 카드 | 4개 카드에 각각 needs_review/approved/rejected 건수 + 진행률 바 | ✓ |
| 통합 요약 + 상세 테이블 | 상단에 전체 요약, 하단에 타입별 상세 테이블 | |

**User's choice:** 컨텐츠 타입별 카드

---

## 검색 & 필터링 UX

### 검색창 동작 방식

| Option | Description | Selected |
|--------|-------------|----------|
| Debounce 실시간 | 300ms debounce로 타이핑 중 자동 검색. 빠른 피드백 | ✓ |
| Submit 방식 | Enter/버튼 누를 때만 검색 실행. 서버 부하 적음 | |

**User's choice:** Debounce 실시간

### 필터 UI 배치

| Option | Description | Selected |
|--------|-------------|----------|
| 테이블 상단 인라인 | 검색창 + JLPT레벨 + 카테고리 + 상태 필터가 한 줄에. 선택하면 즉시 적용 | ✓ |
| 필터 패널/사이드바 | 별도 필터 패널에서 조건 설정 후 적용. 복잡한 필터에 적합하지만 클릭 수 많음 | |

**User's choice:** 테이블 상단 인라인

---

## Claude's Discretion

- FastAPI 어드민 엔드포인트 상세 설계
- Alembic migration 스크립트
- 테이블 컴포넌트 구조
- TanStack Query 캐싱 전략
- 사이드바 컴포넌트 반응형 동작

## Deferred Ideas

None
