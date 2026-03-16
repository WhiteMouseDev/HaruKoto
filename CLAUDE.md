# 하루코토 (HaruKoto / ハルコト) - 일본어 학습 앱

## 프로젝트 개요

한국인을 위한 재미있는 일본어 학습 앱. JLPT 시험 대비 + AI 실전 회화 연습.

- **하루**: 한국어 "하루"(1일) + 일본어 "春"(봄)
- **코토**: 일본어 "言"(말/단어)
- 상세 기획: `docs/PRD.md`

## 기술 스택

- **Monorepo**: Turborepo + pnpm workspace
- **Framework**: Next.js 16.1 (App Router, Turbopack)
- **Language**: TypeScript (strict mode)
- **Styling**: Tailwind CSS
- **UI**: shadcn/ui (Radix 기반)
- **서버 상태**: TanStack Query
- **클라이언트 상태**: Zustand
- **폼**: React Hook Form + Zod
- **테마**: next-themes (라이트 봄 테마 기본 / 다크 모드 지원)
- **애니메이션**: Framer Motion
- **DB/Auth**: Supabase (PostgreSQL + Auth)
- **ORM**: Prisma
- **AI**: Vercel AI SDK (초기: OpenAI/Gemini, 추후: Claude)
- **배포**: Vercel
- **테스트**: Vitest + Testing Library + Playwright (E2E)

## 프로젝트 구조 (Turborepo Monorepo)

```
harukoto/
├── apps/
│   └── web/                  # Next.js 16.1 메인 학습 앱
├── packages/
│   ├── ui/                   # 공유 UI 컴포넌트 (shadcn 기반)
│   ├── types/                # 공유 타입 정의
│   ├── database/             # Prisma 스키마 + 클라이언트
│   ├── ai/                   # AI Provider 추상화 레이어
│   └── config/               # ESLint, TS, Tailwind 공유 설정
├── turbo.json
├── pnpm-workspace.yaml
└── package.json
```

## 팀 역할 (Claude Session Team)

### PM (프로젝트 매니저/감독)

- 기획 의도 대로 개발되는지 감독
- PRD 대비 진행 상황 체크
- 기능 우선순위 관리
- 사용: `/pm-review` 커맨드

### Frontend Developer (프론트엔드 개발)

- UI 컴포넌트, 페이지, 인터랙션 구현
- 반응형 디자인, 접근성
- 사용: `/develop` 커맨드

### Backend Developer (백엔드 개발)

- API Routes, DB 스키마, AI 통합
- 인증, 결제, 보안
- 사용: `/develop` 커맨드와 함께 백엔드 컨텍스트

### QA (테스트 엔지니어)

- 단위 테스트, 통합 테스트, E2E 테스트
- 기능 검증, 엣지 케이스 확인
- 사용: `/qa-test` 커맨드

### Code Reviewer (코드 리뷰어)

- 코드 품질, 패턴 일관성, 보안 검토
- PR 리뷰 시뮬레이션
- 사용: `/code-review` 커맨드

## 개발 워크플로우

### 1. 기능 개발 사이클

```
PM 검토 → 개발 → 코드 리뷰 → QA 테스트 → PM 최종 확인
```

### 2. Git 브랜치 전략

- `main`: 프로덕션 배포 브랜치
- `develop`: 개발 통합 브랜치
- `feature/*`: 기능 개발 브랜치
- `fix/*`: 버그 수정 브랜치
- `hotfix/*`: 긴급 수정 브랜치

### 3. 커밋 컨벤션 (Conventional Commits)

```
feat: 새로운 기능 추가
fix: 버그 수정
docs: 문서 변경
style: 코드 포맷팅 (기능 변경 없음)
refactor: 코드 리팩토링
test: 테스트 추가/수정
chore: 빌드, 설정 변경
```

## 모바일 빌드 규칙 (apps/mobile)

- iOS 빌드 시 반드시 `--dart-define-from-file=.env` 포함
- 실기기 device ID: `00008150-000A20881E88401C` (Kun Woo's iPhone)
- 시뮬레이터 사용 시: `iPhone 17 Pro` (ID: `16FEF8B7-DC41-49D8-9EC6-E9911468E875`) 사용
- Release 빌드: `flutter build ios --release --dart-define-from-file=.env`
- 실기기 설치: `flutter install --release -d 00008150-000A20881E88401C`
- Debug 실행: `flutter run -d 00008150-000A20881E88401C --dart-define-from-file=.env`
- 시뮬레이터 실행: `flutter run -d 16FEF8B7-DC41-49D8-9EC6-E9911468E875 --dart-define-from-file=.env`

## 코딩 컨벤션

### TypeScript

- strict 모드 필수
- `any` 타입 사용 금지 (불가피한 경우 주석으로 이유 명시)
- interface보다 type alias 선호 (확장 필요 시 interface)
- 파일명: kebab-case (`user-profile.tsx`)
- 컴포넌트명: PascalCase (`UserProfile`)
- 함수/변수명: camelCase (`getUserData`)
- 상수: UPPER_SNAKE_CASE (`MAX_RETRY_COUNT`)

### React/Next.js

- Server Components 기본, 필요 시에만 `"use client"`
- `proxy.ts` 사용 (middleware.ts 아님 - Next.js 16 변경사항)
- `params`, `cookies()`, `headers()` 등 async 사용 필수
- 컴포넌트 파일: 하나의 파일에 하나의 exported 컴포넌트

### 디렉토리 구조 (apps/web)

```
src/
├── app/                  # Next.js App Router 페이지
│   ├── (auth)/           # 인증 관련 페이지 그룹
│   ├── (main)/           # 메인 앱 페이지 그룹
│   └── api/              # API Route Handlers
├── components/           # 앱 전용 컴포넌트
│   ├── ui/               # 기본 UI 컴포넌트
│   ├── features/         # 기능별 컴포넌트
│   └── layouts/          # 레이아웃 컴포넌트
├── hooks/                # 커스텀 훅
├── lib/                  # 유틸리티, 헬퍼
├── stores/               # Zustand 스토어
├── styles/               # 글로벌 스타일
└── types/                # 앱 전용 타입
```

### 테스트

- 모든 유틸 함수: 단위 테스트 필수
- 주요 컴포넌트: 통합 테스트
- 핵심 사용자 플로우: E2E 테스트
- 테스트 파일 위치: `__tests__/` 또는 `*.test.ts(x)`
- 테스트 네이밍: `describe('기능명')` → `it('should 동작')` 패턴

### 보안

- 환경 변수: `.env.local` (절대 커밋하지 않음)
- API 키: 서버 사이드에서만 접근
- 사용자 입력: Zod로 반드시 검증
- SQL Injection: Prisma ORM으로 방지
- XSS: React 기본 이스케이프 + DOMPurify (HTML 렌더링 시)

### 성능

- 이미지: Next.js Image 컴포넌트 사용
- 번들 크기: dynamic import 활용
- 데이터: TanStack Query 캐싱 전략 활용
- 렌더링: ISR/SSG 우선, 필요 시 SSR
