# 하루코토 (HaruKoto) 앱 종합 분석 리포트

> 작성일: 2026-03-07
> 분석 팀: UX/Flow, Frontend, Backend/API, Architecture 4개 분야 병렬 분석
> 검증 전 발견 이슈: Critical 13건 / Major 19건 / Minor 15건+
> **검증 후 확정 이슈: Critical 5건 / Major 23건 / Minor 19건+**

---

## 목차

1. [Executive Summary](#1-executive-summary)
2. [Critical Issues (즉시 대응)](#2-critical-issues)
3. [Major Issues (1~2주 내 해결)](#3-major-issues)
4. [Minor Issues (지속적 개선)](#4-minor-issues)
5. [긍정 평가](#5-긍정-평가)
6. [우선순위 액션 플랜](#6-우선순위-액션-플랜)
7. [검증 결과](#7-검증-결과)
8. [검증 후 확정 액션 플랜](#8-검증-후-확정-액션-플랜)

---

## 1. Executive Summary

하루코토는 전반적으로 **잘 설계된 학습 앱**입니다. 온보딩이 명확하고, 홈 페이지의 정보 아키텍처가 우수하며, 학습 피드백이 풍부합니다. 하지만 **결제 보안, 데이터 정합성, 타입 안전성, 테스트/CI 인프라** 영역에서 프로덕션 배포 전 반드시 해결해야 할 Critical 이슈들이 발견되었습니다.

### 분야별 건강도

| 분야 | 점수 | 핵심 문제 |
|------|------|----------|
| UX/Flow | 7/10 | 에러 상태 불일관, 회화 진입장벽 높음 |
| Frontend | 6/10 | 렌더 루프 버그, 거대 컴포넌트, 접근성 부족 |
| Backend/API | 5/10 | 결제 보안 취약, 트랜잭션 분리, Rate Limiting |
| Architecture | 5/10 | CI/CD 전무, 환경변수 검증 없음, 설정 중복 |

---

## 2. Critical Issues

> 프로덕션 배포 전 반드시 해결 필요

### Backend/API

#### C-BE-1. 결제 금액 Tampering 취약점
**파일:** `apps/web/src/app/api/v1/subscription/activate/route.ts`

- PortOne 결제에서 금액만으로 plan 판별 → 변조된 데이터로 premium 활성화 가능
- Webhook에서도 동일한 취약점 존재
```typescript
// 위험: 금액만으로 plan 판별
const plan = portonePayment.amount.total === PRICES.YEARLY ? 'yearly' : 'monthly';
```
**조치:** paymentId + 서버 저장 plan 매핑으로 검증, idempotency key 추가

#### C-BE-2. Onboarding Auth/DB 트랜잭션 분리
**파일:** `apps/web/src/app/api/v1/auth/onboarding/route.ts`

- Supabase Auth update → Prisma User upsert 순차 실행
- 중간 실패 시 Auth/DB 불일치 → 사용자 접속 불가 또는 프로필 없음
**조치:** 단일 트랜잭션으로 통합하거나 idempotent 처리

#### C-BE-3. Webhook Replay Attack 취약성
**파일:** 결제 webhook 엔드포인트

- 시그니처 검증은 있으나 timestamp/nonce 검증 없음
- 동일 webhook 재전송 → 중복 구독 활성화 가능
**조치:** timestamp 5분 제한 + nonce 중복 체크

#### C-BE-4. AI 사용량 제한 누락
**파일:** voice transcribe, TTS, live-feedback 엔드포인트

- `/v1/chat/message`, `/v1/chat/start`는 `checkAiLimit()` 있음
- voice transcribe, TTS, live-feedback은 미적용 → 무료 사용자 AI 리소스 오버사용
**조치:** 모든 AI 엔드포인트에 `checkAiLimit()` 적용

---

### Frontend

#### C-FE-1. TypingQuiz 렌더 루프 버그
**파일:** TypingQuiz 관련 컴포넌트

- setTimeout이 렌더 중 실행되어 무한 상태 업데이트 가능
**조치:** useEffect 내부로 이동

#### C-FE-2. apiFetch 에러 핸들링 미흡
**파일:** `apps/web/src/lib/` 관련

- apiFetch 실패 시 일관된 에러 처리 부재
**조치:** 전역 에러 핸들러 패턴 적용

#### C-FE-3. QuizQuestion 타입 안전성 약화
**파일:** 퀴즈 관련 타입 정의

- optional 필드 남발로 런타임 에러 위험
- 디스크리미네이트 유니온으로 퀴즈 타입별 명확한 타입 분리 필요
**조치:** discriminated union으로 리팩토링

---

### Architecture

#### C-AR-1. 환경 변수 타입 안전성 부재
**파일:** 전체 프로젝트

- `process.env` 모든 접근이 `any` 타입 추론
- turbo.json globalEnv는 7개만 정의하지만 실제 50+ 변수 사용
- 누락된 환경 변수는 런타임에 `undefined` → 오류 발생
**조치:** Zod 기반 env 스키마 검증 (`@t3-oss/env-nextjs` 등)

#### C-AR-2. @harukoto/ui 패키지 미사용 (Dead Package)
**파일:** `packages/ui/src/index.ts`

- export가 비어있음, 앱에서 직접 `@/components/ui` 사용
- 모노레포 구조 혼란, 빌드 시간 낭비
**조치:** 패키지 제거 또는 shadcn/ui 컴포넌트 이전 계획 수립

#### C-AR-3. ESLint 설정 중복
**파일:** `apps/web/eslint.config.mjs`, `apps/landing/eslint.config.mjs`

- 거의 동일한 설정이 두 곳에 중복
- `packages/config`에 ESLint 미포함 → 규칙 일관성 불가
**조치:** `packages/config`에 공유 ESLint 설정 추가

---

### UX/Flow

#### C-UX-1. 온보딩 후 가나 학습으로 강제 라우팅
**파일:** `apps/web/src/app/(auth)/onboarding/page.tsx:104-108`

- N5 + showKana 선택 시 홈을 건너뛰고 바로 가나 학습으로 이동
- 앱의 메인 인터페이스(홈, 미션, 스트릭)를 경험하지 못한 채 학습 강요
**조치:** 항상 홈으로 라우팅, 홈에서 가나 CTA로 유도 (이미 KanaCtaCard 있음)

#### C-UX-2. 학습 탭 에러 상태 처리 없음
**파일:** `apps/web/src/app/(app)/study/page.tsx:88-92`

- `useRecommendations()` 에러 시 "추천 학습이 없어요"로 잘못 표시
- 네트워크 오류를 빈 상태로 착각 → 사용자 혼란
**조치:** loading vs error vs empty 명확히 구분

---

## 3. Major Issues

> 1~2주 내 해결 권장

### Backend/API

| # | 이슈 | 파일 |
|---|------|------|
| M-BE-1 | N+1 쿼리 — Quiz Start에서 루프 내 개별 update + 전체 단어 로드 | `api/v1/quiz/start/route.ts` |
| M-BE-2 | 인메모리 Rate Limiting — 서버리스 인스턴스 간 공유 불가 | rate-limit 관련 |
| M-BE-3 | 입력 검증 불일관 — 일부 POST에 Zod 없음 (`/quiz/answer`, `/wordbook`) | 다수 API |
| M-BE-4 | Chat 메시지 동시성 — JSON 배열 덮어쓰기 race condition | `api/v1/chat/` |

### Frontend

| # | 이슈 | 파일 |
|---|------|------|
| M-FE-1 | SettingsMenu 622줄 — 학습/앱/정보/계정 혼합 단일 컴포넌트 | `settings-menu.tsx` |
| M-FE-2 | Quiz 페이지 Prop Drilling — 10개+ state 하나의 컴포넌트에서 관리 | `quiz/page.tsx` |
| M-FE-3 | 접근성 부족 — 키보드 네비게이션, aria-live 부분 적용 | 전체 |
| M-FE-4 | 애니메이션 과다 — 4개 섹션 순차 애니메이션, 600ms 지연 | 다수 페이지 |

### Architecture

| # | 이슈 | 파일 |
|---|------|------|
| M-AR-1 | tsconfig 확장 미사용 — apps에서 config 상속 안 함, target 불일치 | tsconfig.json |
| M-AR-2 | 테스트 인프라 분산 — packages 테스트 전무, E2E 미구현 | 전체 |
| M-AR-3 | CI/CD 파이프라인 미구현 — .github/workflows 없음 | 루트 |
| M-AR-4 | Turbo lint/test가 ^build에 의존 — 불필요한 빌드 대기 | `turbo.json` |

### UX/Flow

| # | 이슈 | 파일 |
|---|------|------|
| M-UX-1 | 회화 시나리오 선택이 다단계 — 로딩 2번, "빠른 시작" 없음 | `chat/page.tsx` |
| M-UX-2 | 학습 결과 → 회화 연습 CTA 없음 — 자연스러운 다음 단계 누락 | `study/result/page.tsx` |
| M-UX-3 | 에러 처리 패턴 불일관 — Home/Chat은 있지만 Study는 없음 | 다수 페이지 |
| M-UX-4 | 미션 상세 페이지 없음 — 동기부여 루프 끊김 | 홈만 표시 |
| M-UX-5 | MY 페이지 설정 접근성 — JLPT 레벨/목표 변경이 어려움 | `my/page.tsx` |

---

## 4. Minor Issues

> 지속적으로 개선

### UX/Flow
- 퀴즈 중 뒤로가기 시 데이터 손실 경고 없음
- 스트릭이 홈에만 표시, 학습/채팅 탭에서 미표시
- 가나 차트 페이지로의 경로가 학습 데이터 섹션에만 존재
- 진행 중인 퀴즈 배너가 홈에만 있음
- Bottom Nav 배경이 라이트 테마에서 콘텐츠와 구분 약함
- 음성 통화 피드백 → 결과 페이지 경로 부재

### Frontend
- 미사용 코드 정리 필요
- Query 무효화 세분화 필요
- localStorage 에러 처리 부족

### Backend/API
- 에러 응답 형식/언어 불일관 (한국어/영어 섞임)
- Pagination 구현 부분적 (wordbook은 있으나 quiz는 없음)
- 민감 정보 노출 — PortOne 에러 응답 그대로 throw
- AI 응답 스트리밍 미지원 (`generateText()` → `streamText()` 권장)
- JSON 필드 타입 검증 없음

### Architecture
- landing 앱 미완성 (database, types 미참조)
- Prettier pre-commit 훅 없음
- Sentry 부분적 적용 (next.config.ts만)

---

## 5. 긍정 평가

### UX/Flow
- 온보딩이 짧고 명확 (3~4 스텝)
- 홈 페이지 정보 아키텍처 우수 (스트릭, 미션, 추천, 통계 한 화면)
- 학습 결과 페이지가 풍부 (정답률, XP, 오답, 단어장 저장)
- 텍스트 회화 "자유 대화" CTA 접근성 좋음

### Frontend
- Framer Motion 활용한 부드러운 전환 효과
- shadcn/ui 기반 일관된 디자인 시스템
- TanStack Query로 서버 상태 관리 체계화

### Backend/API
- API 구조 기본 설계가 체계적
- Prisma ORM으로 SQL Injection 방지
- Supabase Auth 통합이 안정적

### Architecture
- Turborepo + pnpm workspace 적절한 선택
- TypeScript strict 모드 적용
- 패키지 분리 방향성은 올바름

---

## 6. 우선순위 액션 플랜

### Phase 0: 긴급 (이번 주)
> 보안/데이터 정합성 — 배포 차단 이슈

| 우선순위 | 이슈 | 예상 공수 |
|---------|------|----------|
| P0-1 | C-BE-1: 결제 금액 검증 강화 | 0.5일 |
| P0-2 | C-BE-2: Onboarding 트랜잭션 통합 | 0.5일 |
| P0-3 | C-BE-3: Webhook replay attack 방어 | 0.5일 |
| P0-4 | C-BE-4: 모든 AI 엔드포인트 checkAiLimit | 0.5일 |
| P0-5 | C-FE-1: TypingQuiz 렌더 루프 수정 | 0.5일 |

### Phase 1: 높은 우선순위 (1주 내)
> 안정성/타입 안전성

| 우선순위 | 이슈 | 예상 공수 |
|---------|------|----------|
| P1-1 | C-AR-1: 환경 변수 Zod 검증 | 1일 |
| P1-2 | C-FE-3: QuizQuestion 타입 리팩토링 | 1일 |
| P1-3 | C-UX-1: 온보딩 후 항상 홈으로 라우팅 | 0.5일 |
| P1-4 | C-UX-2: 학습 탭 에러 상태 처리 | 0.5일 |
| P1-5 | M-BE-3: 모든 API에 Zod 입력 검증 | 1일 |

### Phase 2: 중간 우선순위 (2주 내)
> 코드 품질/DX

| 우선순위 | 이슈 | 예상 공수 |
|---------|------|----------|
| P2-1 | M-AR-3: CI/CD 파이프라인 구축 | 1일 |
| P2-2 | M-FE-1: SettingsMenu 분해 | 1일 |
| P2-3 | M-BE-1: N+1 쿼리 최적화 | 0.5일 |
| P2-4 | M-UX-3: 에러 처리 패턴 통일 | 1일 |
| P2-5 | M-BE-2: Rate Limiting → Redis | 1일 |

### Phase 3: 장기 개선 (3~4주)
> UX 향상/확장성

| 우선순위 | 이슈 | 예상 공수 |
|---------|------|----------|
| P3-1 | M-FE-3: 접근성 (키보드, aria) | 2일 |
| P3-2 | M-UX-1: 회화 빠른 시작 옵션 | 1일 |
| P3-3 | M-AR-2: 테스트 인프라 통합 | 2일 |
| P3-4 | M-UX-2: 학습 결과 → 회화 CTA | 0.5일 |
| P3-5 | C-AR-2: @harukoto/ui 정리 | 0.5일 |

---

## 부록: 분석 팀 구성

| 역할 | 분석 범위 | 발견 이슈 |
|------|----------|----------|
| UX/Flow 분석관 | 유저 플로우, 에러 상태, 네비게이션 | Critical 2, Major 5, Minor 7 |
| Frontend 분석관 | 컴포넌트, 상태관리, 성능, 접근성 | Critical 3, Major 4, Minor 3+ |
| Backend/API 분석관 | API 설계, DB, 보안, 트랜잭션 | Critical 4, Major 4, Minor 5+ |
| Architecture 분석관 | 모노레포, 의존성, CI/CD, DX | Critical 3, Major 4, Minor 3 |

---

## 7. 검증 결과

> 4개 분야의 분석 결과를 실제 코드 대조로 재검증한 결과

분석관들이 보고한 **Critical 13건**을 실제 코드를 읽어 검증했습니다.

### 검증 요약

| 구분 | 건수 | 설명 |
|------|------|------|
| **타당 (진짜 Critical)** | 5건 | 코드로 확인, 즉시 수정 필요 |
| **심각도 하향 (Critical → Major)** | 4건 | 문제 존재하나 Critical은 아님 |
| **과장/오진** | 4건 | 실제로 문제 없거나 Minor 수준 |

### 타당 — 진짜 Critical (5건)

| # | 이슈 | 분야 | 근거 |
|---|------|------|------|
| 1 | **결제 금액 Tampering** | Backend | Webhook에서 `amount.total === PRICES.YEARLY`로만 plan 판별. 금액 변조 시 잘못된 plan 활성화 가능 |
| 2 | **Webhook Replay Attack** | Backend | HMAC 서명 검증은 있으나 timestamp/nonce 없음. `PENDING` 상태 동시 읽기 race condition 존재 |
| 3 | **TypingQuiz 렌더 루프** | Frontend | `typing-quiz.tsx:103-106` — setTimeout이 useEffect 밖 렌더 중 실행. 조건 충족 시 매 렌더마다 중복 스케줄링 |
| 4 | **환경 변수 타입 안전성 부재** | Architecture | 15개 파일에서 `process.env` 직접 접근. Zod 검증 파일 없음. `!` non-null assertion만 사용 |
| 5 | **온보딩 후 가나 강제 라우팅** | UX | `onboarding/page.tsx:104-108` — showKana=true 시 `router.push('/study/kana')` 확인. 홈 건너뜀 |

### 심각도 하향 — Critical → Major (4건)

| # | 원래 이슈 | 원래 등급 | 실제 등급 | 하향 이유 |
|---|----------|----------|----------|----------|
| 6 | **Onboarding 트랜잭션 분리** (C-BE-2) | Critical | **Major** | 실제 위험 존재하나 Supabase Auth 실패 확률 낮고, upsert는 idempotent |
| 7 | **AI 사용량 제한 누락** (C-BE-4) | Critical | **Major** | 분당 rate limit(20회)은 모든 AI 엔드포인트에 적용됨. 일일 한도(`checkAiLimit`)만 일부 누락 |
| 8 | **@harukoto/ui 미사용** (C-AR-2) | Critical | **Minor** | 기능/보안 영향 0. 빈 패키지일 뿐 빌드 에러나 런타임 문제 없음 |
| 9 | **학습 탭 에러 처리 없음** (C-UX-2) | Critical | **Major** | 실제로 에러 상태 미처리이나, TanStack Query가 자동 재시도하므로 사용자 노출 빈도 낮음 |

### 과장/오진 — 문제 아님 (4건)

| # | 원래 이슈 | 원래 등급 | 판정 | 오진 이유 |
|---|----------|----------|------|----------|
| 10 | **apiFetch 에러 핸들링 미흡** (C-FE-2) | Critical | **해당없음** | `api.ts`에 에러 처리 구현됨 + 테스트 존재. 호출처도 try-catch 또는 TanStack Query로 처리 |
| 11 | **QuizQuestion 타입 안전성** (C-FE-3) | Critical | **해당없음** | 기본 타입은 optional 2개뿐(25%). 각 퀴즈 모드별로 이미 자체 타입 분리 완료 (ClozeQuizQuestion, TypingQuestion 등) |
| 12 | **ESLint 설정 중복** (C-AR-3) | Critical | **Minor** | 2개 파일이 동일한 건 사실이나, 유지보수성 이슈일 뿐 기능/보안 영향 없음 |
| 13 | **채팅 피드백 바닥 네비** (UX 분석) | Critical | **과장** | 정규식이 `/chat/[id]`만 매칭하여 피드백 페이지에서 네비 표시되는 건 맞으나, 분석관의 "네비게이션 혼란" 진단은 과장. 사용자가 자유롭게 이동 가능 |

### 분석관별 정확도

| 분석관 | 검증 대상 | 타당 | 과장/오진 | 정확도 |
|--------|----------|------|----------|--------|
| **Backend** | 4건 | 3건 | 1건 (부분 과장) | **87%** |
| **UX/Flow** | 4건 | 2건 | 1건 과장, 1건 부분 타당 | **62%** |
| **Frontend** | 3건 | 1건 | 2건 | **33%** |
| **Architecture** | 3건 | 1건 | 2건 (하향) | **33%** |

> Backend 분석관이 가장 정확했고, Frontend/Architecture 분석관은 심각도를 과대 평가하는 경향

---

## 8. 검증 후 확정 액션 플랜

> 검증 결과를 반영한 실제 실행 로드맵

### Phase 0: 보안 긴급 (이번 주)
> 결제/인증 보안 — **배포 전 필수**

| # | 이슈 | 작업 내용 | 공수 |
|---|------|----------|------|
| 1 | **결제 금액 Tampering** | Webhook에서 금액 기반 plan 판별 제거. 결제 생성 시 서버에 plan 저장 → Webhook에서 paymentId로 조회하여 검증 | 0.5일 |
| 2 | **Webhook Replay Attack** | timestamp 5분 제한 추가. `PENDING` 상태 업데이트에 optimistic lock 또는 `updateMany` where 조건 추가로 race condition 방지 | 0.5일 |
| 3 | **TypingQuiz 렌더 루프** | `typing-quiz.tsx:103-106`의 setTimeout을 useEffect로 이동 + cleanup 추가 | 0.5일 |

### Phase 1: 안정성 강화 (1주 내)
> 데이터 정합성 + 에러 처리

| # | 이슈 | 작업 내용 | 공수 |
|---|------|----------|------|
| 4 | **온보딩 가나 강제 라우팅** | `handleComplete()`에서 showKana 여부 무관하게 항상 `/home`으로 라우팅 | 0.5일 |
| 5 | **Onboarding 트랜잭션 분리** | Prisma upsert 실패 시 Supabase Auth 롤백 로직 추가, 또는 Prisma 먼저 실행 후 Auth 업데이트 | 0.5일 |
| 6 | **AI 일일 한도 누락** | `/v1/chat/tts`, `/v1/chat/voice/transcribe`, `/v1/chat/live-feedback`, `/v1/chat/message`, `/v1/chat/live-token`에 `checkAiLimit()` 추가 | 0.5일 |
| 7 | **환경 변수 타입 검증** | `apps/web/src/lib/env.ts` 생성, Zod 스키마로 모든 환경 변수 검증. 서버 시작 시 즉시 실패하도록 구성 | 1일 |
| 8 | **학습 탭 에러 처리** | `study/page.tsx`에서 `useRecommendations()`의 `isError` 반환 + 에러/빈 상태 UI 분리 | 0.5일 |

### Phase 2: 코드 품질 (2주 내)
> API 안정성 + DX 개선

| # | 이슈 | 작업 내용 | 공수 |
|---|------|----------|------|
| 9 | **입력 검증 통일** | `/quiz/answer`, `/wordbook` POST, `/chat/message` 등 Zod 미적용 API에 스키마 추가 | 1일 |
| 10 | **N+1 쿼리 최적화** | Quiz Start에서 루프 내 update → `updateMany` 일괄 처리. 전체 단어 로드 → 페이지네이션 | 0.5일 |
| 11 | **Chat 메시지 동시성** | JSON 배열 전체 덮어쓰기 → 버전 컬럼 추가 또는 atomic append 패턴 | 1일 |
| 12 | **에러 처리 패턴 통일** | 모든 페이지에 loading/error/empty 3상태 처리. 공통 에러 컴포넌트 추출 | 1일 |
| 13 | **CI/CD 파이프라인** | `.github/workflows/ci.yml` — PR 시 lint + typecheck + test 자동 실행 | 1일 |

### Phase 3: UX/확장성 (3~4주)
> 사용자 경험 향상

| # | 이슈 | 작업 내용 | 공수 |
|---|------|----------|------|
| 14 | **SettingsMenu 분해** | 622줄 → 학습설정/앱설정/정보/계정 4개 서브 컴포넌트로 분리 | 1일 |
| 15 | **접근성 개선** | 키보드 네비게이션, aria-live 영역, 포커스 관리 | 2일 |
| 16 | **회화 빠른 시작** | 음성 탭에도 "빠른 음성 통화" CTA 추가. 시나리오 prefetch | 1일 |
| 17 | **테스트 인프라** | packages에 Vitest 설정 추가, 주요 API 통합 테스트 작성 | 2일 |
| 18 | **Turbo 빌드 의존성 정리** | lint/test에서 `^build` 의존 제거. @harukoto/ui 패키지 제거 | 0.5일 |
