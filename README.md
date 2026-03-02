# 하루코토 (HaruKoto / ハルコト)

매일 한 단어, 봄처럼 피어나는 나의 일본어.

JLPT 시험 대비 + AI 실전 회화를 제공하는 한국인을 위한 일본어 학습 앱입니다.

## 프로젝트 구조

```
harukoto/
├── apps/
│   ├── web/          # Next.js 학습 앱 (PWA, Flutter WebView)
│   ├── landing/      # Next.js 서비스 소개 페이지 (SSG)
│   └── mobile/       # Flutter 모바일 앱
├── packages/
│   ├── ui/           # 공유 UI 컴포넌트 (shadcn 기반)
│   ├── types/        # 공유 타입 정의
│   ├── database/     # Prisma 스키마 + 클라이언트
│   ├── ai/           # AI Provider 추상화 레이어
│   └── config/       # ESLint, TS, Tailwind 공유 설정
└── docs/             # 기획 문서 (PRD 등)
```

## 기술 스택

| 영역 | 기술 |
|------|------|
| Monorepo | Turborepo + pnpm |
| Framework | Next.js 16 (App Router) |
| Language | TypeScript (strict) |
| Styling | Tailwind CSS v4 + shadcn/ui |
| 서버 상태 | TanStack Query |
| 클라이언트 상태 | Zustand |
| 애니메이션 | Framer Motion |
| DB / Auth | Supabase (PostgreSQL + Auth) |
| ORM | Prisma |
| AI | Vercel AI SDK |
| 모바일 | Flutter (WebView) |
| 배포 | Vercel |

## 시작하기

### 요구사항

- Node.js >= 20.9.0
- pnpm 10.x

### 설치 및 실행

```bash
# 의존성 설치
pnpm install

# 환경 변수 설정
cp apps/web/.env.example apps/web/.env.local

# 개발 서버 실행
pnpm dev              # 전체 (web + landing)
pnpm dev:web          # 학습 앱만 (localhost:3000)
pnpm dev:landing      # 랜딩 페이지만 (localhost:3001)
```

### 빌드

```bash
pnpm build            # 전체 빌드
pnpm build:web        # web만
pnpm build:landing    # landing만 (정적 빌드)
```

### 기타 명령어

```bash
pnpm lint             # ESLint 검사
pnpm test             # 테스트 실행
pnpm format           # Prettier 포맷팅
pnpm clean            # 빌드 캐시 정리
```

## 배포 구성

| 앱 | URL | 설명 |
|----|-----|------|
| landing | harukoto.com | 서비스 소개 (정적) |
| web | app.harukoto.com | 학습 앱 (SSR) |
| mobile | App Store / Play Store | Flutter 앱 |

## 모바일 앱

Flutter 프로젝트는 pnpm workspace 외부에서 별도로 관리됩니다.

```bash
cd apps/mobile
flutter pub get
flutter run
```

## 라이선스

Private - All rights reserved.
