# 하루코토 (HaruKoto / ハルコト) - 일본어 학습 앱

## 프로젝트 개요

한국인을 위한 재미있는 일본어 학습 앱. JLPT 시험 대비 + AI 실전 회화 연습.

- **하루**: 한국어 "하루"(1일) + 일본어 "春"(봄)
- **코토**: 일본어 "言"(말/단어)
- 상세 기획: `docs/product/prd.md`
- 문서 인덱스: `docs/README.md`

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
│   ├── web/                  # Next.js 16.1 메인 학습 앱
│   ├── mobile/               # Flutter 모바일 앱
│   ├── api/                  # Python/FastAPI 백엔드
│   └── landing/              # 랜딩 페이지
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

| 역할 | 커맨드 | 설명 |
|---|---|---|
| PM | `/pm-review` | 기획 의도 감독, PRD 대비 체크 |
| Frontend Dev | `/develop` | UI, 페이지, 인터랙션 구현 |
| Backend Dev | `/develop` | API, DB, AI 통합 |
| QA | `/qa-test` | 단위/통합/E2E 테스트 |
| Code Reviewer | `/code-review` | 코드 품질, 보안 검토 |
| Codex Review | `/codex-review` | 교차 검증 (API 계약, 타입, 런타임) |
| CI Watch | `/ci-watch` | 푸시 후 CI 감시 + 자동 수정 |
| Sprint Plan | `/sprint-plan` | 스프린트 계획 |

## Git 브랜치 전략

- `main`: 프로덕션 배포 브랜치
- `develop`: 개발 통합 브랜치
- `feature/*`: 기능 개발 브랜치
- `fix/*`: 버그 수정 브랜치
- `hotfix/*`: 긴급 수정 브랜치

## 커밋 컨벤션 (Conventional Commits)

```
feat: 새로운 기능 추가
fix: 버그 수정
docs: 문서 변경
style: 코드 포맷팅 (기능 변경 없음)
refactor: 코드 리팩토링
test: 테스트 추가/수정
chore: 빌드, 설정 변경
```

## 핵심 개발 원칙

1. **올바른 접근법 우선**: 빠른 해결(quick fix)보다 근본 원인을 파악하고 올바른 방법으로 해결한다. 임시 우회 시 반드시 TODO + 근본 해결 계획을 문서화한다.
2. **Codex 교차 검증 필수**: 기능 구현/버그 수정 커밋 전에 Codex 교차 검증을 실행하고, P0/P1 피드백은 반드시 수정 후 커밋한다.

## 세부 규칙 참조

경로별/주제별 세부 규칙은 `.claude/rules/`에 분리되어 있습니다:

- `web.md` — Next.js 16.1, App Router, 컴포넌트, 상태 관리, 성능
- `mobile.md` — Flutter 빌드, 시트 안정화, device ID
- `api.md` — Python/FastAPI, ruff, API 계약
- `quality.md` — TypeScript 컨벤션, 테스트 패턴, lint 규칙
- `security.md` — 시크릿 관리, 입력 검증, 접근 제어
- `workflow.md` — Claude+Codex 협업 워크플로우, 리뷰 규칙
