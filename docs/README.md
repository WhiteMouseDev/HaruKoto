# HaruKoto Documentation

> 하루코토 프로젝트 문서 인덱스. 모든 문서의 단일 진입점입니다.

## 문서 구조

```
docs/
├── architecture/    # 시스템 아키텍처, API, DB, 인프라
├── domain/          # 도메인 지식 (학습, 게임화, 결제)
├── product/         # 기획, 화면, 로드맵, 디자인
├── decisions/       # ADR (Architecture Decision Records)
├── operations/      # 운영, 배포, 콘텐츠 파이프라인, QA
└── archive/         # 레거시/구식 문서 (참조용 보존)
```

## 핵심 문서 (빠른 접근)

### 제품
- [PRD (제품 요구사항)](product/prd.md)
- [화면 구조](product/screens/)

### 학습 시스템 (Part 1 완성)
- [학습 트랙 설계](domain/learning/learning-track.md) — 마이크로 레슨 10분 구조
- [퀴즈 트랙 설계](domain/learning/quiz-track.md) — 4탭 퀴즈 시스템
- [SRS 엔진](domain/learning/srs-engine.md) — 6단계 상태 머신, PROVISIONAL, FSRS
- [N5 커리큘럼 맵](domain/learning/n5-curriculum-map.md) — 90레슨 × 18챕터

### 아키텍처
- [학습 데이터 스키마](architecture/data/learning-data-schema.md) — 5개 테이블 + review_events
- [FastAPI 엔드포인트 맵](architecture/api/fastapi-endpoint-map.md)
- [인프라 구성](architecture/platform/infrastructure-overview.md)

### 의사결정
- [ADR-001: MVP-β 스코프](decisions/ADR-001-mvp-beta-scope.md) — synonym_groups/quiz_sessions 보류

### 운영
- [콘텐츠 파이프라인](operations/content/content-pipeline.md) — AI 생성 + PM 검수
- [콘텐츠 변환 가이드](operations/content/content-conversion-guide.md)
- [앱스토어 배포](operations/release/app-store-submission-guide.md)
- [v1.1 안정화 체크포인트](operations/release/v1.1-stabilization-checkpoint-2026-04-23.md) — 릴리스 경계, 자동 검증, 수동 UAT 게이트
- [**AI Coding Harness**](operations/harness.md) — Claude Code + Codex 운영체계 (도메인 에이전트, 스킬, 훅, 계약 관리, 에스컬레이션)
- [AI 하네스 엔지니어링 실전 구축기 (블로그)](blog/2026-04-23-ai-harness-engineering-실전-구축기.md) — 4-pillar 하네스 설계와 실제 드리프트 버그를 잡아낸 사례
- [Codex 운영 가이드](operations/codex-workflows.md) — 프로필, 프롬프트 템플릿, 모노레포 검증 기준
- [Codex 스모크 테스트](operations/codex-smoke-test.md) — 첫 실전 테스트용 프롬프트 모음
- [모바일 아키텍처 감사 (2026-03-24)](operations/audits/mobile-architecture-audit-2026-03-24.md) — 모바일 구조 문제점과 개선 우선순위
- [모바일 시작/스플래시 정책 (2026-03-24)](operations/mobile/mobile-startup-splash-policy-2026-03-24.md) — 스플래시 길이와 시작 경험 기준
- [모바일 비스플래시 개선 설계 (2026-03-24)](operations/plans/mobile-non-splash-improvement-design-2026-03-24.md) — 네트워크, 설정, 세션, 테스트 개선 설계
- [모바일 비스플래시 실행 로드맵 (2026-03-24)](operations/plans/mobile-non-splash-implementation-roadmap-2026-03-24.md) — 단계별 작업 순서와 완료 기준

## 콘텐츠 데이터

레슨 콘텐츠 JSON은 `packages/database/data/lessons/n5/`에 위치합니다:
```
packages/database/data/lessons/n5/
├── ch01-greetings-and-first-meetings.json
├── ch02-introducing-things-and-people.json
├── ch03-location-and-movement.json
├── ch04-verb-basics.json
├── ch05-past-and-sequence.json
└── ch06-progress-and-habits.json
```

개발/스테이징 DB에 학습 콘텐츠를 재현할 때는 root에서 통합 시드 명령을 실행합니다.

```bash
DATABASE_URL="postgresql+asyncpg://user:pass@host:5432/db" pnpm seed:learning
```

## 문서 규칙

- **정본 원칙**: 코드가 문서보다 최신이면 문서를 업데이트
- **ADR/RFC**: 번호 체계 유지 (ADR-001, RFC-0001)
- **일반 문서**: 의미있는 파일명, 번호 불필요
- **아카이브**: 구식 문서는 삭제하지 않고 `archive/`로 이동
- **기능 계획 문서**: `docs/operations/plans/`에 유지
- **GSD 상태 문서**: `.planning/`에 유지
- **CLAUDE.md**: 작업 규칙/워크플로 전용, 도메인 지식은 `docs/`에
